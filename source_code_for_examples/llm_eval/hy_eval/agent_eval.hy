;; hy_eval/agent_eval.hy -- Agent tool-call sequence and argument trajectory evaluation.

(defn _call-name [tc]
  (if (hasattr tc "name") tc.name (get tc "name")))


(defn _call-args [tc]
  (if (hasattr tc "arguments") tc.arguments (.get tc "arguments" {})))


(defn tool-sequence-score [actual-calls expected-tool-names]
  "Compare the ordered list of called tool names against `expected-tool-names`."
  (setv actual-names (lfor tc actual-calls (_call-name tc))
        expected (list expected-tool-names))
  (when (and (not expected) (not actual-names))
    (return {"exact_match" True "score" 1.0 "actual" [] "expected" [] "extra_calls" 0}))
  (when (not expected)
    (return {"exact_match" False
             "score" 0.0
             "actual" actual-names
             "expected" []
             "extra_calls" (len actual-names)}))

  ;; Ordered subsequence match count
  (setv exp-idx 0)
  (for [name actual-names]
    (when (and (< exp-idx (len expected)) (= name (get expected exp-idx)))
      (+= exp-idx 1)))

  (setv recall (/ exp-idx (len expected))
        extra (max 0 (- (len actual-names) (len expected)))
        penalty (min 0.5 (* 0.15 extra))
        score (max 0.0 (round (- recall penalty) 4)))
  {"exact_match" (= actual-names expected)
   "score" score
   "actual" actual-names
   "expected" expected
   "extra_calls" extra})


(defn argument-correctness [actual-calls expected-specs]
  "Verify that each expected tool call specification has matching tool name and arguments.

  Each item in `expected-specs` is a dict:
    {\"name\": \"scrape_website_content\", \"arguments\": {\"url\": \"https://markwatson.com\"}}"
  (setv specs (list expected-specs))
  (when (not specs)
    (return {"passed" True "score" 1.0 "details" []}))

  (setv matched-scores []
        details [])
  (for [[idx spec] (enumerate specs)]
    (setv exp-name (get spec "name")
          exp-args (.get spec "arguments" {})
          candidate (if (< idx (len actual-calls)) (get actual-calls idx) None))
    (if (is candidate None)
      (do
        (.append matched-scores 0.0)
        (.append details {"step" idx "expected" exp-name "status" "missing_call"}))
      (do
        (setv act-name (_call-name candidate)
              act-args (_call-args candidate))
        (if (!= act-name exp-name)
          (do
            (.append matched-scores 0.0)
            (.append details {"step" idx
                              "expected" exp-name
                              "actual" act-name
                              "status" "wrong_tool"}))
          (if (not exp-args)
            (do
              (.append matched-scores 1.0)
              (.append details {"step" idx "tool" act-name "status" "ok"}))
            (do
              (setv arg-hits (sum (gfor [k v] (.items exp-args)
                                        (if (and (in k act-args) (= (get act-args k) v)) 1 0)))
                    arg-score (/ arg-hits (len exp-args)))
              (.append matched-scores arg-score)
              (.append details {"step" idx
                                "tool" act-name
                                "arg_score" (round arg-score 4)
                                "status" (if (= arg-score 1.0) "ok" "arg_mismatch")})))))))

  (setv mean-score (round (/ (sum matched-scores) (len specs)) 4))
  {"passed" (= mean-score 1.0)
   "score" mean-score
   "details" details})


(defn evaluate-trajectory [actual-calls expected-specs [max-steps 4]]
  "Evaluate an agent trajectory on tool order, argument accuracy, and step budget."
  (setv expected-names (lfor s expected-specs (get s "name"))
        seq-res (tool-sequence-score actual-calls expected-names)
        arg-res (argument-correctness actual-calls expected-specs)
        within-budget (<= (len actual-calls) max-steps)
        combined (round (* 0.5 (+ (get seq-res "score") (get arg-res "score"))) 4)
        final-score (if within-budget combined (round (* combined 0.7) 4)))
  {"passed" (and (get seq-res "exact_match")
                 (get arg-res "passed")
                 within-budget)
   "score" final-score
   "sequence" seq-res
   "arguments" arg-res
   "within_budget" within-budget
   "steps_used" (len actual-calls)
   "max_steps" max-steps})
