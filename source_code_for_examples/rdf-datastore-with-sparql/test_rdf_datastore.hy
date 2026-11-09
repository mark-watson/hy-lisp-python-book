;; Tests for rdf_datastore.hy  --  run with:  uv run pytest

(import rdf-datastore [RdfStore variable-p parse-sparql-query
                       parse-where-patterns apply-bindings merge-bindings
                       triple-to-binding make-triple])


;; ---------- helpers ----------

(defn sample-store []
  (setv store (RdfStore))
  (for [[s p o] [["John" "age" "30"]  ["John" "likes" "pizza"]
                 ["Mary" "age" "25"]  ["Mary" "likes" "sushi"]
                 ["Bob" "age" "35"]   ["Bob" "likes" "burger"]]]
    (store.add-triple s p o))
  store)

(defn sort-results [results]
  (sorted results :key (fn [r] (sorted (.items r)))))


;; ---------- helper functions ----------

(defn test-variable-p []
  (assert (variable-p "?x"))
  (assert (not (variable-p "x")))
  (assert (not (variable-p "")))
  (assert (not (variable-p None))))

(defn test-parse-where-patterns []
  (assert (= (parse-where-patterns ["?a" "b" "?c" "." "?a" "d" "e"])
             [["?a" "b" "?c"] ["?a" "d" "e"]]))
  (assert (= (parse-where-patterns []) [])))

(defn test-parse-sparql-query []
  (setv parsed (parse-sparql-query
                 "SELECT ?s ?o WHERE { ?s likes ?o . ?s age 30 }"))
  (assert (= (get parsed "select-vars") ["?s" "?o"]))
  (assert (= (get parsed "where-patterns")
             [["?s" "likes" "?o"] ["?s" "age" "30"]])))

(defn test-apply-and-merge-bindings []
  (assert (= (apply-bindings ["?s" "likes" "?o"] {"?s" "John"})
             ["John" "likes" "?o"]))
  (assert (= (merge-bindings {"?a" 1} {"?b" 2}) {"?a" 1 "?b" 2})))

(defn test-triple-to-binding []
  (assert (= (triple-to-binding (make-triple "John" "likes" "pizza")
                                ["?s" "likes" "?o"])
             {"?s" "John" "?o" "pizza"})))


;; ---------- RdfStore ----------

(defn test-add-and-query-triples []
  (setv store (sample-store))
  (assert (= (len store.triples) 6))
  (assert (= (len (store.query-triples "John" None None)) 2))
  (assert (= (len (store.query-triples "?s" "age" "?o")) 3))
  (assert (= (store.query-triples "Mary" "likes" "?o")
             [(make-triple "Mary" "likes" "sushi")])))

(defn test-remove-triple []
  (setv store (sample-store))
  (store.remove-triple "Bob" "age" "35")
  (assert (= (len store.triples) 5))
  (assert (= (store.query-triples "Bob" "age" None) [])))

(defn test-print-all-triples [capsys]
  (.print-all-triples (sample-store))
  (assert (in "Mary  likes  sushi" (. (capsys.readouterr) out))))


;; ---------- SPARQL ----------

(defn test-sparql-single-pattern-projection []
  (setv results ((. (sample-store) execute-sparql)
                  "select ?s ?o where { ?s likes ?o }"))
  (assert (= (sort-results results)
             (sort-results [{"?s" "John" "?o" "pizza"}
                            {"?s" "Mary" "?o" "sushi"}
                            {"?s" "Bob"  "?o" "burger"}]))))

(defn test-sparql-join []
  (setv results ((. (sample-store) execute-sparql)
                  "select * where { ?name age ?age . ?name likes ?food }"))
  (assert (= (len results) 3))
  (assert (in {"?name" "Mary" "?age" "25" "?food" "sushi"} results)))

(defn test-sparql-join-with-constant []
  (setv results ((. (sample-store) execute-sparql)
                  "select * where { ?name age ?age . ?name likes pizza }"))
  (assert (= results [{"?name" "John" "?age" "30"}])))

(defn test-sparql-no-results []
  (assert (= ((. (sample-store) execute-sparql)
               "select ?s where { ?s likes tacos }")
             [])))

(defn test-sparql-after-remove []
  (setv store (sample-store))
  (store.remove-triple "Bob" "age" "35")
  (setv names (sorted (lfor r (store.execute-sparql
                                "select ?name where { ?name age ?age }")
                            (get r "?name"))))
  (assert (= names ["John" "Mary"])))
