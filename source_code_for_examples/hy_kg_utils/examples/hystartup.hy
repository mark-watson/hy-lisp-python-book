"Example HYSTARTUP file for interactive Hy REPL sessions.

Launch a REPL with this file:
  HYSTARTUP=examples/hystartup.hy uv run hy
"

(import importlib [reload])
(import pprint [pprint])
(import hy_kg_utils [GraphClient])
(import hy_kg_utils.core [query->rows])
(require hy_kg_utils [with-graph])

(setv repl-output-fn hy.repr)


(defn expand [form]
  "Pretty-print one step of macroexpansion for a quoted form."
  (print (hy.repr (hy.macroexpand-1 form))))


(print "Loaded examples/hystartup.hy: GraphClient, query->rows, with-graph, reload, expand ready.")
