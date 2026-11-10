;; Command-line entry point:  uv run hy -m nsk [options]

(import argparse)
(import nsk [__version__])
(import nsk.store [Graph use-graph])
(import nsk.neural [config])
(import nsk.repl [repl])
(import nsk.server [serve])


(defn main [[argv None]]
  (setv parser (argparse.ArgumentParser
                 :prog "nsk"
                 :description "NSK: a neural-symbolic knowledge graph engine."))
  (parser.add-argument "--db" :default "nsk-graph.log" :metavar "PATH"
                       :help "transaction log (default: nsk-graph.log)")
  (parser.add-argument "--memory" :action "store_true"
                       :help "keep the graph in memory only; write no log")
  (parser.add-argument "--serve" :action "store_true"
                       :help "start the REST server instead of the REPL")
  (parser.add-argument "--host" :default "127.0.0.1"
                       :help "server address (default: 127.0.0.1)")
  (parser.add-argument "--port" :type int :default 8800
                       :help "server port (default: 8800)")
  (parser.add-argument "--model" :help f"Ollama model (default: {(get config "model")})")
  (parser.add-argument "--no-neural" :action "store_true"
                       :help "never call the model")
  (parser.add-argument "--version" :action "version" :version f"NSK {__version__}")
  (setv args (parser.parse-args argv))
  (when args.model
    (setv (get config "model") args.model))
  (when args.no-neural
    (setv (get config "enabled") False))
  (with [graph (Graph (if args.memory None args.db))]
    (use-graph graph)
    (if args.serve
        (serve graph args.host args.port)
        (repl graph))))

(when (= __name__ "__main__")
  (main))
