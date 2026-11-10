(import rdflib [OWL RDF RDFS])
(import corpus [load-corpus])
(import extract [FakeExtractor OllamaExtractor])
(import kg [EX PROV build-kg provenance-for-triple transactional-sparql-update])
(import quality [validate-graph make-invalid-graph-sample apply-rdfs-inference])
(import resolve [resolve-entities blocking-key label-similarity])
(import retrieve [KeywordRetriever GraphRetriever])
(import graphrag [GraphRAGPipeline])
(import evaluate [evaluate-pipeline format-eval-table])

(defn test-corpus-loading []
  (setv chunks (load-corpus))
  (assert (= (len chunks) 12))
  (assert (= (. (get chunks 0) chunk-id) "doc1#chunk0"))
  (assert (.startswith (. (get chunks 0) source-uri) "https://example.org/docs/")))

(defn test-extraction-and-provenance []
  (setv chunks (load-corpus)
        batch (.extract-corpus (FakeExtractor) chunks)
        g (build-kg batch))
  (assert (>= (len batch.entities) 20))
  (assert (>= (len batch.triples) 22))
  (setv prov (provenance-for-triple g "kgcreator" "usesComponent" "spacy"))
  (assert (= (len prov) 1))
  (assert (= (get (get prov 0) "chunk_id") "doc3#chunk0"))
  (assert (= (get (get prov 0) "confidence") 0.95)))

(defn test-ollama-extractor-graceful-fallback []
  (setv chunks (cut (load-corpus) 0 2)
        ext (OllamaExtractor :url "http://127.0.0.1:9/api/generate")
        batch (.extract-corpus ext chunks))
  (assert (>= (len batch.triples) 3)))

(defn test-entity-resolution-blocking-and-canonicalization []
  (setv chunks (load-corpus)
        batch (.extract-corpus (FakeExtractor) chunks)
        g (build-kg batch)
        report (resolve-entities g batch.entities))
  ;; mark_l_watson -> mark_watson and kg_creator -> kgcreator auto-merge
  (setv merged-aliases (set (lfor m report.auto-merged m.alias-id)))
  (assert (in "mark_l_watson" merged-aliases))
  (assert (in "kg_creator" merged-aliases))
  (assert (in #(EX.mark_l_watson OWL.sameAs EX.mark_watson) g))
  (assert (in #(EX.kg_creator OWL.sameAs EX.kgcreator) g))
  ;; Triples originally pointing to mark_l_watson are rewritten to mark_watson
  (assert (in #(EX.zvec_rag EX.createdBy EX.mark_watson) g))
  ;; Ambiguous pairs like m_watson and nsk_engine go to human review queue
  (setv review-aliases (set (lfor r report.review-queue r.alias-id)))
  (assert (in "m_watson" review-aliases)))

(defn test-rdfs-inference-and-shacl-validation []
  (setv chunks (load-corpus)
        batch (.extract-corpus (FakeExtractor) chunks)
        g (build-kg batch))
  (resolve-entities g batch.entities)
  (setv added (apply-rdfs-inference g))
  (assert (> (len added) 10))
  ;; nsk had ex:authoredBy; RDFS subPropertyOf infers ex:createdBy
  (assert (in #(EX.nsk EX.createdBy EX.mark_watson) g))
  ;; nsk had ex:NeuralSymbolicSystem; RDFS subClassOf infers ex:SoftwareProject and ex:AISoftware
  (assert (in #(EX.nsk RDF.type EX.SoftwareProject) g))
  (assert (in #(EX.nsk RDF.type EX.AISoftware) g))

  (setv clean-res (validate-graph g))
  (assert clean-res.conforms)
  (assert (= clean-res.violation-count 0))

  (setv bad-g (make-invalid-graph-sample g)
        bad-res (validate-graph bad-g))
  (assert (not bad-res.conforms))
  (assert (>= bad-res.violation-count 4)))

(defn test-sparql-update-and-rollback []
  (setv pipe (GraphRAGPipeline)
        g pipe.graph
        initial-len (len g))
  ;; Valid update commits
  (setv #(ok1 _ len1)
        (transactional-sparql-update
          g
          "PREFIX ex: <http://example.org/kgrag/>
           DELETE { ex:kgn ex:sharesPatternWith ex:nsk_engine }
           INSERT { ex:kgn ex:relatedProject ex:nsk }
           WHERE  { OPTIONAL { ex:kgn ex:sharesPatternWith ex:nsk_engine } }"))
  (assert ok1)
  (assert (in #(EX.kgn EX.relatedProject EX.nsk) g))

  ;; Update that fails post-update SHACL validator rolls back cleanly
  (setv #(ok2 reason len2)
        (transactional-sparql-update
          g
          "PREFIX ex: <http://example.org/kgrag/>
           PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
           INSERT DATA { ex:unlabeled_app rdf:type ex:SoftwareProject }"
          :validator (fn [graph]
                       (setv vr (validate-graph graph))
                       #(vr.conforms "SHACL violation"))))
  (assert (not ok2))
  (assert (not (in #(EX.unlabeled_app RDF.type EX.SoftwareProject) g)))
  (assert (= len2 len1)))

(defn test-retrieval-token-budget-and-modes []
  (setv pipe (GraphRAGPipeline)
        q "Which database stores embeddings for the RAG system built by Mark L. Watson, and which model generates its answers?"
        base-ans (.answer pipe q :mode "baseline")
        graph-ans (.answer pipe q :mode "graphrag_local" :token-budget 170)
        global-ans (.answer pipe "Summarize the knowledge graph and vector RAG communities" :mode "graphrag_global"))
  (assert (<= graph-ans.context.tokens-used graph-ans.context.token-budget))
  ;; GraphRAG traverses from mark_watson -> zvec_rag -> zvec_db and qwen3_1_7b
  (assert (in "zvec_db" graph-ans.answer-text))
  (assert (in "qwen3_1_7b" graph-ans.answer-text))
  (assert (> (len graph-ans.cited-triples) 0))
  (assert (= (len global-ans.context.communities) 3)))

(defn test-blocking-and-similarity-primitives []
  (setv chunks (load-corpus)
        batch (.extract-corpus (FakeExtractor) chunks)
        by-id (dfor e batch.entities e.local-id e))
  (assert (= (blocking-key (get by-id "mark_watson")) "Person:m"))
  (assert (= (blocking-key (get by-id "kgcreator")) "System:k"))
  (assert (> (label-similarity "Mark Watson" "Mark L. Watson") 0.88))
  (assert (< (label-similarity "Mark Watson" "M. Watson") 0.88))
  (assert (> (label-similarity "Mark Watson" "M. Watson") 0.72)))

(defn test-sparql-syntax-error-rollback []
  (setv pipe (GraphRAGPipeline)
        g pipe.graph
        before (len g)
        #(ok msg after) (transactional-sparql-update g "INVALID SPARQL SYNTAX {{{"))
  (assert (not ok))
  (assert (= after before)))

(defn test-evaluation-metrics-graphrag-outperforms-baseline []
  (setv pipe (GraphRAGPipeline)
        report (evaluate-pipeline pipe)
        summary (get report "summary")
        table (format-eval-table report))
  (assert (> (get summary "graphrag_recall") (get summary "baseline_recall")))
  (assert (> (get summary "graphrag_groundedness") (get summary "baseline_groundedness")))
  (assert (= (get summary "graphrag_citation_acc") 1.0))
  (assert (in "GraphRAG" table)))
