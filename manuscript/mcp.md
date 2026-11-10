# MCP Servers and Tool-Using Agents in Hy

In earlier chapters we gave language models tools in two different ways: we passed Hy functions directly to Ollama's tool-calling API, and we wrapped a web scraper in an Agno `@tool` decorator. Both approaches work inside a single program, yet neither lets you share those tools across different applications without rewriting glue code. The Model Context Protocol (MCP) solves that problem. MCP is an open JSON-RPC 2.0 protocol (this chapter targets specification revision `2025-11-25`) that defines how a host application discovers and invokes tools, reads resources, and fetches prompt templates from an external server.

The code for this chapter is in the directory **source_code_for_examples/nsk_mcp**.

## What You Will Build

We will build an MCP server and client in Hy from scratch using only the Python standard library, and use it to expose the NSK symbolic knowledge graph engine from the chapter *NSK: A Neural-Symbolic Knowledge Graph Engine*. Our server speaks newline-delimited JSON-RPC 2.0 over standard input and standard output (`stdio`), exposes five graph tools (`ask`, `add-fact`, `graph-stats`, `explain`, and `load-facts`), publishes the graph's facts and forward-chaining rules as MCP resources, and provides reusable query templates as MCP prompts. Around the server we place a security boundary (`ToolPolicy`) with a deny-by-default tool allowlist, result limits, execution timeouts, path-traversal protection on file loading, and a structured JSON Lines (`JSONL`) audit log written to `stderr`.

```
+-------------------------------------------------------------------+
| Host Application (Claude Desktop, IDE, or Hy StdioMcpClient)      |
+-------------------------------------------------------------------+
               |                                     ^
               | JSON-RPC 2.0 requests (stdin)       | JSON-RPC 2.0 responses (stdout)
               v                                     |
+-------------------------------------------------------------------+
| server.hy: serve-stdio -> handle-line -> dispatch (pure function) |
|                                                                   |
|   +-----------------------------------------------------------+   |
|   | policy.hy: ToolPolicy                                     |   |
|   | - allowlist check         - Path.is_relative_to guard     |   |
|   | - result limit clamping   - JSONL audit log -> stderr     |   |
|   +-----------------------------------------------------------+   |
|                               |                                   |
|                               v                                   |
|   +-----------------------------------------------------------+   |
|   | NSK Engine (imported via nsk_path.hy, neural disabled)    |   |
|   | - Graph triplestore       - Datalog rules + provenance    |   |
|   +-----------------------------------------------------------+   |
+-------------------------------------------------------------------+
```

## Why It Matters

When you wire a tool directly into one SDK, three engineering problems appear as soon as the project grows:

1. **Every host needs its own adapter.** A function registered for Ollama chat cannot be called by an IDE assistant, a CLI agent, or another team's orchestrator without writing a new wrapper.
2. **Tools run in the same trust domain as the caller.** If a model is tricked by prompt injection into passing `"../../etc/passwd"` to a file reader or requesting ten million rows from a database, nothing between the model and the Python function stops it unless you build a policy layer yourself.
3. **Testing requires mocking the model or the transport.** If tool dispatch is tangled up with network sockets or standard I/O streams, unit tests become slow and brittle.

Implementing the MCP wire protocol directly in Hy shows that there is no magic inside an MCP SDK: every interaction is a plain dictionary sent over a stream. Separating the pure JSON-RPC dispatcher (`request dict -> response dict`) from the `stdio` loop lets us test the entire server contract in memory in milliseconds, and then verify the process boundary with a single subprocess test.

## The Hy Angle

Hy is well suited to protocol servers and symbolic tool backends:

- **S-expressions as a safe query and data format.** Our `ask` and `explain` tools accept NSK patterns such as `"[?book :author ?who] [?who :codes-in ?lang]"`, and `load-facts` reads `(:add ...)` and `(:rule ...)` forms from disk. Using `hy.read-many` with `nsk.terms.to-pattern` parses these forms into data structures without ever calling `eval`.
- **Compact dictionary and list comprehensions.** JSON-RPC payloads are nested dictionaries and lists. Hy's `lfor`, `dfor`, `sfor`, and dictionary unpacking (`{#** base ...}`) build schemas and structured provenance payloads concisely.
- **Direct module reuse.** We do not modify a single line of the existing NSK package. A 20-line helper module (`nsk_path.hy`) adds `../nsk-neural-symbolic-graph` to `sys.path`, imports `Graph` and `run-query`, and turns off the Ollama neural fallback so every MCP tool call is deterministic and offline-safe.

## Brief Python Equivalent

In Python, dispatching a JSON-RPC request and building a tool response with provenance uses dictionary literals and dictionary comprehensions:

```python
# Python
def rpc_result(req_id, result):
    return {"jsonrpc": "2.0", "id": req_id, "result": result}

def format_bindings(row):
    return {k: term_to_json(v) for k, v in row.items()}
```

In Hy, the same logic uses `dfor`:

```hy
;; Hy
(defn rpc-result [req-id result]
  {"jsonrpc" "2.0" "id" req-id "result" result})

(defn format-bindings [row]
  (dfor [k v] (.items row) k (term-to-json v)))
```

## Run It

Synchronize the environment, run the test suite, and run the client demo from **source_code_for_examples/nsk_mcp**:

```bash
cd source_code_for_examples/nsk_mcp
uv sync
uv run pytest -q
uv run hy client.hy
```

Here is the real output from running the tests and `client.hy`:

```text
.............                                                            [100%]
13 passed in 0.37s
Connected to nsk-mcp v0.1.0 (protocol 2025-11-25)
Tools: ask, add-fact, graph-stats, explain, load-facts
Initial stats: 21 triples (12 facts, 9 derived), 3 rules

--- 1. Query with rule provenance (ask) ---
  book=nsk, who=mark, lang=lisp  ; rule: ['nsk', 'author', 'mark']
  book=nsk, who=mark, lang=hy  ; rule: ['nsk', 'author', 'mark']
  book=hy-book, who=mark, lang=lisp  ; rule: ['hy-book', 'author', 'mark']
  book=hy-book, who=mark, lang=hy  ; rule: ['hy-book', 'author', 'mark']
  book=nsk, who=jane, lang=python  ; rule: ['nsk', 'author', 'jane']

--- 2. Explain a rule-derived query (explain) ---
  {'person': 'mark'} <- [{'triple': ['mark', 'knows-topic', 'mcp'], 'source': 'rule', 'note': 'derived by rule: [:mark :knows-topic :mcp]'}]

--- 3. Load allowlisted file (load-facts) ---
  loaded 4 facts and 0 rules from extra_facts.sexp

--- 4. Reject path traversal (load-facts) ---
  isError=True -> error: path escapes allowlisted data dir: ../../etc/passwd

--- 5. Read resource and prompt ---
  nsk://graph/rules has 3 rules
  prompt message: Call the `ask` tool with query `[?author :wrote :nsk] [?author :codes-in ?lang]` and summarize the bindings and provenance.
```

### Interpreting the Output

Look closely at the five sections of the demo output:

1. **Handshake and discovery.** `StdioMcpClient` spawns `hy server.hy` as a child process, sends `initialize` with protocol version `2025-11-25`, follows up with the `notifications/initialized` notification, and calls `tools/list`. The server reports 12 asserted facts, 3 rules, and 9 triples derived by forward chaining (21 triples total).
2. **Provenance preservation (`ask`).** The query `[?book :author ?who] [?who :codes-in ?lang]` joins a rule-derived predicate (`:author`, derived from `[?person :wrote ?work]`) with an asserted predicate (`:codes-in`). Every solution carries its `support` list in `structuredContent`, showing which rule triple proved that row.
3. **Rule explanation (`explain`).** Querying `[?person :knows-topic :mcp]` traces how `:mark` is linked to `:mcp` through the rule `[?person :knows-topic ?topic] <- [?person :wrote ?work] [?work :covers ?topic]`.
4. **Path traversal defense (`load-facts`).** Loading `"extra_facts.sexp"` succeeds because the file resolves inside the allowlisted `data/` directory. Passing `"../../etc/passwd"` is caught by `ToolPolicy.resolve-safe-path` and returned as an MCP tool error (`isError=True`) rather than crashing the server or leaking host files.
5. **Resources and prompts.** Reading `nsk://graph/rules` returns the three active Datalog rules as JSON, and `prompts/get` for `find-authors` returns a ready-to-use user message instructing an agent how to query the graph.

## Seed Data Format

Before looking at the code, inspect **source_code_for_examples/nsk_mcp/data/authors.log**, which the server loads on startup:

```hy
;; Seed facts for the nsk_mcp server.
(:add :mark :wrote :nsk)
(:add :mark :wrote :hy-book)
(:add :mark :codes-in :lisp)
(:add :mark :codes-in :hy)
(:add :mark :lives-in :sedona)
(:add :jane :wrote :nsk)
(:add :jane :codes-in :python)
(:add :jane :lives-in :oslo)
(:add :nsk :uses :unification)
(:add :nsk :uses :datalog)
(:add :hy-book :covers :mcp)
(:add :hy-book :covers :nsk)
(:rule [?work :author ?person] [?person :wrote ?work])
(:rule [?person :coauthor ?other] [?person :wrote ?work] [?other :wrote ?work])
(:rule [?person :knows-topic ?topic] [?person :wrote ?work] [?work :covers ?topic])
```

And **data/extra_facts.sexp** holds additional facts that an agent can load on demand with the `load-facts` tool:

```hy
;; Extra facts loaded on demand by the load-facts tool.
(:add :ada :wrote :notes-g)
(:add :ada :codes-in :analytical-engine)
(:add :alan :wrote :computing-machinery)
(:add :notes-g :covers :algorithms)
```

## How It Works

### 1. Reusing NSK Without Modification: `nsk_path.hy`

To keep a single source of truth for the knowledge graph engine, **nsk_path.hy** resolves `../nsk-neural-symbolic-graph` relative to its own file path, inserts that directory at the front of `sys.path`, imports the NSK symbols we need, and sets `(get nsk.config "enabled") False` so `~` predicates never call out to Ollama during MCP requests:

```hy
;; nsk_path.hy -- Locate the NSK example package and disable neural fallback.

(import sys)
(import pathlib [Path])

(setv ROOT (.resolve (. (Path __file__) parent))
      NSK-DIR (.resolve (/ ROOT ".." "nsk-neural-symbolic-graph"))
      DATA-DIR (.resolve (/ ROOT "data")))

(when (not-in (str NSK-DIR) sys.path)
  (.insert sys.path 0 (str NSK-DIR)))

(import nsk)
(import nsk.terms [Var Neural show to-term to-pattern to-keyword])
(import nsk.store [Graph])
(import nsk.query [QueryResult run-query saturate])

;; Disable the Ollama neural fallback for deterministic MCP tool execution.
(setv (get nsk.config "enabled") False)
```

### 2. The Security Boundary: `policy.hy`

An MCP server should treat tool arguments as untrusted input. Even when you trust the user, a model can be steered by untrusted text inside a webpage or document to call tools with unexpected arguments. **policy.hy** defines `ToolPolicy`, which enforces five controls:

1. **Deny-by-default tool allowlist (`check-tool`).** Only tool names present in `self.allowed-tools` may be listed or called.
2. **Result limit clamping (`clamp-limit`).** Queries default to 25 rows and are capped at 100 rows so a broad pattern like `[?s ?p ?o]` cannot flood the client's context window.
3. **Path-traversal defense (`resolve-safe-path`).** Any relative path passed to `load-facts` is resolved with `Path.resolve` and checked with `.is-relative-to` against `self.data-dir`. Attempts to escape via `..` or symlinks raise `PolicyError`.
4. **Execution timeouts (`run-with-timeout`).** Each tool call runs inside a single-worker `ThreadPoolExecutor` with a configurable timeout (2 seconds by default).
5. **Stderr audit logging (`audit`).** Every JSON-RPC method and tool outcome is written as one JSON line to `self.audit-stream`, which defaults to `sys.stderr`. In stdio MCP, `stdout` belongs exclusively to the JSON-RPC wire protocol; writing logs or debug prints to `stdout` corrupts the stream.

Here is **policy.hy**:

```hy
;; policy.hy -- Security boundary: allowlists, path validation, limits, audit log.

(import json)
(import sys)
(import time)
(import concurrent.futures [ThreadPoolExecutor TimeoutError])
(import pathlib [Path])

(setv DEFAULT-ALLOWED-TOOLS #{"ask" "add-fact" "graph-stats" "explain" "load-facts"}
      MAX-LIMIT 100
      DEFAULT-LIMIT 25
      DEFAULT-TIMEOUT 2.0)


(defclass PolicyError [ValueError]
  "Raised when a tool call violates the server policy.")


(defclass ToolPolicy []
  "Deny-by-default security policy for MCP tool calls."

  (defn __init__ [self
                  [allowed-tools None]
                  [data-dir None]
                  [max-limit MAX-LIMIT]
                  [default-limit DEFAULT-LIMIT]
                  [timeout-seconds DEFAULT-TIMEOUT]
                  [audit-stream None]]
    (setv self.allowed-tools (set (if (is allowed-tools None)
                                      DEFAULT-ALLOWED-TOOLS
                                      allowed-tools))
          self.data-dir (.resolve (Path (if (is data-dir None) "data" data-dir)))
          self.max-limit max-limit
          self.default-limit default-limit
          self.timeout-seconds timeout-seconds
          self.audit-stream (if (is audit-stream None) sys.stderr audit-stream))
    None)

  (defn check-tool [self name]
    "Raise PolicyError if name is not in the allowlist."
    (when (not-in name self.allowed-tools)
      (raise (PolicyError f"tool denied by policy: {name}"))))

  (defn clamp-limit [self requested]
    "Return a positive result limit bounded by self.max-limit."
    (when (is requested None)
      (return self.default-limit))
    (setv n (int requested))
    (when (<= n 0)
      (raise (PolicyError f"limit must be positive, got {n}")))
    (min n self.max-limit))

  (defn resolve-safe-path [self rel-path]
    "Resolve rel-path inside self.data-dir and reject path traversal."
    (when (or (not (isinstance rel-path str)) (not (.strip rel-path)))
      (raise (PolicyError "path must be a non-empty string")))
    (setv candidate (.resolve (/ self.data-dir rel-path)))
    (when (not (.is-relative-to candidate self.data-dir))
      (raise (PolicyError f"path escapes allowlisted data dir: {rel-path}")))
    (when (not (.is-file candidate))
      (raise (PolicyError f"file not found in data dir: {rel-path}")))
    candidate)

  (defn run-with-timeout [self fn #* args]
    "Run (fn #* args) under a wall-clock timeout."
    (with [pool (ThreadPoolExecutor :max-workers 1)]
      (setv future (.submit pool fn #* args))
      (try
        (.result future :timeout self.timeout-seconds)
        (except [TimeoutError]
          (raise (PolicyError
                   f"tool timed out after {self.timeout-seconds}s"))))))

  (defn audit [self event #** fields]
    "Write one JSONL audit record to self.audit-stream (never stdout)."
    (setv record {"ts" (round (time.time) 3)
                  "event" event
                  #** fields})
    (.write self.audit-stream (+ (json.dumps record :sort-keys True) "\n"))
    (.flush self.audit-stream)))
```

### 3. Tools and Query Helpers in `server.hy`

The first half of **server.hy** converts between JSON values and NSK terms, and implements the five graph tools (`tool-ask`, `tool-add-fact`, `tool-graph-stats`, `tool-explain`, and `tool-load-facts`). Notice that `parse-query-string` and `load-sexp-file` both use `hy.read-many` and `to-pattern`, so an s-expression string from a client can never execute arbitrary code:

```hy
(defn parse-query-string [query-str]
  "Parse one or more [s p o] patterns from an s-expression string without eval."
  (when (or (not (isinstance query-str str)) (not (.strip query-str)))
    (raise (ValueError "query must be a non-empty string of [s p o] patterns")))
  (setv forms (list (hy.read-many query-str)))
  (when (not forms)
    (raise (ValueError "query contained no patterns")))
  (lfor form forms (to-pattern form)))

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

(defn tool-ask [graph policy args]
  (setv query-str (.get args "query")
        limit (policy.clamp-limit (.get args "limit"))
        patterns (parse-query-string query-str)
        result (run-query patterns :graph graph :neural False :limit limit)
        structured (result-to-structured result))
  (setv (get structured "limit") limit)
  structured)

(defn tool-load-facts [graph policy args]
  (setv rel-path (.get args "file" "")
        safe-path (policy.resolve-safe-path rel-path)
        [added-facts added-rules] (load-sexp-file graph safe-path))
  {"file" rel-path
   "added_facts" added-facts
   "added_rules" added-rules
   "total_triples" (len graph)
   "text" f"loaded {added-facts} facts and {added-rules} rules from {rel-path}"})
```

### 4. The Pure JSON-RPC Dispatcher and Stdio Loop in `server.hy`

MCP uses JSON-RPC 2.0 messages. A request has `"jsonrpc": "2.0"`, an `"id"`, a `"method"`, and optional `"params"`. A notification omits `"id"` and must not receive a reply. Errors at the protocol layer (such as an unknown method `-32601`, invalid parameters `-32602`, or malformed JSON `-32700`) return a JSON-RPC `"error"` object. Errors inside a tool call (such as bad query syntax or a policy rejection) return a normal JSON-RPC `"result"` with `"isError": True` and an explanation in `"content"`, so the language model can see what went wrong and recover.

In specification revision `2025-11-25`, a `tools/call` result can include both human-readable `"content"` blocks and machine-readable `"structuredContent"`. Here is the dispatcher and stdio loop from **server.hy**:

```hy
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
```

Notice how `dispatch` and `handle-line` are decoupled from `sys.stdin` and `sys.stdout`. `serve-stdio` is only ten lines of code at the bottom of the file.

### 5. The Stdio Client: `client.hy`

To verify our server from the outside and show how any MCP host interacts with a stdio server, **client.hy** defines `StdioMcpClient`. It uses `subprocess.Popen` with line-buffered text pipes (`:bufsize 1`, `:text True`) and implements context-manager methods (`__enter__` and `__exit__`) so the child process is always cleaned up when the `with` block exits:

```hy
(defclass StdioMcpClient []
  "A synchronous MCP client that talks to a child process over stdio."

  (defn __init__ [self [command None] [cwd None] [capture-stderr True]]
    (setv self.command (if (is command None)
                           [sys.executable "-m" "hy" SERVER-PATH]
                           (list command))
          self.cwd (if (is cwd None) (str HERE) (str cwd))
          self.capture-stderr capture-stderr
          self.proc None
          self._next-id 0)
    None)

  (defn __enter__ [self]
    (setv self.proc (subprocess.Popen
                      self.command
                      :cwd self.cwd
                      :stdin subprocess.PIPE
                      :stdout subprocess.PIPE
                      :stderr (if self.capture-stderr subprocess.PIPE sys.stderr)
                      :text True
                      :encoding "utf-8"
                      :bufsize 1))
    self)

  (defn __exit__ [self #* exc-info]
    (self.close))

  (defn request [self method [params None]]
    "Send a JSON-RPC request and wait for the matching response line."
    (setv self._next-id (+ self._next-id 1)
          req-id self._next-id
          msg {"jsonrpc" "2.0" "id" req-id "method" method})
    (when (is-not params None)
      (setv (get msg "params") params))
    (self._send msg)
    (setv line (.readline self.proc.stdout))
    (when (not line)
      (raise (McpClientError f"server closed stdout while waiting for {method}")))
    (setv resp (json.loads line))
    (when (in "error" resp)
      (setv err (get resp "error"))
      (raise (McpClientError f"RPC error {(get err "code")}: {(get err "message")}")))
    (get resp "result"))

  (defn initialize [self]
    "Run the MCP initialize handshake."
    (setv res (self.request "initialize"
                {"protocolVersion" "2025-11-25"
                 "capabilities" {}
                 "clientInfo" {"name" "nsk-hy-client" "version" "0.1.0"}}))
    (self.notify "notifications/initialized")
    res)

  (defn call-tool [self name [arguments None]]
    (self.request "tools/call"
      {"name" name
       "arguments" (if (is arguments None) {} arguments)})))
```

## Connecting to an MCP Host, SDKs, and Remote Transports

Because `server.hy` speaks standard MCP over `stdio`, any MCP-capable host (such as Claude Desktop, Cursor, Zed, or an open-source MCP host) can launch it directly using `uv`:

```json
{
  "mcpServers": {
    "nsk-graph": {
      "command": "uv",
      "args": [
        "run",
        "--directory",
        "/path/to/hy-lisp-python-book/source_code_for_examples/nsk_mcp",
        "hy",
        "server.hy"
      ]
    }
  }
}
```

### Official `mcp` Python SDK and Streamable HTTP

We wrote our JSON-RPC dispatcher directly so every protocol message and error code is visible in plain Hy. In larger services you can also import the official Python `mcp` package (`FastMCP`) from Hy, or expose the same pure `dispatch` function over MCP's **Streamable HTTP** transport (`POST /mcp` accepting JSON-RPC messages and returning either `application/json` or `text/event-stream`). Because `dispatch` in `server.hy` takes a dictionary and returns a dictionary, wrapping it in an HTTP endpoint takes only a few lines of code, and the same `ToolPolicy` class continues to enforce allowlists, limits, and timeouts. When deploying over Streamable HTTP, always add authentication (such as OAuth 2.1 bearer tokens) and bind to `127.0.0.1` during local development.

### Comparing MCP, Direct Function Calling, and Agno Tools

| Approach | Where we used it | Best for | Tradeoffs |
| --- | --- | --- | --- |
| **Direct function calling** (`ollama.chat :tools [...]`) | *Running Local LLMs Using Ollama* | Single-script utilities with 2 to 5 local functions | Tied to one provider's SDK; no separate process or resource/prompt primitives |
| **Framework decorator** (`(defn [tool] ...)` in Agno) | *Agents Using the Agno Agent Framework* | Rapid single-process agents with built-in prompt loops | Coupled to the agent framework; tools live inside the same Python process |
| **MCP server** (`server.hy` over `stdio` or Streamable HTTP) | This chapter (`nsk_mcp`) | Sharing a stateful engine (like NSK) across many hosts, languages, and agents with a clear process and security boundary | Slight protocol overhead (process spawn + JSON-RPC serialization) |

## Tests

The test suite in **test_mcp.hy** runs without network access or a live model. Twelve tests call `dispatch` or `handle-line` directly in memory against JSON fixtures, and one test (`test-stdio-client-server-round-trip`) spawns the server subprocess over `stdio` via `StdioMcpClient`:

```hy
(defn make-env [[allowed None] [timeout 2.0]]
  "Return #(graph policy audit-buf) for fast in-memory dispatcher tests."
  (setv buf (io.StringIO)
        graph (make-seed-graph)
        pol (ToolPolicy :allowed-tools allowed
                        :data-dir DATA-DIR
                        :timeout-seconds timeout
                        :audit-stream buf))
  #(graph pol buf))

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
```

## Wrap Up

We built a standards-compliant MCP server and client in Hy without external protocol dependencies, connected it to the NSK knowledge graph engine, and wrapped every tool invocation in an explicit security policy. Keeping the JSON-RPC dispatcher pure (`dispatch`) made it simple to test both normal graph queries and adversarial inputs in memory before running over `stdio`.

## Optional Practice Problems

1. **Add a `remove-fact` Tool with Policy Control**:
   Add a `remove-fact` tool to `server.hy` that calls `graph.remove` on a ground `[subject predicate object]` triple and returns whether the triple was present. Exclude `"remove-fact"` from `DEFAULT-ALLOWED-TOOLS` in `policy.hy` so it is denied by default, and write a test in `test_mcp.hy` verifying that `remove-fact` is blocked under the default policy and succeeds only when `"remove-fact"` is explicitly passed to `ToolPolicy`.
2. **Expose a Streamable HTTP Endpoint for `dispatch`**:
   Write a small `http_server.hy` module using Python's `http.server.BaseHTTPRequestHandler` (similar to `nsk/server.hy`) that accepts `POST /mcp` requests with a JSON-RPC 2.0 body, passes the parsed dictionary to `server.dispatch`, and returns HTTP `202 Accepted` when `dispatch` returns `None` (a notification) or HTTP `200 OK` with `application/json` when `dispatch` returns a response dictionary. Add a header check requiring an `Authorization: Bearer <token>` header from an environment variable.

## Further Reading

- [Model Context Protocol Specification (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25) for the full lifecycle, capability negotiation, and security best practices.
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification) for request, notification, and error object definitions.
- *AI Engineering* by Chip Huyen (O'Reilly, 2025) for agent tool design, guardrails, and operational safety.
