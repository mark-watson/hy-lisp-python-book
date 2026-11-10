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
