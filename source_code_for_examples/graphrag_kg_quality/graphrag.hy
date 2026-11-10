(import dataclasses [dataclass])
(import corpus [load-corpus])
(import extract [FakeExtractor])
(import kg [build-kg])
(import quality [validate-graph apply-rdfs-inference])
(import resolve [resolve-entities])
(import retrieve [KeywordRetriever GraphRetriever])

(defclass [(dataclass :frozen True)] AnswerResult []
  "A grounded answer with explicit triple and chunk citations."
  #^ str question
  #^ str mode
  #^ str answer-text
  #^ list cited-triples
  #^ list cited-chunks
  #^ RetrievalContext context)

(defn format-context-block [ctx]
  "Render retrieved triples, chunks, or communities into a prompt-ready block."
  (setv lines [])
  (when ctx.triples
    (.append lines "=== GRAPH TRIPLES ===")
    (for [st ctx.triples]
      (setv c-str (if st.chunk-ids (.join "," st.chunk-ids) "inferred")
            conf-str (format st.confidence ".2f"))
      (.append lines f"- [triple: {st.subject} {st.predicate} {st.object-val}] (source: {c-str}, conf: {conf-str})")))
  (when ctx.chunks
    (.append lines "=== SOURCE CHUNKS ===")
    (for [ch ctx.chunks]
      (.append lines f"- [chunk: {ch.chunk-id}] {ch.text}")))
  (when ctx.communities
    (.append lines "=== COMMUNITY SUMMARIES ===")
    (for [comm ctx.communities]
      (setv cids (.join "," comm.chunk-ids))
      (.append lines f"- {comm.summary-text} (chunks: {cids})")))
  (.join "\n" lines))

(defn synthesize-grounded-answer [question ctx]
  "Synthesize a deterministic answer strictly from facts present in ctx."
  (setv cited-triples []
        cited-chunks []
        statements [])

  (when (= ctx.mode "graphrag_global")
    (for [comm ctx.communities]
      (.append statements f"{comm.title}: {comm.summary-text}")
      (for [cid comm.chunk-ids]
        (when (not (in cid cited-chunks))
          (.append cited-chunks cid))))
    (setv body (if statements (.join " " statements) "No matching communities found."))
    (return #(body cited-triples cited-chunks)))

  ;; Collect evidence from retrieved graph triples first
  (for [st ctx.triples]
    (setv t-id f"{st.subject} {st.predicate} {st.object-val}")
    (.append cited-triples t-id)
    (for [cid st.chunk-ids]
      (when (not (in cid cited-chunks))
        (.append cited-chunks cid)))
    (setv c-tag (if st.chunk-ids f" [chunk: {(get st.chunk-ids 0)}]" ""))
    (.append statements
      f"{st.subject} --{st.predicate}--> {st.object-val} [triple: {t-id}]{c-tag}"))

  ;; Collect evidence from retrieved text chunks
  (for [ch ctx.chunks]
    (when (not (in ch.chunk-id cited-chunks))
      (.append cited-chunks ch.chunk-id))
    (.append statements f"{ch.text} [chunk: {ch.chunk-id}]"))

  (setv answer-text
    (if statements
        (.join " | " statements)
        "Insufficient context retrieved to answer the question."))
  #(answer-text cited-triples cited-chunks))

(defclass GraphRAGPipeline []
  "End-to-end pipeline: ingest -> extract -> resolve -> RDFS infer -> SHACL validate -> retrieve."
  (defn __init__ [self [chunks None] [extractor None]]
    (setv self.chunks (if (is chunks None) (load-corpus) chunks)
          self.extractor (if (is extractor None) (FakeExtractor) extractor)
          self.batch (.extract-corpus self.extractor self.chunks)
          self.graph (build-kg self.batch :include-schema True)
          self.resolution (resolve-entities self.graph self.batch.entities)
          self.inferred-triples (apply-rdfs-inference self.graph)
          self.validation (validate-graph self.graph)
          self.keyword-retriever (KeywordRetriever self.chunks)
          self.graph-retriever (GraphRetriever self.graph self.chunks)))

  (defn answer [self question [mode "graphrag_local"] [token-budget 180]]
    (setv ctx
      (cond
        (= mode "baseline")
        (.retrieve self.keyword-retriever question :top-k 2 :token-budget 95)
        (= mode "graphrag_global")
        (.global-search self.graph-retriever question :top-communities 3 :token-budget token-budget)
        True
        (.local-search self.graph-retriever question :max-hops 2 :top-k-chunks 4 :token-budget token-budget)))
    (setv #(text cited-triples cited-chunks) (synthesize-grounded-answer question ctx))
    (AnswerResult :question question
                  :mode ctx.mode
                  :answer-text text
                  :cited-triples cited-triples
                  :cited-chunks cited-chunks
                  :context ctx)))
