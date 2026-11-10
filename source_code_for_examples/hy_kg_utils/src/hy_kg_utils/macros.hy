"Compile-time macros for hy_kg_utils."


(defmacro with-graph [binding #* body]
  "Bind a fresh GraphClient (with optional seed triples) and close it on exit.

  Usage:
    (with-graph [g]
      (.add g \"hy\" \"is-a\" \"lisp\"))

    (with-graph [g [#(\"hy\" \"is-a\" \"lisp\")]]
      (query->rows g :s \"hy\"))"
  (when (or (not (isinstance binding hy.models.Sequence))
            (< (len binding) 1)
            (> (len binding) 2))
    (raise (SyntaxError
             "with-graph expects [client-sym] or [client-sym seed-triples]")))
  (setv client-sym (get binding 0))
  (setv seed-expr (if (= (len binding) 2) (get binding 1) '[]))
  (setv seed-var (hy.gensym "seed"))
  `(do
     (setv ~client-sym (hy.I.hy_kg_utils.core.GraphClient))
     (try
       (setv ~seed-var ~seed-expr)
       (when ~seed-var
         (.add-many ~client-sym (list ~seed-var)))
       ~@body
       (finally
         (.close ~client-sym)))))


(export
  :objects []
  :macros [with-graph])
