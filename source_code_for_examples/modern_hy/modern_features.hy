;; Modern Hy 1.3 and Python 3.12-3.15 language features tour.

(import sys)
(import dataclasses [dataclass])

;; 1. Chained assignment (Hy 1.2+) and assignment expressions
(defn reset-counters []
  "Return a dictionary of zeroed counters using (setv :chain ...)."
  (setv :chain [hits misses errors] 0)
  {"hits" hits "misses" misses "errors" errors})

(defn first-non-empty [#^ (get list str) lines]
  "Demonstrate (setx ...) inside a condition and a comprehension."
  (setv cleaned
    (lfor raw lines
          :if (setx stripped (.strip raw))
          stripped))
  (if cleaned (get cleaned 0) ""))

;; 2. Lexical scoping with let and closure mutation with nonlocal
(defn make-accumulator [#^ int start]
  "Return a closure that increments an internal total using nonlocal."
  (let [initial (max 0 start)]
    (setv total initial)
    (defn step [#^ int delta]
      (nonlocal total)
      (+= total delta)
      total)
    step))

;; 3. Type aliases (PEP 695 deftype) and #^ annotations
(deftype NodeId str)
(deftype Triple (get tuple #(NodeId str NodeId)))
(deftype :tp [T] Pair (get tuple #(T T)))

(defn #^ (get Pair NodeId) endpoints [#^ Triple triple]
  "Return the (subject, object) pair of a (subject, object, predicate) triple."
  (setv [subj obj _] triple)
  #(subj obj))

;; 4. Structural pattern matching (match) with dataclasses and Hy models
(defclass [dataclass] QueryEvent []
  #^ str kind
  #^ object payload)

(defn #^ str describe-event [#^ object event]
  "Describe a domain event or a raw Hy model using structural pattern matching."
  (match event
    (QueryEvent :kind "lookup" :payload (| "isa" "part_of") :as pred)
      f"hierarchy lookup on {pred}"
    (QueryEvent :kind "lookup" :payload pred)
      f"lookup on {pred}"
    (QueryEvent :kind "limit" :payload (int n)) :if (> n 0)
      f"limit to {n} triples"
    (hy.models.Expression [(hy.models.Symbol "edge") subj obj pred])
      f"model edge: {(str subj)} -{(str pred)}-> {(str obj)}"
    [subj obj pred]
      f"tuple edge: {subj} -{pred}-> {obj}"
    _
      "unknown event"))

;; 5. Bracket strings and PEP 750 template strings (Python 3.14+)
(setv CYPHER-SAMPLE #[cypher[
MATCH (s:Concept)-[r]->(o:Concept)
WHERE r.predicate = "isa"
RETURN s.id, o.id
]cypher])

(defn render-safe-query [#^ str predicate #^ int limit]
  "On Python 3.14+, build a PEP 750 Template and quote interpolations safely.
   On Python 3.12-3.13, fall back to a formatted pair of (query, params)."
  (setv code "(setv tmpl t\"SELECT subj, obj FROM triples WHERE pred = {predicate} LIMIT {limit}\")")
  (if (>= sys.version-info #(3 14))
    (do
      (setv ns {"predicate" predicate "limit" limit})
      (hy.eval (hy.read-many code) :locals ns)
      (setv tmpl (get ns "tmpl"))
      (setv parts [])
      (setv params [])
      (for [[i Static] (enumerate tmpl.strings)]
        (.append parts Static)
        (when (< i (len tmpl.interpolations))
          (setv interp (get tmpl.interpolations i))
          (.append parts "?")
          (.append params interp.value)))
      #((.join "" parts) (tuple params)))
    #("SELECT subj, obj FROM triples WHERE pred = ? LIMIT ?" #(predicate limit))))

;; 6. PEP 798 unpacking in comprehensions (Hy 1.3+)
(defn #^ (get list str) flatten-batches [#^ (get list (get list str)) batches]
  "Flatten a list of batches with #* inside lfor (PEP 798 in Hy 1.3)."
  (lfor batch batches #* batch))
