;; client.hy -- Stdio MCP client in Hy that spawns server.hy and runs a demo.

(import json)
(import pathlib [Path])
(import subprocess)
(import sys)

(setv HERE (.resolve (. (Path __file__) parent))
      SERVER-PATH (str (/ HERE "server.hy")))


(defclass McpClientError [RuntimeError]
  "Raised when the MCP server returns a JSON-RPC or protocol error.")


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

  (defn close [self]
    (when self.proc
      (try
        (when self.proc.stdin
          (.close self.proc.stdin))
        (.wait self.proc :timeout 3)
        (except [Exception]
          (.kill self.proc)))
      (setv self.proc None)))

  (defn _send [self payload]
    (.write self.proc.stdin (+ (json.dumps payload) "\n"))
    (.flush self.proc.stdin))

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

  (defn notify [self method [params None]]
    "Send a JSON-RPC notification (no id, no response)."
    (setv msg {"jsonrpc" "2.0" "method" method})
    (when (is-not params None)
      (setv (get msg "params") params))
    (self._send msg))

  (defn initialize [self]
    "Run the MCP initialize handshake."
    (setv res (self.request "initialize"
                {"protocolVersion" "2025-11-25"
                 "capabilities" {}
                 "clientInfo" {"name" "nsk-hy-client" "version" "0.1.0"}}))
    (self.notify "notifications/initialized")
    res)

  (defn list-tools [self]
    (get (self.request "tools/list") "tools"))

  (defn call-tool [self name [arguments None]]
    (self.request "tools/call"
      {"name" name
       "arguments" (if (is arguments None) {} arguments)}))

  (defn list-resources [self]
    (get (self.request "resources/list") "resources"))

  (defn read-resource [self uri]
    (self.request "resources/read" {"uri" uri}))

  (defn list-prompts [self]
    (get (self.request "prompts/list") "prompts"))

  (defn get-prompt [self name [arguments None]]
    (self.request "prompts/get"
      {"name" name
       "arguments" (if (is arguments None) {} arguments)})))


(defn run-demo []
  (with [client (StdioMcpClient)]
    (setv init (client.initialize)
          info (get init "serverInfo"))
    (print f"Connected to {(get info "name")} v{(get info "version")} (protocol {(get init "protocolVersion")})")

    (setv tools (client.list-tools))
    (print "Tools:" (.join ", " (gfor t tools (get t "name"))))

    (setv stats (client.call-tool "graph-stats"))
    (print "Initial stats:" (get (get (get stats "content") 0) "text"))

    (print "\n--- 1. Query with rule provenance (ask) ---")
    (setv ans (client.call-tool "ask"
                {"query" "[?book :author ?who] [?who :codes-in ?lang]"
                 "limit" 10}))
    (setv structured (get ans "structuredContent"))
    (for [sol (get structured "solutions")]
      (setv b (get sol "bindings")
            sup (get sol "support")
            note (if sup
                     (+ "  ; " (.join ", " (gfor s sup
                                             f"{(get s "source")}: {(get s "triple")}")))
                     ""))
      (print f"  book={(get b "book")}, who={(get b "who")}, lang={(get b "lang")}{note}"))

    (print "\n--- 2. Explain a rule-derived query (explain) ---")
    (setv exp (client.call-tool "explain"
                {"query" "[?person :knows-topic :mcp]"}))
    (for [row (get (get exp "structuredContent") "explanations")]
      (print " " (get row "bindings") "<-" (get row "proof")))

    (print "\n--- 3. Load allowlisted file (load-facts) ---")
    (setv loaded (client.call-tool "load-facts" {"file" "extra_facts.sexp"}))
    (print " " (get (get (get loaded "content") 0) "text"))

    (print "\n--- 4. Reject path traversal (load-facts) ---")
    (setv blocked (client.call-tool "load-facts" {"file" "../../etc/passwd"}))
    (print f"  isError={(get blocked "isError")} -> {(get (get (get blocked "content") 0) "text")}")

    (print "\n--- 5. Read resource and prompt ---")
    (setv rules-res (client.read-resource "nsk://graph/rules")
          rules-data (json.loads (get (get (get rules-res "contents") 0) "text")))
    (print f"  nsk://graph/rules has {(len (get rules-data "rules"))} rules")
    (setv prompt-res (client.get-prompt "find-authors" {"work" "nsk"}))
    (print "  prompt message:"
           (get (get (get (get prompt-res "messages") 0) "content") "text"))))

(when (= __name__ "__main__")
  (run-demo))
