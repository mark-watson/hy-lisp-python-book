"Demonstration script for hy_kg_utils."

(import hy_kg_utils [GraphClient])
(import hy_kg_utils.core [query->rows])
(require hy_kg_utils [with-graph])


(defn main []
  (print "=== 1. Using with-graph macro and query->rows from Hy ===")
  (setv seed [#("hy" "is-a" "lisp")
              #("hy" "compiles-to" "python-ast")
              #("hatchling" "builds" "wheel")
              #("mypy" "checks" "hy2py-output")])
  (setv rows
    (with-graph [g seed]
      (.add g "hy" "supports" "macros")
      (print f"Graph '{g.name}' has {(.count g)} triples; predicates: {(.predicates g)}")
      (query->rows g :s "hy")))
  (for [row rows]
    (print " " row))
  (print f"After with-graph block, g.closed = {g.closed}")

  (print "\n=== 2. Inspecting macro expansion and name mangling ===")
  (setv mangled (hy.mangle "query->rows"))
  (print "mangle('query->rows')  ->" mangled)
  (print "unmangle(mangled)      ->" (hy.unmangle mangled))
  (print "mangle('query-to-rows') ->" (hy.mangle "query-to-rows"))
  (print "macroexpand-1 of (with-graph [g] (.count g)):")
  (print (hy.repr (hy.macroexpand-1 '(with-graph [g] (.count g))))))


(when (= __name__ "__main__")
  (main))
