;; test_mcp.hy -- In-memory contract tests, policy tests, and stdio round-trip test.

(import io)
(import json)
(import time)
(import pytest)
(import nsk_path [DATA-DIR Graph])
(import policy [ToolPolicy PolicyError])
(import server [PROTOCOL-VERSION METHOD-NOT-FOUND INVALID-PARAMS PARSE-ERROR
                dispatch handle-line make-seed-graph])
(import client [StdioMcpClient])


(defn make-env [[allowed None] [timeout 2.0]]
  "Return #(graph policy audit-buf) for fast in-memory dispatcher tests."
  (setv buf (io.StringIO)
        graph (make-seed-graph)
        pol (ToolPolicy :allowed-tools allowed
                        :data-dir DATA-DIR
                        :timeout-seconds timeout
                        :audit-stream buf))
  #(graph pol buf))


;; ---------- protocol and lifecycle tests ----------

(defn test-initialize-and-notification []
  (setv [graph pol _] (make-env)
        resp (dispatch {"jsonrpc" "2.0"
                        "id" 1
                        "method" "initialize"
                        "params" {"protocolVersion" "2025-11-25"
                                  "capabilities" {}
                                  "clientInfo" {"name" "pytest" "version" "0.1"}}}
                       graph pol))
  (assert (= (get resp "jsonrpc") "2.0"))
  (assert (= (get resp "id") 1))
  (assert (= (get (get resp "result") "protocolVersion") PROTOCOL-VERSION))
  (assert (in "tools" (get (get resp "result") "capabilities")))
  ;; A notification (no "id") must return None.
  (assert (is (dispatch {"jsonrpc" "2.0" "method" "notifications/initialized"}
                        graph pol)
              None)))

(defn test-ping-and-unknown-method []
  (setv [graph pol _] (make-env)
        pong (dispatch {"jsonrpc" "2.0" "id" 2 "method" "ping"} graph pol)
        missing (dispatch {"jsonrpc" "2.0" "id" 3 "method" "no/such/method"} graph pol))
  (assert (= (get pong "result") {}))
  (assert (= (get (get missing "error") "code") METHOD-NOT-FOUND)))

(defn test-parse-error-on-malformed-json []
  (setv [graph pol _] (make-env)
        raw (handle-line "{not valid json" graph pol)
        resp (json.loads raw))
  (assert (= (get (get resp "error") "code") PARSE-ERROR)))


;; ---------- tools contract tests ----------

(defn test-tools-list-respects-allowlist []
  (setv [graph pol _] (make-env :allowed #{"ask" "graph-stats"})
        resp (dispatch {"jsonrpc" "2.0" "id" 4 "method" "tools/list"} graph pol)
        names (sfor t (get (get resp "result") "tools") (get t "name")))
  (assert (= names #{"ask" "graph-stats"})))

(defn test-ask-returns-bindings-and-rule-provenance []
  (setv [graph pol _] (make-env)
        resp (dispatch {"jsonrpc" "2.0"
                        "id" 5
                        "method" "tools/call"
                        "params" {"name" "ask"
                                  "arguments" {"query" "[?book :author ?who] [?who :codes-in ?lang]"
                                               "limit" 10}}}
                       graph pol)
        result (get resp "result")
        structured (get result "structuredContent"))
  (assert (is (get result "isError") False))
  (assert (= (get structured "count") 5))
  (assert (in {"triple" ["nsk" "author" "mark"] "source" "rule"}
              (get structured "provenance"))))

(defn test-ask-enforces-result-limit []
  (setv [graph pol _] (make-env)
        resp (dispatch {"jsonrpc" "2.0"
                        "id" 6
                        "method" "tools/call"
                        "params" {"name" "ask"
                                  "arguments" {"query" "[?s ?p ?o]"
                                               "limit" 2}}}
                       graph pol)
        structured (get (get resp "result") "structuredContent"))
  (assert (= (get structured "count") 2))
  (assert (= (get structured "limit") 2)))

(defn test-add-fact-and-explain []
  (setv [graph pol _] (make-env)
        add-resp (dispatch {"jsonrpc" "2.0"
                            "id" 7
                            "method" "tools/call"
                            "params" {"name" "add-fact"
                                      "arguments" {"subject" "grace"
                                                   "predicate" "wrote"
                                                   "object" "hy-book"}}}
                           graph pol)
        exp-resp (dispatch {"jsonrpc" "2.0"
                            "id" 8
                            "method" "tools/call"
                            "params" {"name" "explain"
                                      "arguments" {"query" "[:grace :knows-topic ?topic]"}}}
                           graph pol)
        explanations (get (get (get exp-resp "result") "structuredContent") "explanations"))
  (assert (is (get (get (get add-resp "result") "structuredContent") "added") True))
  (assert (= (len explanations) 2))
  (assert (= (get (get (get (get explanations 0) "proof") 0) "source") "rule")))


;; ---------- resources and prompts tests ----------

(defn test-resources-and-prompts []
  (setv [graph pol _] (make-env)
        res-list (dispatch {"jsonrpc" "2.0" "id" 9 "method" "resources/list"} graph pol)
        facts-res (dispatch {"jsonrpc" "2.0"
                             "id" 10
                             "method" "resources/read"
                             "params" {"uri" "nsk://graph/facts"}}
                            graph pol)
        bad-res (dispatch {"jsonrpc" "2.0"
                           "id" 11
                           "method" "resources/read"
                           "params" {"uri" "nsk://graph/unknown"}}
                          graph pol)
        prompt-res (dispatch {"jsonrpc" "2.0"
                              "id" 12
                              "method" "prompts/get"
                              "params" {"name" "find-authors"
                                        "arguments" {"work" "nsk"}}}
                             graph pol))
  (assert (= (len (get (get res-list "result") "resources")) 2))
  (setv facts-payload (json.loads (get (get (get (get facts-res "result") "contents") 0) "text")))
  (assert (>= (len (get facts-payload "triples")) 12))
  (assert (= (get (get bad-res "error") "code") INVALID-PARAMS))
  (assert (in ":nsk" (get (get (get (get (get prompt-res "result") "messages") 0) "content") "text"))))


;; ---------- security policy tests ----------

(defn test-policy-rejects-path-traversal []
  (setv [graph pol buf] (make-env)
        resp (dispatch {"jsonrpc" "2.0"
                        "id" 13
                        "method" "tools/call"
                        "params" {"name" "load-facts"
                                  "arguments" {"file" "../../etc/passwd"}}}
                       graph pol)
        result (get resp "result"))
  (assert (is (get result "isError") True))
  (assert (in "escapes allowlisted data dir"
              (get (get (get result "content") 0) "text")))
  (assert (in "\"status\": \"error\"" (.getvalue buf))))

(defn test-policy-allows-safe-file-in-data-dir []
  (setv [graph pol _] (make-env)
        resp (dispatch {"jsonrpc" "2.0"
                        "id" 14
                        "method" "tools/call"
                        "params" {"name" "load-facts"
                                  "arguments" {"file" "extra_facts.sexp"}}}
                       graph pol)
        result (get resp "result"))
  (assert (is (get result "isError") False))
  (assert (= (get (get result "structuredContent") "added_facts") 4)))

(defn test-policy-denies-unlisted-tool []
  (setv [graph pol _] (make-env :allowed #{"graph-stats"})
        resp (dispatch {"jsonrpc" "2.0"
                        "id" 15
                        "method" "tools/call"
                        "params" {"name" "add-fact"
                                  "arguments" {"subject" "x" "predicate" "y" "object" "z"}}}
                       graph pol)
        result (get resp "result"))
  (assert (is (get result "isError") True))
  (assert (in "tool denied by policy: add-fact"
              (get (get (get result "content") 0) "text"))))

(defn test-policy-enforces-timeout []
  (setv [ _ pol _] (make-env :timeout 0.05))
  (defn slow-task []
    (time.sleep 0.25)
    "done")
  (with [(pytest.raises PolicyError :match "timed out")]
    (pol.run-with-timeout slow-task)))


;; ---------- subprocess stdio round-trip test ----------

(defn test-stdio-client-server-round-trip []
  (with [client (StdioMcpClient)]
    (setv init (client.initialize))
    (assert (= (get init "protocolVersion") PROTOCOL-VERSION))
    (setv tools (client.list-tools))
    (assert (= (len tools) 5))
    (setv ans (client.call-tool "ask"
                {"query" "[?who :wrote :nsk] [?who :codes-in ?lang]"}))
    (assert (is (get ans "isError") False))
    (setv solutions (get (get ans "structuredContent") "solutions"))
    (assert (= (len solutions) 3))
    (setv blocked (client.call-tool "load-facts" {"file" "../../etc/passwd"}))
    (assert (is (get blocked "isError") True))))
