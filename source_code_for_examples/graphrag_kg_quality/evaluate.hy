(import dataclasses [dataclass])

(defclass [(dataclass :frozen True)] EvalCase []
  "A benchmark question with gold provenance chunks and required answer facts."
  #^ str case-id
  #^ str question
  #^ list gold-chunks
  #^ list expected-facts)

(defclass [(dataclass :frozen True)] CaseMetrics []
  "Evaluation scores for a single question and retrieval mode."
  #^ str case-id
  #^ str mode
  #^ float retrieval-recall
  #^ float citation-accuracy
  #^ float groundedness)

(setv BENCHMARK_CASES
  [(EvalCase :case-id "Q1"
             :question "Which database stores embeddings for the RAG system built by Mark L. Watson, and which model generates its answers?"
             :gold-chunks ["doc1#chunk0" "doc5#chunk0" "doc5#chunk1"]
             :expected-facts ["zvec_rag" "zvec_db" "qwen3_1_7b"])
   (EvalCase :case-id "Q2"
             :question "What NLP library and vocabulary standard does KG-Creator use to build RDF?"
             :gold-chunks ["doc1#chunk1" "doc3#chunk0" "doc3#chunk1"]
             :expected-facts ["spacy" "schema_org" "dbpedia"])
   (EvalCase :case-id "Q3"
             :question "When NSK symbolic unification fails, what fallback mechanism and model does it call?"
             :gold-chunks ["doc2#chunk0" "doc2#chunk1"]
             :expected-facts ["unification" "ollama_fallback" "qwen3_5_4b"])
   (EvalCase :case-id "Q4"
             :question "Which SPARQL endpoint does KGN query, and which datastore component does it build on?"
             :gold-chunks ["doc4#chunk0" "doc4#chunk1"]
             :expected-facts ["dbpedia" "rdf_datastore" "mark_watson"])
   (EvalCase :case-id "Q5"
             :question "How does kg-rag validate RDF constraints and record triple provenance?"
             :gold-chunks ["doc6#chunk0" "doc6#chunk1"]
             :expected-facts ["shacl" "pyshacl" "prov_o"])
   (EvalCase :case-id "Q6"
             :question "Which AI software projects were created by Mark Watson?"
             :gold-chunks ["doc1#chunk0" "doc2#chunk0" "doc3#chunk0" "doc4#chunk0" "doc6#chunk0"]
             :expected-facts ["zvec_rag" "nsk" "kgcreator" "kgn" "kg_rag"])])

(defn score-answer [eval-case ans]
  "Compute retrieval recall, citation accuracy, and groundedness for an AnswerResult."
  (setv ctx ans.context
        retrieved-chunk-ids (set (lfor ch ctx.chunks ch.chunk-id)))
  (for [st ctx.triples]
    (for [cid st.chunk-ids]
      (.add retrieved-chunk-ids cid)))

  ;; 1. Retrieval recall against gold chunks
  (setv gold (set eval-case.gold-chunks)
        recall (if gold
                   (/ (len (& gold retrieved-chunk-ids)) (float (len gold)))
                   1.0))

  ;; 2. Citation accuracy: every cited triple/chunk must belong to the retrieved context
  (setv valid-triples (set (lfor st ctx.triples f"{st.subject} {st.predicate} {st.object-val}"))
        total-cites (+ (len ans.cited-triples) (len ans.cited-chunks))
        valid-cites 0)
  (for [ct ans.cited-triples]
    (when (in ct valid-triples)
      (setv valid-cites (+ valid-cites 1))))
  (for [cc ans.cited-chunks]
    (when (in cc retrieved-chunk-ids)
      (setv valid-cites (+ valid-cites 1))))
  (setv cite-acc (if (> total-cites 0)
                     (/ valid-cites (float total-cites))
                     0.0))

  ;; 3. Groundedness: fraction of expected facts present in the context-backed answer
  (setv low-ans (.lower ans.answer-text)
        norm-ans (.replace (.replace low-ans ":" "_") "." "_")
        hits 0)
  (for [fact eval-case.expected-facts]
    (setv f-low (.lower fact))
    (when (or (in f-low low-ans) (in f-low norm-ans))
      (setv hits (+ hits 1))))
  (setv grounded (if eval-case.expected-facts
                     (/ hits (float (len eval-case.expected-facts)))
                     1.0))

  (CaseMetrics :case-id eval-case.case-id
               :mode ans.mode
               :retrieval-recall (round recall 3)
               :citation-accuracy (round cite-acc 3)
               :groundedness (round grounded 3)))

(defn evaluate-pipeline [pipeline [cases None]]
  "Evaluate both baseline keyword retrieval and GraphRAG local retrieval across cases."
  (setv suite (if (is cases None) BENCHMARK_CASES cases)
        baseline-rows []
        graphrag-rows [])
  (for [c suite]
    (.append baseline-rows (score-answer c (.answer pipeline c.question :mode "baseline")))
    (.append graphrag-rows (score-answer c (.answer pipeline c.question :mode "graphrag_local"))))

  (defn avg [rows attr]
    (round (/ (sum (gfor r rows (getattr r attr))) (float (len rows))) 3))

  {"cases" suite
   "baseline" baseline-rows
   "graphrag" graphrag-rows
   "summary"
   {"baseline_recall" (avg baseline-rows "retrieval_recall")
    "graphrag_recall" (avg graphrag-rows "retrieval_recall")
    "baseline_citation_acc" (avg baseline-rows "citation_accuracy")
    "graphrag_citation_acc" (avg graphrag-rows "citation_accuracy")
    "baseline_groundedness" (avg baseline-rows "groundedness")
    "graphrag_groundedness" (avg graphrag-rows "groundedness")}})

(defn fmt-row [cid mode rec cit grd]
  (setv c-pad (.ljust cid 4)
        m-pad (.ljust mode 14)
        r-str (.rjust (format rec ".2f") 6)
        c-str (.rjust (format cit ".2f") 7)
        g-str (.rjust (format grd ".2f") 8))
  f"{c-pad} | {m-pad} | {r-str} | {c-str} | {g-str}")

(defn format-eval-table [report]
  "Format per-question and aggregate metrics into a readable text table."
  (setv lines
    ["Case | Mode           | Recall | CiteAcc | Grounded"
     "-----+----------------+--------+---------+---------"])
  (for [#(b g) (zip (get report "baseline") (get report "graphrag"))]
    (.append lines (fmt-row b.case-id "Baseline" b.retrieval-recall b.citation-accuracy b.groundedness))
    (.append lines (fmt-row g.case-id "GraphRAG" g.retrieval-recall g.citation-accuracy g.groundedness)))
  (setv s (get report "summary"))
  (.append lines "-----+----------------+--------+---------+---------")
  (.append lines (fmt-row "AVG" "Baseline"
                          (get s "baseline_recall")
                          (get s "baseline_citation_acc")
                          (get s "baseline_groundedness")))
  (.append lines (fmt-row "AVG" "GraphRAG"
                          (get s "graphrag_recall")
                          (get s "graphrag_citation_acc")
                          (get s "graphrag_groundedness")))
  (.join "\n" lines))
