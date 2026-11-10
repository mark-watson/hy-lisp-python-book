;; hy_eval/metrics.hy -- Deterministic metrics and LLM-as-judge evaluators.

(import collections [Counter])
(import json)
(import math)
(import re)


(defn normalize-text [#^ str text]
  "Lowercase text, strip punctuation, and collapse whitespace."
  (setv cleaned (re.sub r"[^\w\s]" " " (.lower (or text ""))))
  (.join " " (.split cleaned)))


(defn tokenize [#^ str text]
  "Split text into normalized word tokens."
  (setv norm (normalize-text text))
  (if norm (.split norm) []))


(defn stem-token [#^ str tok]
  "Light suffix normalization so related forms like 'economists'/'economist' align."
  (cond
    (and (> (len tok) 5) (.endswith tok "ing")) (cut tok 0 -3)
    (and (> (len tok) 4) (.endswith tok "ed"))  (cut tok 0 -2)
    (and (> (len tok) 4) (.endswith tok "es"))  (cut tok 0 -2)
    (and (> (len tok) 3) (.endswith tok "s"))   (cut tok 0 -1)
    True tok))


(defn exact-match [#^ str actual #^ str expected [normalize True]]
  "Return 1.0 when actual matches expected, else 0.0."
  (setv a (if normalize (normalize-text actual) (.strip actual))
        b (if normalize (normalize-text expected) (.strip expected)))
  (if (= a b) 1.0 0.0))


(defn token-f1 [#^ str actual #^ str reference]
  "Compute token-level precision, recall, and F1 between actual and reference."
  (setv pred-tokens (tokenize actual)
        ref-tokens (tokenize reference))
  (when (and (not pred-tokens) (not ref-tokens))
    (return {"precision" 1.0 "recall" 1.0 "f1" 1.0}))
  (when (or (not pred-tokens) (not ref-tokens))
    (return {"precision" 0.0 "recall" 0.0 "f1" 0.0}))

  (setv overlap (& (Counter pred-tokens) (Counter ref-tokens))
        num-same (sum (.values overlap)))
  (when (= num-same 0)
    (return {"precision" 0.0 "recall" 0.0 "f1" 0.0}))

  (setv precision (/ num-same (len pred-tokens))
        recall (/ num-same (len ref-tokens))
        f1 (/ (* 2.0 precision recall) (+ precision recall)))
  {"precision" (round precision 4)
   "recall" (round recall 4)
   "f1" (round f1 4)})


(defn token-f1-score [#^ str actual #^ str reference]
  "Return only the F1 float from token-f1."
  (get (token-f1 actual reference) "f1"))


(defn keyword-check [#^ str text [required None] [forbidden None]]
  "Check that all `required` substrings appear (case-insensitive) and no `forbidden` ones do."
  (setv req-list (cond
                   (is required None) []
                   (isinstance required str) [required]
                   True (list required))
        forb-list (cond
                    (is forbidden None) []
                    (isinstance forbidden str) [forbidden]
                    True (list forbidden))
        lowered (.lower (or text ""))
        missing (lfor kw req-list :if (not (in (.lower kw) lowered)) kw)
        found-forb (lfor kw forb-list :if (in (.lower kw) lowered) kw)
        total (+ (len req-list) (len forb-list))
        passed-count (+ (- (len req-list) (len missing))
                        (- (len forb-list) (len found-forb)))
        score (if (= total 0) 1.0 (round (/ passed-count total) 4)))
  {"passed" (and (not missing) (not found-forb))
   "score" score
   "missing" missing
   "forbidden_found" found-forb})


(defn regex-check [#^ str text #^ str pattern]
  "Return True when `pattern` matches `text` (case-insensitive, multiline)."
  (bool (re.search pattern (or text "") (| re.IGNORECASE re.MULTILINE))))


(defn bow-cosine-similarity [#^ str text-a #^ str text-b]
  "Compute bag-of-words cosine similarity on stemmed tokens with zero heavy dependencies."
  (setv toks-a (lfor t (tokenize text-a) (stem-token t))
        toks-b (lfor t (tokenize text-b) (stem-token t)))
  (when (or (not toks-a) (not toks-b))
    (return 0.0))
  (setv vec-a (Counter toks-a)
        vec-b (Counter toks-b)
        common (& (set (.keys vec-a)) (set (.keys vec-b)))
        dot (sum (gfor k common (* (get vec-a k) (get vec-b k))))
        norm-a (math.sqrt (sum (gfor v (.values vec-a) (* v v))))
        norm-b (math.sqrt (sum (gfor v (.values vec-b) (* v v)))))
  (if (or (= norm-a 0.0) (= norm-b 0.0))
    0.0
    (round (/ dot (* norm-a norm-b)) 4)))


(defclass LLMJudge []
  "Rubric-based LLM-as-judge wrapper that works with FakeModel or OllamaModel."

  (defn __init__ [self model [rubric "Score the answer from 0.0 to 1.0 for factual accuracy, completeness, and groundedness in the provided context."]]
    (setv self.model model
          self.rubric rubric))

  (defn score [self #^ str question #^ str answer [reference ""] [context ""]]
    (setv system-prompt
      (+ "You are an impartial evaluation judge. "
         "Evaluate the candidate answer using the rubric and return JSON with keys: "
         "{\"score\": float between 0.0 and 1.0, \"passed\": bool, \"reason\": string}.\n"
         f"Rubric: {self.rubric}"))
    (setv user-prompt
      (+ f"Question: {question}\n"
         (if context f"Context: {context}\n" "")
         (if reference f"Reference Answer: {reference}\n" "")
         f"Candidate Answer: {answer}\n"))
    (setv resp (.generate self.model user-prompt :system system-prompt))
    (try
      (setv match-obj (re.search r"\{.*\}" resp.text re.DOTALL)
            payload (json.loads (if match-obj (.group match-obj 0) resp.text))
            raw-score (float (.get payload "score" 0.0))
            norm-score (if (> raw-score 1.0) (/ raw-score 5.0) raw-score)
            passed (bool (.get payload "passed" (>= norm-score 0.7))))
      {"score" (round (max 0.0 (min 1.0 norm-score)) 4)
       "passed" passed
       "reason" (str (.get payload "reason" ""))
       "latency_ms" resp.latency-ms}
      (except [Exception]
        {"score" 0.0
         "passed" False
         "reason" f"Unparseable judge output: {resp.text}"
         "latency_ms" resp.latency-ms}))))


(defn _parse-winner [#^ str text]
  (try
    (setv m (re.search r"\{.*\}" text re.DOTALL)
          data (json.loads (if m (.group m 0) text))
          w (.upper (str (.get data "winner" "TIE"))))
    (if (in w ["A" "B" "TIE"]) w "TIE")
    (except [Exception]
      "TIE")))


(defn pairwise-judge [model #^ str question #^ str answer-a #^ str answer-b
                      [rubric "Prefer answers that are accurate, grounded in context, and cite sources."]]
  "Compare two candidate answers in both orders (A, B) and (B, A) to detect position bias."
  (setv sys-prompt
    (+ "You are a pairwise evaluation judge. Compare Candidate 1 and Candidate 2. "
       "Return JSON: {\"winner\": \"A\" if Candidate 1 is better, \"B\" if Candidate 2 is better, or \"TIE\", \"reason\": string}.\n"
       f"Rubric: {rubric}"))
  (setv prompt-ab
    f"[PAIRWISE_ORDER:AB]\nQuestion: {question}\nCandidate 1 (A): {answer-a}\nCandidate 2 (B): {answer-b}"
    prompt-ba
    f"[PAIRWISE_ORDER:BA]\nQuestion: {question}\nCandidate 1 (A): {answer-b}\nCandidate 2 (B): {answer-a}")

  (setv resp-ab (.generate model prompt-ab :system sys-prompt)
        resp-ba (.generate model prompt-ba :system sys-prompt)
        win-ab (_parse-winner resp-ab.text)
        win-ba (_parse-winner resp-ba.text))

  ;; When order is swapped (B first, A second), "A" in the second call means answer-b won,
  ;; and "B" in the second call means answer-a won.
  (setv mapped-ba (cond
                    (= win-ba "A") "B"
                    (= win-ba "B") "A"
                    True "TIE"))
  (if (and (= win-ab mapped-ba) (in win-ab ["A" "B"]))
    {"winner" win-ab "consistent" True "first_pass" win-ab "swapped_pass" win-ba}
    {"winner" "TIE" "consistent" (= win-ab mapped-ba) "first_pass" win-ab "swapped_pass" win-ba}))
