;; test_structured.hy -- Tests for Pydantic structured validation, retry loop, and agent trajectories.

(import hy_eval [FakeModel ToolCall CitedAnswer ExtractedTriple
                 extract-json-block generate-structured
                 tool-sequence-score argument-correctness evaluate-trajectory])


(defn test-extract-json-from-fenced-markdown []
  (setv raw "Here is your output:\n```json\n{\"subject\": \"Hy\", \"predicate\": \"targets\", \"object\": \"Python AST\"}\n```")
  (setv extracted (extract-json-block raw))
  (assert (.startswith extracted "{"))
  (assert (in "Python AST" extracted)))


(defn test-structured-validation-self-healing-retry []
  (setv model (FakeModel
                :responses
                {"Extract citation"
                 [;; Attempt 1: malformed JSON
                  "not valid json at all"
                  ;; Attempt 2: valid JSON but fails Pydantic constraint (confidence > 1.0)
                  "{\"answer\": \"Blendergast [econ-2]\", \"citations\": [\"econ-2\"], \"confidence\": 2.5}"
                  ;; Attempt 3: valid JSON and satisfies Pydantic schema
                  "{\"answer\": \"Blendergast [econ-2]\", \"citations\": [\"econ-2\"], \"confidence\": 0.9, \"abstained\": false}"]}))
  (setv result (generate-structured model CitedAnswer "Extract citation" :max-retries 2))
  (assert (get result "valid"))
  (assert (= (get result "attempts") 3))
  (assert (= (len (get result "errors")) 2))
  (assert (= (. (get result "data") confidence) 0.9))
  (assert (= (. (get result "data") citations) ["econ-2"])))


(defn test-structured-validation-exhausts-retries []
  (setv model (FakeModel
                :responses {"Always bad" "{\"answer\": \"\", \"confidence\": -5.0}"})
        result (generate-structured model CitedAnswer "Always bad" :max-retries 1))
  (assert (not (get result "valid")))
  (assert (is (get result "data") None))
  (assert (= (get result "attempts") 2)))


(defn test-agent-trajectory-evaluation []
  (setv calls [(ToolCall :name "scrape_website_content"
                         :arguments {"url" "https://markwatson.com"})]
        expected [{"name" "scrape_website_content"
                   "arguments" {"url" "https://markwatson.com"}}]
        verdict (evaluate-trajectory calls expected :max-steps 2))
  (assert (get verdict "passed"))
  (assert (= (get verdict "score") 1.0))

  ;; Wrong URL argument fails argument correctness
  (setv wrong-calls [(ToolCall :name "scrape_website_content"
                               :arguments {"url" "https://example.com"})]
        bad-verdict (evaluate-trajectory wrong-calls expected :max-steps 2))
  (assert (not (get bad-verdict "passed")))
  (assert (< (get bad-verdict "score") 1.0)))
