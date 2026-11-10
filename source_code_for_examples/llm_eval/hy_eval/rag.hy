;; hy_eval/rag.hy -- Offline RAG retrievers (keyword vs graph-enhanced) and RAG metrics.

(import collections [Counter])
(import re)
(import hy_eval.metrics [tokenize stem-token])


(setv _STOPWORDS
  #{"a" "an" "and" "are" "as" "at" "be" "by" "does" "for" "from" "has" "he"
    "how" "in" "is" "it" "its" "of" "on" "or" "says" "stated" "studies"
    "that" "the" "their" "this" "to" "was" "what" "when" "where" "which"
    "who" "with"})


;; Tiny knowledge graph linking entities across chunks in data/corpus.jsonl.
(setv DEFAULT_GRAPH_EDGES
  [{"source" "Pauli Blendergast"
    "relation" "affiliated_with"
    "target" "University of Krampton Ohio"
    "doc_id" "econ-2"}
   {"source" "University of Krampton Ohio"
    "relation" "publishes"
    "target" "Journal of Skeptical Economics"
    "doc_id" "econ-3"}
   {"source" "Microeconomics"
    "relation" "contrasts_with"
    "target" "Macroeconomics"
    "doc_id" "econ-1"}
   {"source" "Hy"
    "relation" "powers_engine"
    "target" "NSK"
    "doc_id" "hy-2"}])


(defn content-tokens [#^ str text]
  "Return stemmed non-stopword tokens from `text`."
  (lfor t (tokenize text)
        :if (and (> (len t) 2) (not (in t _STOPWORDS)))
        (stem-token t)))


(defn keyword-retrieve [corpus #^ str query [top-k 2] [min-score 0.25]]
  "Rank corpus chunks by stemmed content-word overlap with the query."
  (setv q-tokens (set (content-tokens query)))
  (when (not q-tokens)
    (return []))
  (setv scored [])
  (for [doc corpus]
    (setv d-tokens (set (content-tokens (+ (.get doc "title" "") " " (get doc "text"))))
          overlap (len (& q-tokens d-tokens))
          score (/ overlap (max 1 (len q-tokens))))
    (when (>= score min-score)
      (.append scored #(score (get doc "id") doc))))
  (.sort scored :key (fn [item] #((- (get item 0)) (get item 1))))
  (lfor [_ _ doc] (cut scored 0 top-k) doc))


(defn graph-retrieve [corpus #^ str query [graph-edges None] [top-k 2]]
  "Retrieve initial chunks by keyword overlap, then expand 1 hop over entity edges."
  (setv edges (if (is graph-edges None) DEFAULT_GRAPH_EDGES graph-edges)
        initial (keyword-retrieve corpus query :top-k top-k)
        by-id (dfor doc corpus (get doc "id") doc)
        seen-ids (set (gfor d initial (get d "id")))
        results (list initial)
        seed-entities (set))

  (for [doc initial]
    (for [ent (.get doc "entities" [])]
      (.add seed-entities (.lower ent))))
  (setv q-lower (.lower query))
  (for [edge edges]
    (when (in (.lower (get edge "source")) q-lower)
      (.add seed-entities (.lower (get edge "source"))))
    (when (in (.lower (get edge "target")) q-lower)
      (.add seed-entities (.lower (get edge "target")))))

  ;; Expand one hop along matching graph edges
  (for [edge edges]
    (setv src (.lower (get edge "source"))
          tgt (.lower (get edge "target"))
          target-doc-id (get edge "doc_id"))
    (when (and (or (in src seed-entities) (in tgt seed-entities))
               (in target-doc-id by-id)
               (not (in target-doc-id seen-ids))
               (< (len results) top-k))
      (.add seen-ids target-doc-id)
      (.append results (get by-id target-doc-id))))

  (cut results 0 top-k))


(defn retrieval-recall-at-k [retrieved-ids relevant-ids [k None]]
  "Fraction of gold `relevant-ids` found within top-k `retrieved-ids`."
  (setv rel-set (set relevant-ids))
  (when (not rel-set)
    ;; For unanswerable / refusal questions with no relevant docs, recall is 1.0.
    (return 1.0))
  (setv top-ret (if (is k None) (list retrieved-ids) (cut (list retrieved-ids) 0 k))
        hits (len (& (set top-ret) rel-set)))
  (round (/ hits (len rel-set)) 4))


(defn context-precision-at-k [retrieved-ids relevant-ids [k None]]
  "Rank-aware Average Precision@k of retrieved context chunks."
  (setv rel-set (set relevant-ids)
        top-ret (if (is k None) (list retrieved-ids) (cut (list retrieved-ids) 0 k)))
  (when (not rel-set)
    (return (if (not top-ret) 1.0 0.0)))
  (when (not top-ret)
    (return 0.0))
  (setv hits 0
        precision-sum 0.0)
  (for [[idx doc-id] (enumerate top-ret :start 1)]
    (when (in doc-id rel-set)
      (+= hits 1)
      (+= precision-sum (/ hits idx))))
  (if (= hits 0)
    0.0
    (round (/ precision-sum hits) 4)))


(defn groundedness-score [#^ str answer context-chunks]
  "Fraction of content tokens in `answer` supported by `context-chunks` (or 1.0 on refusal)."
  (setv lower-ans (.lower (or answer "")))
  (when (or (in "does not contain" lower-ans)
            (in "not enough information" lower-ans))
    (return 1.0))
  (setv ans-tokens (content-tokens (re.sub r"\[[a-zA-Z0-9_-]+\]" "" answer)))
  (when (not ans-tokens)
    (return 0.0))
  (setv ctx-text (.join " " (gfor c context-chunks
                                  (if (isinstance c dict) (get c "text") (str c))))
        ctx-tokens (set (content-tokens ctx-text))
        supported (sum (gfor t ans-tokens (if (in t ctx-tokens) 1 0))))
  (round (/ supported (len ans-tokens)) 4))


(defn citation-accuracy [#^ str answer retrieved-chunks [expect-refusal False]]
  "Check bracketed citations like [econ-2] against the IDs of `retrieved-chunks`."
  (setv cited (re.findall r"\[([a-zA-Z0-9_-]+)\]" (or answer ""))
        valid-ids (set (gfor c retrieved-chunks
                             (if (isinstance c dict) (get c "id") (str c)))))
  (when expect-refusal
    (setv no-bogus (= (len cited) 0))
    (return {"score" (if no-bogus 1.0 0.0)
             "cited_ids" cited
             "valid_citations" []
             "hallucinated_citations" cited}))
  (when (not cited)
    (return {"score" 0.0
             "cited_ids" []
             "valid_citations" []
             "hallucinated_citations" []}))
  (setv valid (lfor cid cited :if (in cid valid-ids) cid)
        hallucinated (lfor cid cited :if (not (in cid valid-ids)) cid)
        precision (/ (len valid) (len cited)))
  {"score" (round precision 4)
   "cited_ids" cited
   "valid_citations" valid
   "hallucinated_citations" hallucinated})
