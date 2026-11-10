;; query.hy -- Pattern matching, rules, the neural fallback, and the ask macro.
;;
;; A query is a conjunction of triple patterns. The engine proves them left to
;; right with generators: each pattern yields one environment per match, and
;; the next pattern continues from there. Nothing is computed until a caller
;; asks for the next solution, so :limit 1 stops after the first proof.
;;
;; Every solution carries its support: the triples in the proof that are not
;; plain facts, each with its source. That is how a result can tell you which
;; answers came from the model.

(import hy.models [Keyword List])
(import nsk.terms [Var Neural show unify resolve ground? variables
                   compile-term compile-pattern])
(import nsk.store [current-graph])
(import nsk [neural])


(defn match-pattern [pattern env graph [use-model True]]
  "Yield (env, support) for every way pattern holds under env. A ~ predicate
  is matched symbolically first and sent to the model only when that fails."
  (setv [s p o] (resolve pattern env)
        fuzzy (isinstance p Neural))
  (when fuzzy
    (setv p (walk-name p env)))
  (setv found False)
  (for [triple (graph.candidates #(s p o))]
    (setv extended (unify #(s p o) triple env))
    (when (is-not extended None)
      (setv found True
            source (.get graph.triples triple "fact"))
      (yield #(extended (if (= source "fact") #() #(#(triple source)))))))
  (when (and fuzzy use-model (not found))
    (setv triple (neural.infer s p o graph))
    (when triple
      (setv extended (unify #(s p o) triple env))
      (when (is-not extended None)
        (yield #(extended #(#(triple "neural"))))))))

(defn walk-name [predicate env]
  (resolve predicate.name env))

(defn prove [patterns env graph [use-model True] [support #()]]
  "Yield (env, support) for every proof of the conjunction of patterns."
  (if (not patterns)
      (yield #(env support))
      (for [[extended used] (match-pattern (get patterns 0) env graph use-model)]
        (yield :from (prove (cut patterns 1 None) extended graph use-model
                            (+ support used))))))


;; ---------- rules ----------
;;
;; A rule derives new triples from existing ones:
;;
;;   [?x :grandparent ?z]  <-  [?x :parent ?y] [?y :parent ?z]
;;
;; Rules run forward to a fixed point: keep applying every rule until a full
;; pass adds nothing. The derived triples are stored with the source "rule"
;; and rebuilt whenever a fact or a rule changes. Because derived triples are
;; ordinary indexed triples, recursive rules need no special care at query
;; time. Rules never call the model.

(defn saturate [graph]
  "Bring the rule-derived triples up to date."
  (when (not graph.stale)
    (return))
  (for [[triple _] (graph.facts "rule")]
    (graph.remove triple))
  (setv changed (bool graph.rules))
  (while changed
    (setv changed False)
    (for [[head body] graph.rules]
      (for [[env _] (list (prove body {} graph :use-model False))]
        (setv triple (resolve head env))
        (when (and (ground? triple) (graph.add triple "rule"))
          (setv changed True)))))
  (setv graph.stale False))


;; ---------- results ----------

(defclass QueryResult []
  "The solutions of a query. Iterate over it to get one dict per solution,
  keyed by variable name. The support list runs parallel to the rows."

  (defn __init__ [self rows support]
    (setv self.rows rows
          self.support support))

  (defn __iter__ [self] (iter self.rows))
  (defn __len__ [self] (len self.rows))
  (defn __getitem__ [self index] (get self.rows index))

  (defn column [self name]
    "Return the values of one variable across all solutions."
    (lfor row self.rows (get row name)))

  (defn __str__ [self]
    (cond
      (not self.rows) "no"
      (= self.rows [{}]) (+ "yes" (explain (get self.support 0)))
      True (.join "\n"
             (gfor [row used] (zip self.rows self.support)
               (+ (.join ", " (gfor [name value] (.items row)
                                f"{name}={(show value)}"))
                  (explain used))))))

  (defn __repr__ [self] f"<QueryResult {(len self.rows)} solutions>"))

(defn explain [used]
  (if used
      (+ "    ; " (.join ", " (gfor [triple source] used
                                f"{source}: {(show triple)}")))
      ""))

(defn run-query [patterns [select None] [graph None] [neural True] [limit None]]
  "Prove patterns and return a QueryResult that binds the select variables.
  With no select list, every variable in the patterns is returned."
  (setv graph (if (is graph None) (current-graph) graph)
        patterns (lfor pattern patterns (tuple pattern))
        select (if (is select None) (variables patterns) (list select))
        rows []
        support []
        seen #{})
  (with [graph.lock]
    (saturate graph)
    (for [[env used] (prove patterns {} graph :use-model neural)]
      (setv values (resolve (tuple select) env))
      (when (not-in values seen)
        (.add seen values)
        (.append rows (dict (zip (gfor v select v.name) values)))
        (.append support used))
      (when (and limit (>= (len rows) limit))
        (break))))
  (QueryResult rows support))


;; ---------- macros ----------

(defn split-options [forms]
  "Macro helper: separate the [s p o] patterns from trailing :key value pairs."
  (setv patterns (lfor form forms :if (isinstance form List) form))
  #(patterns (cut forms (len patterns) None)))

(defmacro ask [select #* body]
  "Run a Datalog-style query.

    (ask [?author ?lang]
      [?author :wrote :nsk]
      [?author ~:codes-in ?lang])

  The first list names the variables to return. Each later list is a triple
  pattern. Anything in a pattern that is not a ?variable or a ~predicate is
  ordinary Hy and is evaluated. Options follow the patterns:
  :graph g, :limit n, :neural False."
  (setv [patterns options] (hy.I.nsk/query.split-options body))
  `(hy.I.nsk/query.run-query
     [~@(map hy.I.nsk/terms.compile-pattern patterns)]
     [~@(map hy.I.nsk/terms.compile-term select)]
     ~@options))

(defmacro rule [head #* body]
  "Add a rule to the default graph, or to the one given by :graph.

    (rule [?x :grandparent ?z]  [?x :parent ?y] [?y :parent ?z])"
  (setv [patterns options] (hy.I.nsk/query.split-options body)
        graph (if options (get options 1) '(hy.I.nsk/store.current-graph)))
  `(.add-rule ~graph
     ~(hy.I.nsk/terms.compile-pattern head)
     [~@(map hy.I.nsk/terms.compile-pattern patterns)]))
