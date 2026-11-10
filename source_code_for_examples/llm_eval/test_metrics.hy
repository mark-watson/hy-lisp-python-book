;; test_metrics.hy -- Offline unit tests for deterministic metrics, RAG metrics, and LLMJudge.

(import hy_eval [FakeModel exact-match token-f1 token-f1-score
                 keyword-check regex-check bow-cosine-similarity
                 LLMJudge pairwise-judge
                 retrieval-recall-at-k context-precision-at-k
                 groundedness-score citation-accuracy
                 keyword-retrieve graph-retrieve load-jsonl])
(import pathlib [Path])


(setv DATA_DIR (/ (. (Path __file__) parent) "data"))


(defn test-exact-match-normalization []
  (assert (= (exact-match "Pauli Blendergast!" "  pauli blendergast ") 1.0))
  (assert (= (exact-match "Pauli Blendergast!" "pauli blendergast" :normalize False) 0.0)))


(defn test-token-f1-overlap []
  (setv scores (token-f1 "microeconomics studies households and firms"
                         "microeconomics studies individual households"))
  (assert (> (get scores "precision") 0.5))
  (assert (> (get scores "recall") 0.5))
  (assert (= (token-f1-score "identical text" "identical text") 1.0))
  (assert (= (token-f1-score "alpha beta" "gamma delta") 0.0)))


(defn test-keyword-and-regex-checks []
  (setv res (keyword-check
              "Pauli Blendergast teaches at the University of Krampton Ohio."
              :required ["Blendergast" "Krampton"]
              :forbidden ["titration" "alchemy"]))
  (assert (get res "passed"))
  (assert (= (get res "score") 1.0))

  (setv bad (keyword-check
              "Titration uses a burette."
              :required ["Krampton"]
              :forbidden ["burette"]))
  (assert (not (get bad "passed")))
  (assert (= (get bad "missing") ["Krampton"]))
  (assert (= (get bad "forbidden_found") ["burette"]))
  (assert (regex-check "Citation: [econ-2]" r"\[econ-\d+\]")))


(defn test-bow-cosine-similarity []
  (setv high (bow-cosine-similarity
               "economists studying market failures"
               "economist study market failure")
        low (bow-cosine-similarity
              "economists studying market failures"
              "organic chemistry laboratory titration"))
  (assert (> high 0.7))
  (assert (= low 0.0)))


(defn test-llm-judge-and-pairwise-debiased []
  (setv fake (FakeModel
               :responses
               {"Candidate Answer: Accurate answer"
                "{\"score\": 0.92, \"passed\": true, \"reason\": \"Grounded in context.\"}"
                "[PAIRWISE_ORDER:AB]"
                "{\"winner\": \"B\", \"reason\": \"B has citations.\"}"
                "[PAIRWISE_ORDER:BA]"
                "{\"winner\": \"A\", \"reason\": \"First candidate (B) has citations.\"}"})
        judge (LLMJudge :model fake)
        scored (.score judge "Who?" "Accurate answer" :reference "Ref"))
  (assert (get scored "passed"))
  (assert (= (get scored "score") 0.92))

  (setv pw (pairwise-judge fake "Question?" "Weak A" "Cited B [econ-2]"))
  (assert (= (get pw "winner") "B"))
  (assert (get pw "consistent")))


(defn test-rag-retrieval-and-citation-metrics []
  (setv corpus (load-jsonl (/ DATA_DIR "corpus.jsonl"))
        q "Which journal is published by the university where Pauli Blendergast teaches?"
        kw-docs (keyword-retrieve corpus q :top-k 2)
        gr-docs (graph-retrieve corpus q :top-k 2)
        kw-ids (lfor d kw-docs (get d "id"))
        gr-ids (lfor d gr-docs (get d "id")))

  ;; Keyword-only retrieval finds econ-2 (Blendergast) but misses econ-3 (Krampton Journal)
  (assert (= (retrieval-recall-at-k kw-ids ["econ-2" "econ-3"] :k 2) 0.5))
  ;; Graph-enhanced retrieval expands 1 hop via University of Krampton Ohio to find econ-3
  (assert (= (retrieval-recall-at-k gr-ids ["econ-2" "econ-3"] :k 2) 1.0))
  (assert (= (context-precision-at-k gr-ids ["econ-2" "econ-3"] :k 2) 1.0))

  (setv ans "Pauli Blendergast teaches at the University of Krampton Ohio [econ-2], which publishes the Journal of Skeptical Economics [econ-3]."
        gnd (groundedness-score ans gr-docs)
        cit (citation-accuracy ans gr-docs)
        bogus-cit (citation-accuracy "Claim [nonexistent-99]." gr-docs))
  (assert (>= gnd 0.8))
  (assert (= (get cit "score") 1.0))
  (assert (= (get bogus-cit "score") 0.0))
  (assert (= (get bogus-cit "hallucinated_citations") ["nonexistent-99"])))
