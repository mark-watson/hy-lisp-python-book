;; Copyright 2025 Mark Watson. All rights reserved. License: AGPL-v3
;;
;; Demo / test script for the simple RDF datastore with SPARQL support.
;; To run: uv run hy main.hy

(import rdf_datastore [RdfStore])

(defn print-query-results [store query-string]
  "Execute a SPARQL query and pretty-print the results."
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

(defn test []
  "Run built-in smoke tests, mirroring the Common Lisp version."
  (setv store (RdfStore))

  ;; Add triples
  (store.add-triple "John" "age" "30")
  (store.add-triple "John" "likes" "pizza")
  (store.add-triple "Mary" "age" "25")
  (store.add-triple "Mary" "likes" "sushi")
  (store.add-triple "Bob" "age" "35")
  (store.add-triple "Bob" "likes" "burger")

  (store.print-all-triples)

  ;; Query 1: join across two patterns — find name, age, and food
  (print-query-results store
    "select * where { ?name age ?age . ?name likes ?food }")

  ;; Query 2: simple single-pattern query
  (print-query-results store
    "select ?s ?o where { ?s likes ?o }")

  ;; Query 3: join with a concrete value in second pattern
  (print-query-results store
    "select * where { ?name age ?age . ?name likes pizza }")

  ;; Additional: demonstrate remove
  (print "--- After removing (Bob age 35) ---")
  (store.remove-triple "Bob" "age" "35")
  (print-query-results store
    "select * where { ?name age ?age }"))

;; Run tests when executed directly
(test)
