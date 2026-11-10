;; hy_eval/harness.hy -- Dataset loader, evaluation runner, and macro DSL (defeval, case, expect).

(import dataclasses [dataclass field asdict])
(import json)
(import pathlib [Path])
(import time)
(import hy_eval.metrics [exact-match token-f1-score keyword-check regex-check bow-cosine-similarity])


(defclass [dataclass] CheckResult []
  "Outcome of a single `expect` assertion."
  #^ str name
  #^ bool passed
  #^ float score
  (setv #^ str detail ""))


(defclass [dataclass] CaseResult []
  "Outcome of a single evaluation case containing one or more checks."
  #^ str case-id
  #^ bool passed
  #^ float score
  #^ list checks
  (setv #^ float latency-ms 0.0
        #^ dict metadata (field :default-factory dict)))


(defclass [dataclass] SuiteReport []
  "Aggregated evaluation report for a suite of cases."
  #^ str suite-name
  #^ int total-cases
  #^ int passed-cases
  #^ float pass-rate
  #^ float mean-score
  #^ float mean-latency-ms
  #^ list cases

  (defn to-dict [self]
    (asdict self)))


;; Dynamic collector stack for `(case ...)` blocks so `(expect ...)` works both
;; standalone and inside a `defeval` suite.
(setv _collector-stack [])


(defn load-jsonl [path]
  "Load a list of dicts from a JSON Lines (.jsonl) file."
  (setv records [])
  (with [f (open (Path path) "r" :encoding "utf-8")]
    (for [line f]
      (setv stripped (.strip line))
      (when stripped
        (.append records (json.loads stripped)))))
  records)


(defn save-jsonl [path records]
  "Write a sequence of dicts to a JSON Lines (.jsonl) file."
  (setv p (Path path))
  (.mkdir p.parent :parents True :exist-ok True)
  (with [f (open p "w" :encoding "utf-8")]
    (for [rec records]
      (.write f (+ (json.dumps rec) "\n")))))


(defn run-expect [actual #** kwargs]
  "Evaluate an expectation against `actual`, record it if inside a `case`, and return CheckResult."
  (setv expr-label (.get kwargs "expr" "value")
        custom-name (.get kwargs "name" None)
        result None)

  (cond
    (in "exact" kwargs)
    (do
      (setv target (get kwargs "exact")
            normalize (.get kwargs "normalize" True)
            s (exact-match (str actual) (str target) :normalize normalize))
      (setv result (CheckResult
                     :name (or custom-name f"exact({expr-label})")
                     :passed (= s 1.0)
                     :score s
                     :detail f"expected={(repr target)}, got={(repr actual)}")))

    (or (in "contains" kwargs) (in "not_contains" kwargs))
    (do
      (setv req (.get kwargs "contains" None)
            forb (.get kwargs "not_contains" None)
            kw-res (keyword-check (str actual) :required req :forbidden forb)
            missing-kw (get kw-res "missing")
            forb-kw (get kw-res "forbidden_found"))
      (setv result (CheckResult
                     :name (or custom-name f"keywords({expr-label})")
                     :passed (get kw-res "passed")
                     :score (get kw-res "score")
                     :detail f"missing={missing-kw}, forbidden={forb-kw}")))

    (in "matches" kwargs)
    (do
      (setv pat (get kwargs "matches")
            ok (regex-check (str actual) pat))
      (setv result (CheckResult
                     :name (or custom-name f"regex({pat})")
                     :passed ok
                     :score (if ok 1.0 0.0)
                     :detail f"pattern={(repr pat)}")))

    (in "f1_at_least" kwargs)
    (do
      (setv threshold (float (get kwargs "f1_at_least"))
            ref (str (get kwargs "reference"))
            f1 (token-f1-score (str actual) ref))
      (setv result (CheckResult
                     :name (or custom-name f"token_f1>={threshold}")
                     :passed (>= f1 threshold)
                     :score f1
                     :detail f"f1={f1 :.3f} (min {threshold :.3f})")))

    (in "cosine_at_least" kwargs)
    (do
      (setv threshold (float (get kwargs "cosine_at_least"))
            ref (str (get kwargs "reference"))
            sim (bow-cosine-similarity (str actual) ref))
      (setv result (CheckResult
                     :name (or custom-name f"bow_cosine>={threshold}")
                     :passed (>= sim threshold)
                     :score sim
                     :detail f"cosine={sim :.3f} (min {threshold :.3f})")))

    (in "judge" kwargs)
    (do
      (setv judge-obj (get kwargs "judge")
            question (.get kwargs "question" "")
            ref (.get kwargs "reference" "")
            ctx (.get kwargs "context" "")
            min-score (float (.get kwargs "min_score" 0.7))
            j-res (.score judge-obj question (str actual) :reference ref :context ctx)
            s (float (get j-res "score")))
      (setv result (CheckResult
                     :name (or custom-name "llm_judge")
                     :passed (and (get j-res "passed") (>= s min-score))
                     :score s
                     :detail (get j-res "reason"))))

    (in "predicate" kwargs)
    (do
      (setv pred-fn (get kwargs "predicate")
            ok (bool (pred-fn actual)))
      (setv result (CheckResult
                     :name (or custom-name f"predicate({expr-label})")
                     :passed ok
                     :score (if ok 1.0 0.0)
                     :detail f"value={(repr actual)}")))

    True
    (do
      (setv ok (bool actual))
      (setv result (CheckResult
                     :name (or custom-name f"truthy({expr-label})")
                     :passed ok
                     :score (if ok 1.0 0.0)
                     :detail f"value={(repr actual)}"))))

  (when _collector-stack
    (.append (get _collector-stack -1) result))
  result)


(defn execute-case [#^ str case-id thunk [metadata None]]
  "Run a zero-arg `thunk`, collecting all `expect` checks executed inside it."
  (setv checks []
        start (time.perf-counter))
  (.append _collector-stack checks)
  (try
    (thunk)
    (finally
      (.pop _collector-stack)))
  (setv elapsed (* (- (time.perf-counter) start) 1000.0)
        passed (if checks (all (gfor c checks c.passed)) True)
        score (if checks
                (round (/ (sum (gfor c checks c.score)) (len checks)) 4)
                1.0))
  (CaseResult
    :case-id case-id
    :passed passed
    :score score
    :checks checks
    :latency-ms (round elapsed 2)
    :metadata (if (is metadata None) {} (dict metadata))))


(defn summarize-suite [#^ str suite-name cases]
  "Aggregate a sequence of CaseResult objects into a SuiteReport."
  (setv case-list (list cases)
        total (len case-list)
        passed (sum (gfor c case-list (if c.passed 1 0)))
        pass-rate (if (= total 0) 0.0 (round (/ passed total) 4))
        mean-score (if (= total 0)
                     0.0
                     (round (/ (sum (gfor c case-list c.score)) total) 4))
        mean-lat (if (= total 0)
                   0.0
                   (round (/ (sum (gfor c case-list c.latency-ms)) total) 2)))
  (SuiteReport
    :suite-name suite-name
    :total-cases total
    :passed-cases passed
    :pass-rate pass-rate
    :mean-score mean-score
    :mean-latency-ms mean-lat
    :cases case-list))


(defmacro expect [actual-form #* options]
  "Declarative expectation macro that captures the source form and runs `run-expect`.

  Examples:
    (expect answer :contains [\"Pauli Blendergast\" \"Krampton\"])
    (expect answer :f1-at-least 0.5 :reference gold)"
  `(hy.I.hy_eval/harness.run-expect
     ~actual-form
     :expr ~(hy.repr actual-form)
     ~@options))


(defmacro case [case-id #* body]
  "Define a single evaluation case that times `body` and collects all `expect` checks."
  (setv fn-sym (hy.gensym "case_fn"))
  `(do
     (defn ~fn-sym []
       ~@body)
     (hy.I.hy_eval/harness.execute-case ~case-id ~fn-sym)))


(defmacro defeval [suite-name #* cases]
  "Define a reusable evaluation suite function that returns a SuiteReport.

  Example:
    (defeval rag-smoke-suite
      (case \"blendergast\"
        (setv ans (ask \"Who says economics is bullshit?\"))
        (expect ans :contains \"Pauli Blendergast\")))"
  `(defn ~suite-name []
     (hy.I.hy_eval/harness.summarize-suite
       ~(str suite-name)
       [~@cases])))
