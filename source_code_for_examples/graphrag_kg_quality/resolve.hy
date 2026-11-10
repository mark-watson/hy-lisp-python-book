(import dataclasses [dataclass])
(import difflib [SequenceMatcher])
(import re)
(import rdflib [OWL RDF RDFS])
(import kg [EX])

(defclass [(dataclass :frozen True)] ResolutionCandidate []
  "A pair of entities evaluated during entity resolution."
  #^ str canonical-id
  #^ str alias-id
  #^ str canonical-label
  #^ str alias-label
  #^ str block-key
  #^ float similarity
  #^ str action)

(defclass [(dataclass :frozen True)] ResolutionReport []
  "Summary of auto-merged owl:sameAs pairs and human review queue items."
  #^ list auto-merged
  #^ list review-queue
  #^ dict canonical-map)

(setv SYSTEM_TYPES #{"SoftwareProject" "NeuralSymbolicSystem"
                     "KnowledgeGraphSystem" "VectorRAGSystem"
                     "GraphRAGSystem" "RetrievalSystem" "AISoftware"})

(defn coarse-type [entity-type]
  (if (in entity-type SYSTEM_TYPES)
      "System"
      entity-type))

(defn normalize-label [label]
  "Lowercase label, strip periods, and collapse whitespace."
  (setv s (.replace (.lower label) "." "")
        s (re.sub r"\s+" " " (.strip s)))
  s)

(defn blocking-key [entity]
  "Group entities by coarse ontology class and first character of normalized label."
  (setv norm (normalize-label entity.label)
        first-ch (if (> (len norm) 0) (get norm 0) "_"))
  f"{(coarse-type entity.entity-type)}:{first-ch}")

(defn label-similarity [label-a label-b]
  "Compute string similarity in [0.0, 1.0] using difflib.SequenceMatcher."
  (setv na (normalize-label label-a)
        nb (normalize-label label-b))
  (.ratio (SequenceMatcher None na nb)))

(defn choose-canonical [ent-a ent-b]
  "Prefer the entity with a shorter, punctuation-free local ID as canonical."
  (setv score-a #((in "_" (.replace ent-a.local-id "mark_watson" "markwatson"))
                  (len ent-a.label)
                  ent-a.local-id)
        score-b #((in "_" (.replace ent-b.local-id "mark_watson" "markwatson"))
                  (len ent-b.label)
                  ent-b.local-id))
  (if (<= score-a score-b)
      #(ent-a ent-b)
      #(ent-b ent-a)))

(defn canonicalize-uri-in-graph [g alias-id canonical-id]
  "Add owl:sameAs and rewrite subject/object references from alias-id to canonical-id."
  (setv alias-uri (get EX alias-id)
        canon-uri (get EX canonical-id)
        to-remove []
        to-add [#(alias-uri OWL.sameAs canon-uri)])
  (for [#(s p o) g]
    (when (and (!= p OWL.sameAs)
               (or (= s alias-uri) (= o alias-uri)))
      (.append to-remove #(s p o))
      (setv new-s (if (= s alias-uri) canon-uri s)
            new-o (if (= o alias-uri) canon-uri o))
      (when (!= new-s new-o)
        (.append to-add #(new-s p new-o)))))
  (for [tr to-remove]
    (.remove g tr))
  (for [tr to-add]
    (.add g tr)))

(defn resolve-entities [g entities [auto-threshold 0.88] [review-threshold 0.72]]
  "Block entities, score candidate pairs, canonicalize high-confidence merges, and queue ambiguous pairs."
  (setv blocks {})
  (for [ent entities]
    (setv bkey (blocking-key ent))
    (.setdefault blocks bkey [])
    (.append (get blocks bkey) ent))

  (setv auto-merged []
        review-queue []
        canonical-map {})

  (for [#(bkey group) (sorted (.items blocks))]
    (setv sorted-group (sorted group :key (fn [e] e.local-id))
          n (len sorted-group))
    (for [i (range n)]
      (for [j (range (+ i 1) n)]
        (setv #(canon alias) (choose-canonical (get sorted-group i)
                                               (get sorted-group j))
              sim (round (label-similarity canon.label alias.label) 4))
        (cond
          (>= sim auto-threshold)
          (do
            (setv cand (ResolutionCandidate :canonical-id canon.local-id
                                            :alias-id alias.local-id
                                            :canonical-label canon.label
                                            :alias-label alias.label
                                            :block-key bkey
                                            :similarity sim
                                            :action "auto_merge"))
            (.append auto-merged cand)
            (setv (get canonical-map alias.local-id) canon.local-id)
            (canonicalize-uri-in-graph g alias.local-id canon.local-id))
          (>= sim review-threshold)
          (.append review-queue
            (ResolutionCandidate :canonical-id canon.local-id
                                 :alias-id alias.local-id
                                 :canonical-label canon.label
                                 :alias-label alias.label
                                 :block-key bkey
                                 :similarity sim
                                 :action "human_review"))))))

  (ResolutionReport :auto-merged auto-merged
                    :review-queue review-queue
                    :canonical-map canonical-map))
