;; Copyright 2025 Mark Watson. All rights reserved. License: AGPL-v3
;;
;; Simple in-memory RDF triple store with partial SPARQL query support.
;; Ported from the Common Lisp implementation.

;; --- RDF Triple representation ---

;; A triple is stored as a dictionary with keys "subject", "predicate", "object".

(defn make-triple [subject predicate object]
  "Create an RDF triple (as a dict)."
  {"subject" subject "predicate" predicate "object" object})

(defn triple-subject [triple]
  (get triple "subject"))

(defn triple-predicate [triple]
  (get triple "predicate"))

(defn triple-object [triple]
  (get triple "object"))

;; --- RDF Datastore ---

(defclass RdfStore []
  "An in-memory RDF triple store with SPARQL query support."

  (defn __init__ [self]
    (setv self.triples []))

  (defn add-triple [self subject predicate object]
    "Add a triple to the datastore."
    (.append self.triples (make-triple subject predicate object)))

  (defn remove-triple [self subject predicate object]
    "Remove all triples matching the given subject, predicate, object."
    (setv self.triples
          (lfor t self.triples
                :if (not (and (= (triple-subject t) subject)
                              (= (triple-predicate t) predicate)
                              (= (triple-object t) object)))
                t)))

  (defn print-all-triples [self]
    "Print every triple in the store."
    (print "All triples in the datastore:")
    (for [t self.triples]
      (print f"  {(triple-subject t)}  {(triple-predicate t)}  {(triple-object t)}"))
    (print))

  (defn query-triples [self subject predicate object]
    "Return all triples matching the pattern (None or ?-vars are wildcards)."
    (lfor t self.triples
          :if (and (or (is subject None) (variable-p subject)
                       (= (triple-subject t) subject))
                   (or (is predicate None) (variable-p predicate)
                       (= (triple-predicate t) predicate))
                   (or (is object None) (variable-p object)
                       (= (triple-object t) object)))
          t))

  ;; --- SPARQL execution ---

  (defn execute-sparql [self query-string]
    "Parse and execute a SPARQL SELECT ... WHERE query string.
     Returns a list of binding dictionaries."
    (let [parsed (parse-sparql-query query-string)
          select-vars (get parsed "select-vars")
          where-patterns (get parsed "where-patterns")
          results (execute-where-patterns self where-patterns)
          projected (project-results results select-vars)]
      projected)))


;; --- Helper functions ---

(defn variable-p [s]
  "Check if a string is a SPARQL variable (starts with '?')."
  (and (isinstance s str) (> (len s) 0) (= (get s 0) "?")))

(defn triple-to-binding [triple pattern]
  "Build a binding dict mapping variables in `pattern` to values in `triple`."
  (setv binding {})
  (when (variable-p (get pattern 0))
    (setv (get binding (get pattern 0)) (triple-subject triple)))
  (when (variable-p (get pattern 1))
    (setv (get binding (get pattern 1)) (triple-predicate triple)))
  (when (variable-p (get pattern 2))
    (setv (get binding (get pattern 2)) (triple-object triple)))
  binding)

(defn apply-bindings [pattern bindings]
  "Substitute known variable bindings into a pattern."
  (lfor item pattern
        (if (and (variable-p item) (in item bindings))
            (get bindings item)
            item)))

(defn merge-bindings [b1 b2]
  "Merge two binding dicts. b2 values override b1 on conflict."
  (| (dict b1) (dict b2)))


;; --- SPARQL parser ---

(defn parse-sparql-query [query-string]
  "Parse a simple SPARQL query: SELECT vars WHERE { patterns }
   Returns dict with 'select-vars' and 'where-patterns'."
  (setv tokens (lfor tok (.split query-string)
                     :if (not (in tok ["{" "}"]))
                     tok))
  ;; Find SELECT and WHERE positions (case-insensitive)
  (setv lower-tokens (lfor t tokens (.lower t)))
  (setv select-idx (.index lower-tokens "select"))
  (setv where-idx (.index lower-tokens "where"))
  ;; Extract SELECT vars
  (setv select-vars (cut tokens (+ select-idx 1) where-idx))
  ;; Extract WHERE clause tokens
  (setv where-tokens (cut tokens (+ where-idx 1) None))
  ;; Parse WHERE patterns (split on '.')
  (setv where-patterns (parse-where-patterns where-tokens))
  {"select-vars" select-vars "where-patterns" where-patterns})

(defn parse-where-patterns [tokens]
  "Split WHERE clause tokens into patterns, delimited by '.'."
  (setv patterns [])
  (setv current [])
  (for [tok tokens]
    (if (= tok ".")
        (do
          (when current
            (.append patterns (list current))
            (setv current [])))
        (.append current tok)))
  ;; Don't forget the last pattern if it wasn't dot-terminated
  (when current
    (.append patterns (list current)))
  patterns)


;; --- SPARQL execution engine ---

(defn execute-where-patterns [store patterns]
  "Execute WHERE patterns against the store. Returns a list of binding dicts."
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
            ;; For each binding from the first pattern, execute remaining
            ;; patterns with the bound values substituted in
            (do
              (setv results [])
              (for [binding bindings]
                (setv sub-results
                      (execute-where-with-bindings store remaining binding))
                (for [sr sub-results]
                  (.append results (merge-bindings binding sr))))
              results)))))

(defn execute-where-with-bindings [store patterns bindings]
  "Execute WHERE patterns with existing variable bindings substituted."
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
  "Project results to only the selected variables. '*' means all."
  (if (= select-vars ["*"])
      ;; Return all bindings, removing duplicates
      (lfor r results (remove-duplicate-keys r))
      ;; Return only requested variables
      (lfor r results
            (dfor var select-vars var (.get r var None)))))

(defn remove-duplicate-keys [binding]
  "Return a cleaned copy of the binding dict (already unique by dict nature)."
  (dict binding))
