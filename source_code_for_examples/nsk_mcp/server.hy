;; server.hy -- Minimal MCP server in Hy (JSON-RPC 2.0 over stdio, spec 2025-11-25).

(import json)
(import shutil)
(import sys)
(import tempfile)
(import hy.models [Keyword Expression List])
(import nsk_path [DATA-DIR Graph Var Neural show to-term to-pattern to-keyword
                  run-query saturate])
(import policy [ToolPolicy PolicyError])

(setv PROTOCOL-VERSION "2025-11-25"
      SERVER-INFO {"name" "nsk-mcp"
                   "title" "NSK Knowledge Graph MCP Server"
                   "version" "0.1.0"}
      PARSE-ERROR -32700
      INVALID-REQUEST -32600
      METHOD-NOT-FOUND -32601
      INVALID-PARAMS -32602
      INTERNAL-ERROR -32603)


;; ---------- term and query helpers ----------

(defn term-to-json [term]
  (cond
    (isinstance term Keyword) term.name
    (isinstance term Var) (+ "?" term.name)
    (isinstance term Neural) (+ "~" (term-to-json term.name))
    True term))

(defn triple-to-json [triple]
  (list (map term-to-json triple)))

(defn parse-query-string [query-str]
  "Parse one or more [s p o] patterns from an s-expression string without eval."
  (when (or (not (isinstance query-str str)) (not (.strip query-str)))
    (raise (ValueError "query must be a non-empty string of [s p o] patterns")))
  (setv forms (list (hy.read-many query-str)))
  (when (not forms)
    (raise (ValueError "query contained no patterns")))
  (lfor form forms (to-pattern form)))

(defn string-to-ground-term [value]
  "Convert a JSON string or number into a ground NSK term."
  (cond
    (isinstance value #(int float)) value
    (isinstance value str)
      (do
        (setv text (.strip value))
        (when (not text)
          (raise (ValueError "term cannot be empty")))
        (when (or (.startswith text "?") (.startswith text "~"))
          (raise (ValueError f"fact terms must be ground, got {text}")))
        (if (.startswith text ":")
            (Keyword (cut text 1 None))
            (or (to-keyword text) (raise (ValueError f"invalid term: {text}")))))
    True (raise (ValueError f"unsupported term type: {(type value)}"))))

(defn format-rule [rule]
  (setv [head body] rule)
  {"head" (show head)
   "body" (lfor pat body (show pat))
   "text" (+ (show head) " <- " (.join " " (map show body)))})

(defn result-to-structured [result]
  "Convert a QueryResult into JSON-friendly bindings and provenance."
  (setv provenance []
        rows [])
  (for [[row used] (zip result.rows result.support)]
    (.append rows
      {"bindings" (dfor [k v] (.items row) k (term-to-json v))
       "support" (lfor [triple source] used
                   {"triple" (triple-to-json triple)
                    "source" source})})
    (for [[triple source] used]
      (setv item {"triple" (triple-to-json triple) "source" source})
      (when (not-in item provenance)
        (.append provenance item))))
  {"count" (len result)
   "text" (str result)
   "solutions" rows
   "provenance" provenance})


;; ---------- tool implementations ----------

(defn tool-ask [graph policy args]
  (setv query-str (.get args "query")
        limit (policy.clamp-limit (.get args "limit"))
        patterns (parse-query-string query-str)
        result (run-query patterns :graph graph :neural False :limit limit)
        structured (result-to-structured result))
  (setv (get structured "limit") limit)
  structured)

(defn tool-add-fact [graph policy args]
  (for [field ["subject" "predicate" "object"]]
    (when (not-in field args)
      (raise (ValueError f"missing required argument: {field}"))))
  (setv triple #((string-to-ground-term (get args "subject"))
                 (string-to-ground-term (get args "predicate"))
                 (string-to-ground-term (get args "object")))
        added (graph.add triple "fact"))
  (saturate graph)
  {"added" added
   "triple" (triple-to-json triple)
   "text" (if added f"added {(show triple)}" f"already known: {(show triple)}")
   "total_triples" (len graph)})

(defn tool-graph-stats [graph policy args]
  (saturate graph)
  (setv by-source {"fact" 0 "rule" 0 "neural" 0})
  (for [[_ src] (graph.facts)]
    (setv (get by-source src) (+ (.get by-source src 0) 1)))
  (setv summary f"{(len graph)} triples ({(get by-source "fact")} facts, {(get by-source "rule")} derived), {(len graph.rules)} rules")
  {"total_triples" (len graph)
   "by_source" by-source
   "rules_count" (len graph.rules)
   "predicates" (sorted (lfor k (.keys graph.pos) (term-to-json k)))
   "text" summary})

(defn tool-explain [graph policy args]
  (setv query-str (.get args "query")
        limit (policy.clamp-limit (.get args "limit" 5))
        patterns (parse-query-string query-str)
        result (run-query patterns :graph graph :neural False :limit limit)
        explanations [])
  (for [[row used] (zip result.rows result.support)]
    (setv bindings (dfor [k v] (.items row) k (term-to-json v))
          steps (if used
                    (lfor [triple source] used
                      {"triple" (triple-to-json triple)
                       "source" source
                       "note" (if (= source "rule")
                                  f"derived by rule: {(show triple)}"
                                  f"{source}: {(show triple)}")})
                    [{"triple" []
                      "source" "fact"
                      "note" "direct match on asserted facts"}]))
    (.append explanations {"bindings" bindings "proof" steps}))
  {"query" query-str
   "count" (len explanations)
   "explanations" explanations
   "text" (str result)})

(defn load-sexp-file [graph path]
  "Read (:add s p o) and (:rule head body...) forms from path without eval."
  (with [f (open path :encoding "utf-8")]
    (setv text (.read f)))
  (setv added-facts 0
        added-rules 0)
  (for [form (hy.read-many text)]
    (when (not (and (isinstance form Expression) form (isinstance (get form 0) Keyword)))
      (raise (ValueError f"invalid entry in {( . path name )}: {(hy.repr form)}")))
    (setv op (. (get form 0) name)
          rest (list (cut form 1 None)))
    (cond
      (= op "add")
        (when (graph.add (to-pattern (List rest)) "fact")
          (setv added-facts (+ added-facts 1)))
      (= op "rule")
        (do
          (setv pats (lfor item rest (to-pattern item)))
          (when (graph.add-rule (get pats 0) (cut pats 1 None))
            (setv added-rules (+ added-rules 1))))
      True (raise (ValueError f"unsupported directive :{op} in {( . path name )}"))))
  (saturate graph)
  #(added-facts added-rules))

(defn tool-load-facts [graph policy args]
  (setv rel-path (.get args "file" "")
        safe-path (policy.resolve-safe-path rel-path)
        [added-facts added-rules] (load-sexp-file graph safe-path))
  {"file" rel-path
   "added_facts" added-facts
   "added_rules" added-rules
   "total_triples" (len graph)
   "text" f"loaded {added-facts} facts and {added-rules} rules from {rel-path}"})


;; ---------- MCP schema declarations ----------

(setv TOOL-SCHEMAS
  [{"name" "ask"
    "description" "Run a conjunctive NSK query such as '[?who :wrote :nsk] [?who :codes-in ?lang]' and return variable bindings with provenance."
    "inputSchema" {"type" "object"
                   "properties" {"query" {"type" "string"
                                          "description" "One or more [s p o] patterns in NSK s-expression syntax."}
                                 "limit" {"type" "integer"
                                          "description" "Maximum number of solutions (1..100)."}}
                   "required" ["query"]
                   "additionalProperties" False}}
   {"name" "add-fact"
    "description" "Assert a new ground fact triple [subject predicate object] into the NSK graph."
    "inputSchema" {"type" "object"
                   "properties" {"subject" {"type" "string"}
                                 "predicate" {"type" "string"}
                                 "object" {"type" ["string" "number"]}}
                   "required" ["subject" "predicate" "object"]
                   "additionalProperties" False}}
   {"name" "graph-stats"
    "description" "Return counts of facts, rule-derived triples, rules, and indexed predicates."
    "inputSchema" {"type" "object"
                   "properties" {}
                   "additionalProperties" False}}
   {"name" "explain"
    "description" "Run an NSK query and explain how each solution was proved (asserted facts vs forward-chained rules)."
    "inputSchema" {"type" "object"
                   "properties" {"query" {"type" "string"}
                                 "limit" {"type" "integer"}}
                   "required" ["query"]
                   "additionalProperties" False}}
   {"name" "load-facts"
    "description" "Load (:add s p o) and (:rule ...) entries from a file inside the allowlisted data directory."
    "inputSchema" {"type" "object"
                   "properties" {"file" {"type" "string"
                                         "description" "Relative filename inside the server data/ directory."}}
                   "required" ["file"]
                   "additionalProperties" False}}])

(setv TOOL-HANDLERS
  {"ask" tool-ask
   "add-fact" tool-add-fact
   "graph-stats" tool-graph-stats
   "explain" tool-explain
   "load-facts" tool-load-facts})

(setv RESOURCES
  [{"uri" "nsk://graph/facts"
    "name" "NSK Graph Facts"
    "description" "All triples currently in the graph with their provenance source."
    "mimeType" "application/json"}
   {"uri" "nsk://graph/rules"
    "name" "NSK Graph Rules"
    "description" "Forward-chaining Datalog rules registered in the graph."
    "mimeType" "application/json"}])

(setv PROMPTS
  [{"name" "find-authors"
    "description" "Template for querying who wrote a given work and what languages they use."
    "arguments" [{"name" "work"
                  "description" "Keyword name of the work (for example, nsk or hy-book)."
                  "required" True}]}
   {"name" "trace-topic"
    "description" "Template for finding people connected to a topic through asserted facts or rules."
    "arguments" [{"name" "topic"
                  "description" "Keyword name of the topic (for example, mcp or unification)."
                  "required" True}]}])


;; ---------- pure JSON-RPC / MCP dispatcher ----------

(defn rpc-result [req-id result]
  {"jsonrpc" "2.0"
   "id" req-id
   "result" result})

(defn rpc-error [req-id code message [data None]]
  (setv err {"code" code "message" message})
  (when (is-not data None)
    (setv (get err "data") data))
  {"jsonrpc" "2.0"
   "id" req-id
   "error" err})

(defn handle-tools-call [graph policy req-id params]
  (when (not (isinstance params dict))
    (return (rpc-error req-id INVALID-PARAMS "params must be an object")))
  (setv name (.get params "name")
        args (.get params "arguments" {}))
  (when (or (not (isinstance name str)) (not name))
    (return (rpc-error req-id INVALID-PARAMS "missing tool name")))
  (when (not (isinstance args dict))
    (return (rpc-error req-id INVALID-PARAMS "tool arguments must be an object")))
  (try
    (policy.check-tool name)
    (when (not-in name TOOL-HANDLERS)
      (raise (PolicyError f"unknown tool: {name}")))
    (setv handler (get TOOL-HANDLERS name)
          payload (policy.run-with-timeout handler graph policy args))
    (policy.audit "tool_call" :tool name :status "ok")
    (rpc-result req-id
      {"content" [{"type" "text" "text" (get payload "text")}]
       "structuredContent" payload
       "isError" False})
    (except [e [PolicyError ValueError TypeError KeyError]]
      (policy.audit "tool_call" :tool name :status "error" :reason (str e))
      (rpc-result req-id
        {"content" [{"type" "text" "text" f"error: {e}"}]
         "structuredContent" {"error" (str e) "tool" name}
         "isError" True}))))

(defn handle-resources-read [graph req-id params]
  (when (not (isinstance params dict))
    (return (rpc-error req-id INVALID-PARAMS "params must be an object")))
  (setv uri (.get params "uri"))
  (cond
    (= uri "nsk://graph/facts")
      (do
        (saturate graph)
        (setv body (json.dumps
                     {"triples" (lfor [triple src] (graph.facts)
                                  {"triple" (triple-to-json triple) "source" src})}
                     :indent 2))
        (rpc-result req-id
          {"contents" [{"uri" uri
                        "mimeType" "application/json"
                        "text" body}]}))
    (= uri "nsk://graph/rules")
      (do
        (setv body (json.dumps
                     {"rules" (lfor rule graph.rules (format-rule rule))}
                     :indent 2))
        (rpc-result req-id
          {"contents" [{"uri" uri
                        "mimeType" "application/json"
                        "text" body}]}))
    True (rpc-error req-id INVALID-PARAMS f"unknown resource URI: {uri}")))

(defn handle-prompts-get [req-id params]
  (when (not (isinstance params dict))
    (return (rpc-error req-id INVALID-PARAMS "params must be an object")))
  (setv name (.get params "name")
        args (.get params "arguments" {}))
  (cond
    (= name "find-authors")
      (do
        (setv work (.lstrip (str (.get args "work" "nsk")) ":"))
        (rpc-result req-id
          {"description" f"Find authors of :{work} and their programming languages"
           "messages" [{"role" "user"
                        "content" {"type" "text"
                                   "text" f"Call the `ask` tool with query `[?author :wrote :{work}] [?author :codes-in ?lang]` and summarize the bindings and provenance."}}]}))
    (= name "trace-topic")
      (do
        (setv topic (.lstrip (str (.get args "topic" "mcp")) ":"))
        (rpc-result req-id
          {"description" f"Trace who is connected to :{topic}"
           "messages" [{"role" "user"
                        "content" {"type" "text"
                                   "text" f"Call the `explain` tool with query `[?person :knows-topic :{topic}]` and report both the bindings and the rule proof steps."}}]}))
    True (rpc-error req-id INVALID-PARAMS f"unknown prompt: {name}")))

(defn dispatch [request graph [policy None]]
  "Pure JSON-RPC 2.0 dispatcher: (request dict, Graph, ToolPolicy) -> response dict or None.
  Notifications (requests without an 'id') return None."
  (setv policy (if (is policy None) (ToolPolicy :data-dir DATA-DIR) policy))
  (when (or (not (isinstance request dict))
            (!= (.get request "jsonrpc") "2.0")
            (not (isinstance (.get request "method") str)))
    (return (rpc-error (if (isinstance request dict) (.get request "id") None)
                       INVALID-REQUEST
                       "invalid JSON-RPC 2.0 request")))
  (setv method (get request "method")
        params (.get request "params" {})
        has-id (in "id" request)
        req-id (.get request "id"))
  (policy.audit "rpc_request" :method method :id req-id)
  (when (not has-id)
    ;; Notifications never produce a response message.
    (return None))
  (cond
    (= method "initialize")
      (rpc-result req-id
        {"protocolVersion" PROTOCOL-VERSION
         "capabilities" {"tools" {"listChanged" False}
                         "resources" {"subscribe" False "listChanged" False}
                         "prompts" {"listChanged" False}}
         "serverInfo" SERVER-INFO})
    (= method "ping")
      (rpc-result req-id {})
    (= method "tools/list")
      (rpc-result req-id
        {"tools" (lfor t TOOL-SCHEMAS
                   :if (in (get t "name") policy.allowed-tools)
                   t)})
    (= method "tools/call")
      (handle-tools-call graph policy req-id params)
    (= method "resources/list")
      (rpc-result req-id {"resources" RESOURCES})
    (= method "resources/read")
      (handle-resources-read graph req-id params)
    (= method "prompts/list")
      (rpc-result req-id {"prompts" PROMPTS})
    (= method "prompts/get")
      (handle-prompts-get req-id params)
    True
      (rpc-error req-id METHOD-NOT-FOUND f"method not found: {method}")))

(defn handle-line [line graph [policy None]]
  "Parse one newline-delimited JSON message and return a JSON response string or None."
  (setv text (.strip line))
  (when (not text)
    (return None))
  (try
    (setv msg (json.loads text))
    (except [e json.JSONDecodeError]
      (return (json.dumps (rpc-error None PARSE-ERROR f"parse error: {e.msg}")))))
  (setv response (dispatch msg graph policy))
  (if (is response None)
      None
      (json.dumps response)))


;; ---------- seed graph and stdio transport ----------

(defn make-seed-graph [[seed-file None]]
  "Create an in-memory Graph populated from data/authors.log."
  (setv seed (if (is seed-file None) (/ DATA-DIR "authors.log") seed-file)
        graph (Graph))
  (load-sexp-file graph seed)
  graph)

(defn serve-stdio [[graph None] [policy None] [in-stream None] [out-stream None]]
  "Run the newline-delimited JSON-RPC stdio loop."
  (setv graph (if (is graph None) (make-seed-graph) graph)
        policy (if (is policy None) (ToolPolicy :data-dir DATA-DIR) policy)
        in-stream (if (is in-stream None) sys.stdin in-stream)
        out-stream (if (is out-stream None) sys.stdout out-stream))
  (for [line in-stream]
    (setv reply (handle-line line graph policy))
    (when (is-not reply None)
      (.write out-stream (+ reply "\n"))
      (.flush out-stream))))

(when (= __name__ "__main__")
  (serve-stdio))
