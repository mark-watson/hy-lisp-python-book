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
