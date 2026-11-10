;; hy_eval/report.hy -- Text tables, failure inspector, and JSON report exporter.

(import json)
(import pathlib [Path])


(defn format-suite-table [report]
  "Format a SuiteReport as a fixed-width ASCII table."
  (setv header f"Suite: {report.suite-name}  ({report.passed-cases}/{report.total-cases} passed, pass_rate={(* report.pass-rate 100) :.1f}%, mean_score={report.mean-score :.3f})"
        sep (+ "+" (* "-" 24) "+" (* "-" 8) "+" (* "-" 9) "+" (* "-" 12) "+" (* "-" 28) "+")
        col-hdr "| Case ID                | Status | Score   | Latency ms | Failed Checks              |"
        lines [header sep col-hdr sep])
  (for [c report.cases]
    (setv status (if c.passed "PASS" "FAIL")
          failed-names (lfor chk c.checks :if (not chk.passed) chk.name)
          failed-str (if failed-names (.join ", " failed-names) "-")
          cid-cell (cut (.ljust c.case-id 22) 0 22)
          fail-cell (cut (.ljust failed-str 26) 0 26))
    (.append lines f"| {cid-cell} | {status :<6} | {c.score :<7.3f} | {c.latency-ms :<10.2f} | {fail-cell} |"))
  (.append lines sep)
  (.join "\n" lines))


(defn format-comparison-table [#^ str name-a metrics-a #^ str name-b metrics-b]
  "Format a side-by-side comparison table between two evaluated systems."
  (setv keys [#("retrieval_recall" "Retrieval Recall@2")
              #("context_precision" "Context Precision@2")
              #("answer_f1" "Answer Token F1")
              #("bow_cosine" "BoW Cosine Similarity")
              #("groundedness" "Groundedness")
              #("citation_accuracy" "Citation Accuracy")
              #("judge_score" "LLM Judge Score")
              #("pass_rate" "Suite Pass Rate")]
        sep (+ "+" (* "-" 25) "+" (* "-" 16) "+" (* "-" 16) "+" (* "-" 12) "+")
        hdr f"| Metric                  | {(cut name-a 0 14) :<14} | {(cut name-b 0 14) :<14} | Delta      |"
        lines [sep hdr sep])
  (for [[key label] keys]
    (setv va (float (.get metrics-a key 0.0))
          vb (float (.get metrics-b key 0.0))
          delta (- vb va)
          sign (if (>= delta 0.0) "+" "")
          delta-str f"{sign}{delta :.3f}")
    (.append lines f"| {label :<23} | {va :<14.3f} | {vb :<14.3f} | {delta-str :<10} |"))
  (.append lines sep)
  (.join "\n" lines))


(defn inspect-failures [report]
  "Return a list of dicts describing every failed check in `report` for error analysis."
  (setv failures [])
  (for [c report.cases]
    (for [chk c.checks]
      (when (not chk.passed)
        (.append failures
          {"case_id" c.case-id
           "check" chk.name
           "score" chk.score
           "detail" chk.detail
           "metadata" c.metadata}))))
  failures)


(defn export-report-json [path payload]
  "Write an evaluation payload dictionary to `path` as formatted JSON."
  (setv p (Path path))
  (.mkdir p.parent :parents True :exist-ok True)
  (with [f (open p "w" :encoding "utf-8")]
    (.write f (+ (json.dumps payload :indent 2) "\n"))))
