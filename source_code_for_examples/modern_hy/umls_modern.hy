;; Modernized UMLS triple processor (compare with plots_with_graphviz/UMLS_graph.hy).
;; Uses PEP 695 deftype, #^ type annotations, chained setv, setx, match, and #* unpacking.

(import dataclasses [dataclass])

(deftype NodeId str)
(deftype Predicate str)
(deftype Triple (get tuple #(NodeId NodeId Predicate)))

(setv PREDICATE-COLORS
  {"isa" "#FF6B6B"
   "interacts_with" "#4ECDC4"
   "affects" "#45B7D1"
   "causes" "#96CEB4"
   "part_of" "#FFEAA7"
   "location_of" "#DDA0DD"
   "treats" "#98D8C8"})

(defclass [dataclass] GraphSummary []
  #^ int triple-count
  #^ int node-count
  #^ (get dict #(Predicate int)) predicate-counts)

(defn #^ str predicate-color [#^ Predicate pred]
  "Return the color hex string for a predicate using structural match."
  (match pred
    (| "isa" "part_of") (.get PREDICATE-COLORS pred "#CCCCCC")
    (str p) :if (in p PREDICATE-COLORS) (get PREDICATE-COLORS p)
    _ "#CCCCCC"))

(defn #^ (get list Triple) parse-triple-lines [
    #^ (get list str) lines
    #^ (| int None) [limit None]
    #^ (| Predicate None) [filter-pred None]]
  "Parse whitespace-separated (subject object predicate) lines."
  (setv triples
    (lfor line lines
          :if (setx stripped (.strip line))
          :if (not (.startswith stripped "#"))
          :setv tokens (.split stripped)
          :if (= (len tokens) 3)
          :setv [subj obj pred] tokens
          :if (or (is filter-pred None) (= pred filter-pred))
          #(subj obj pred)))
  (if (is limit None)
    triples
    (cut triples 0 limit)))

(defn #^ GraphSummary summarize-triples [#^ (get list Triple) triples]
  "Compute node and predicate counts for a list of triples."
  (setv :chain [triple-count node-count] 0)
  (setv endpoints (lfor [s o _] triples #* [s o]))
  (setv unique-nodes (set endpoints))
  (setv #^ (get dict #(Predicate int)) counts {})
  (for [[_ _ pred] triples]
    (setv (get counts pred) (+ (.get counts pred 0) 1)))
  (setv triple-count (len triples)
        node-count (len unique-nodes))
  (GraphSummary
    :triple-count triple-count
    :node-count node-count
    :predicate-counts counts))
