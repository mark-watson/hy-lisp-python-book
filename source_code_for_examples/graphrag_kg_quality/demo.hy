(import graphrag [GraphRAGPipeline])
(import kg [provenance-for-triple transactional-sparql-update])
(import quality [validate-graph make-invalid-graph-sample])
(import evaluate [evaluate-pipeline format-eval-table])

(defn main []
  (print "=== 1. Corpus & Extraction ===")
  (setv pipe (GraphRAGPipeline))
  (print f"Loaded {(len pipe.chunks)} text chunks across 6 documents.")
  (print f"Extracted {(len pipe.batch.entities)} entities and {(len pipe.batch.triples)} raw triples.")
  (setv sample-prov (provenance-for-triple pipe.graph "kgcreator" "usesComponent" "spacy"))
  (print f"Provenance for (kgcreator usesComponent spacy): {sample-prov}")

  (print "\n=== 2. Entity Resolution (Blocking + String Similarity) ===")
  (for [m pipe.resolution.auto-merged]
    (print f"  [auto-merge] {m.alias-id} ({m.alias-label}) -> {m.canonical-id} ({m.canonical-label}) [block={m.block-key}, sim={m.similarity}]"))
  (for [r pipe.resolution.review-queue]
    (print f"  [review-queue] {r.alias-id} ({r.alias-label}) ? {r.canonical-id} ({r.canonical-label}) [block={r.block-key}, sim={r.similarity}]"))

  (print "\n=== 3. RDFS Inference & SHACL Validation ===")
  (print f"RDFS inference derived {(len pipe.inferred-triples)} implicit triples.")
  (print f"Clean graph SHACL conforms: {pipe.validation.conforms} (violations: {pipe.validation.violation-count})")

  (setv bad-graph (make-invalid-graph-sample pipe.graph)
        bad-report (validate-graph bad-graph))
  (print f"Corrupted sample SHACL conforms: {bad-report.conforms} (violations: {bad-report.violation-count})")
  (for [v bad-report.violations]
    (setv fn-node (get v "focus_node")
          v-msg (get v "message"))
    (print f"  - focus={fn-node} | {v-msg}"))

  (print "\n=== 4. SPARQL Update & Snapshot Rollback ===")
  (setv before-count (len pipe.graph)
        #(ok-good msg-good after-good)
        (transactional-sparql-update
          pipe.graph
          "PREFIX ex: <http://example.org/kgrag/>
           INSERT DATA { ex:kgn ex:supportsExportFormat ex:turtle_rdf }"
          :validator (fn [g] (setv vr (validate-graph g)) #(vr.conforms vr.report-text))))
  (print f"Valid SPARQL Update: ok={ok-good}, triples {before-count} -> {after-good}")

  (setv #(ok-bad msg-bad after-bad)
        (transactional-sparql-update
          pipe.graph
          "PREFIX ex: <http://example.org/kgrag/>
           PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
           INSERT DATA { ex:broken_tool rdf:type ex:SoftwareProject }"
          :validator (fn [g] (setv vr (validate-graph g)) #(vr.conforms "SHACL check failed"))))
  (print f"Invalid SPARQL Update rolled back: ok={ok-bad}, triples restored to {after-bad}")

  (print "\n=== 5. Baseline vs GraphRAG Retrieval (Local & Global) ===")
  (setv q "Which database stores embeddings for the RAG system built by Mark L. Watson, and which model generates its answers?"
        ans-base (.answer pipe q :mode "baseline")
        ans-graph (.answer pipe q :mode "graphrag_local")
        ans-global (.answer pipe "Compare the major knowledge graph and RAG architectures in this corpus." :mode "graphrag_global"))
  (print f"Question: {q}")
  (print f"  Baseline chunks: {(lfor c ans-base.context.chunks c.chunk-id)}")
  (print f"  GraphRAG seeds:  {ans-graph.context.seed-entities}")
  (print f"  GraphRAG chunks: {(lfor c ans-graph.context.chunks c.chunk-id)}")
  (print f"  GraphRAG cited triples ({(len ans-graph.cited-triples)}): {(cut ans-graph.cited-triples 0 4)}")
  (print f"  Global search communities: {(len ans-global.context.communities)}")
  (for [comm ans-global.context.communities]
    (print f"    * {comm.summary-text}"))

  (print "\n=== 6. Benchmark Evaluation Table ===")
  (setv eval-report (evaluate-pipeline pipe))
  (print (format-eval-table eval-report)))

(when (= __name__ "__main__")
  (main))
