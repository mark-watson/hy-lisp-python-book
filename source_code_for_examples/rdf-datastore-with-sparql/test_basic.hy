;; Self-contained test of all RDF datastore + SPARQL logic
;; (Avoids cross-module import for sandbox-constrained testing)

;; --- RDF Triple representation ---
(defn make-triple [subject predicate object]
  {"subject" subject "predicate" predicate "object" object})
(defn triple-subject [triple] (get triple "subject"))
(defn triple-predicate [triple] (get triple "predicate"))
(defn triple-object [triple] (get triple "object"))

;; --- Helpers ---
(defn variable-p [s]
  (and (isinstance s str) (> (len s) 0) (= (get s 0) "?")))

(defn triple-to-binding [triple pattern]
  (setv binding {})
  (when (variable-p (get pattern 0))
    (setv (get binding (get pattern 0)) (triple-subject triple)))
  (when (variable-p (get pattern 1))
    (setv (get binding (get pattern 1)) (triple-predicate triple)))
  (when (variable-p (get pattern 2))
    (setv (get binding (get pattern 2)) (triple-object triple)))
  binding)

(defn apply-bindings [pattern bindings]
  (lfor item pattern
        (if (and (variable-p item) (in item bindings))
            (get bindings item)
            item)))

(defn merge-bindings [b1 b2]
  (| (dict b1) (dict b2)))

(defn parse-where-patterns [tokens]
  (setv patterns [])
  (setv current [])
  (for [tok tokens]
    (if (= tok ".")
        (do
          (when current
            (.append patterns (list current))
            (setv current [])))
        (.append current tok)))
  (when current
    (.append patterns (list current)))
  patterns)

(defn parse-sparql-query [query-string]
  (setv tokens (lfor tok (.split query-string)
                     :if (not (in tok ["{" "}"]))
                     tok))
  (setv lower-tokens (lfor t tokens (.lower t)))
  (setv select-idx (.index lower-tokens "select"))
  (setv where-idx (.index lower-tokens "where"))
  (setv select-vars (cut tokens (+ select-idx 1) where-idx))
  (setv where-tokens (cut tokens (+ where-idx 1) None))
  (setv where-patterns (parse-where-patterns where-tokens))
  {"select-vars" select-vars "where-patterns" where-patterns})

;; --- RdfStore class ---
(defclass RdfStore []
  (defn __init__ [self]
    (setv self.triples []))

  (defn add-triple [self subject predicate object]
    (.append self.triples (make-triple subject predicate object)))

  (defn remove-triple [self subject predicate object]
    (setv self.triples
          (lfor t self.triples
                :if (not (and (= (triple-subject t) subject)
                              (= (triple-predicate t) predicate)
                              (= (triple-object t) object)))
                t)))

  (defn print-all-triples [self]
    (print "All triples in the datastore:")
    (for [t self.triples]
      (print f"  {(triple-subject t)}  {(triple-predicate t)}  {(triple-object t)}"))
    (print))

  (defn query-triples [self subject predicate object]
    (lfor t self.triples
          :if (and (or (is subject None) (variable-p subject)
                       (= (triple-subject t) subject))
                   (or (is predicate None) (variable-p predicate)
                       (= (triple-predicate t) predicate))
                   (or (is object None) (variable-p object)
                       (= (triple-object t) object)))
          t))

  (defn execute-sparql [self query-string]
    (let [parsed (parse-sparql-query query-string)
          select-vars (get parsed "select-vars")
          where-patterns (get parsed "where-patterns")
          results (execute-where-patterns self where-patterns)
          projected (project-results results select-vars)]
      projected)))

;; --- SPARQL execution ---
(defn execute-where-patterns [store patterns]
  (if (not patterns)
      [{}]
      (let [pattern (get patterns 0)
            remaining (cut patterns 1 None)
            matching (store.query-triples (get pattern 0)
                                          (get pattern 1)
                                          (get pattern 2))
            bindings (lfor t matching (triple-to-binding t pattern))]
        (if (not remaining)
            bindings
            (do
              (setv results [])
              (for [binding bindings]
                (setv sub-results
                      (execute-where-with-bindings store remaining binding))
                (for [sr sub-results]
                  (.append results (merge-bindings binding sr))))
              results)))))

(defn execute-where-with-bindings [store patterns bindings]
  (if (not patterns)
      [bindings]
      (let [pattern (get patterns 0)
            remaining (cut patterns 1 None)
            bound-pattern (apply-bindings pattern bindings)
            matching (store.query-triples (get bound-pattern 0)
                                          (get bound-pattern 1)
                                          (get bound-pattern 2))
            new-bindings (lfor t matching
                               (merge-bindings bindings
                                               (triple-to-binding t pattern)))]
        (if (not remaining)
            new-bindings
            (do
              (setv results [])
              (for [nb new-bindings]
                (setv sub-results
                      (execute-where-with-bindings store remaining nb))
                (for [sr sub-results]
                  (.append results sr)))
              results)))))

(defn project-results [results select-vars]
  (if (= select-vars ["*"])
      (lfor r results (dict r))
      (lfor r results
            (dfor var select-vars var (.get r var None)))))

;; --- Test harness ---
(defn print-query-results [store query-string]
  (print f"Query: {query-string}")
  (setv results (store.execute-sparql query-string))
  (print "Results:")
  (if results
      (do
        (for [result results]
          (setv parts (lfor #(var val) (.items result)
                            f"{var}: {val}"))
          (print (+ "  " (.join ", " parts)))))
      (print "  No results"))
  (print))

;; --- Run tests ---
(setv store (RdfStore))

(store.add-triple "John" "age" "30")
(store.add-triple "John" "likes" "pizza")
(store.add-triple "Mary" "age" "25")
(store.add-triple "Mary" "likes" "sushi")
(store.add-triple "Bob" "age" "35")
(store.add-triple "Bob" "likes" "burger")

(store.print-all-triples)

(print-query-results store
  "select * where { ?name age ?age . ?name likes ?food }")

(print-query-results store
  "select ?s ?o where { ?s likes ?o }")

(print-query-results store
  "select * where { ?name age ?age . ?name likes pizza }")

(print "--- After removing (Bob age 35) ---")
(store.remove-triple "Bob" "age" "35")
(print-query-results store
  "select * where { ?name age ?age }")
