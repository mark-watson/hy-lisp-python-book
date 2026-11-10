;; test_harness.hy -- Tests for the defeval/case/expect macro DSL, dataset loader, and reports.

(import hy)
(import pathlib [Path])
(import hy_eval [load-jsonl save-jsonl format-suite-table inspect-failures])
(require hy_eval [defeval case expect])


(defn test-defeval-macro-and-suite-report []
  (defeval sample-suite
    (case "math-and-text"
      (setv answer "Hy compiles S-expressions to Python AST [hy-1].")
      (expect answer :contains ["S-expressions" "Python AST"])
      (expect answer :matches r"\[hy-\d+\]")
      (expect answer :f1-at-least 0.6 :reference "Hy compiles S-expressions into a Python AST"))

    (case "refusal-check"
      (setv refusal "The provided context does not contain information about chemistry.")
      (expect refusal :contains "does not contain" :not-contains ["burette" "beaker"])))

  (setv report (sample-suite))
  (assert (= report.suite-name "sample-suite"))
  (assert (= report.total-cases 2))
  (assert (= report.passed-cases 2))
  (assert (= report.pass-rate 1.0))
  (assert (> report.mean-score 0.85))
  (setv table (format-suite-table report))
  (assert (in "math-and-text" table))
  (assert (in "PASS" table)))


(defn test-failure-inspection []
  (defeval failing-suite
    (case "broken-case"
      (expect "wrong answer" :exact "expected answer")))

  (setv rep (failing-suite)
        failures (inspect-failures rep))
  (assert (= rep.passed-cases 0))
  (assert (= (len failures) 1))
  (assert (= (get (get failures 0) "case_id") "broken-case")))


(defn test-macroexpand-expect []
  (setv expanded (hy.macroexpand-1 '(expect (ask-model q) :contains "Krampton")))
  (setv rendered (hy.repr expanded))
  (assert (in "run-expect" rendered))
  (assert (in ":expr" rendered)))


(defn test-jsonl-roundtrip [tmp_path]
  (setv target (/ (Path tmp_path) "roundtrip.jsonl")
        rows [{"id" "c1" "question" "Q1"} {"id" "c2" "question" "Q2"}])
  (save-jsonl target rows)
  (setv loaded (load-jsonl target))
  (assert (= loaded rows)))
