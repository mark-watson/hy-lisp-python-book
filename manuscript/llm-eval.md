# Evaluating and Operating LLM Applications

Earlier chapters in this book showed how to call language models from OpenAI, Google Gemini, Perplexity, and local Ollama servers, how to build a local vector RAG system with `zvec`, and how to construct a web-scraping agent with Agno. Those programs print useful answers in an interactive session, yet a single successful terminal transcript does not prove that an application works reliably. When you change a system prompt, swap `qwen3:30b` for `qwen3:1.7b`, or alter chunk sizes in a retriever, you need a repeatable way to measure whether accuracy improved or regressed, how much each query costs, and whether an attacker can hijack your tools.

The code for this chapter is in the directory **source_code_for_examples/llm_eval**.

## What You Will Build

In this chapter, I build `hy-eval`, a self-contained evaluation, tracing, structured-output, and operations toolkit written in Hy 1.3.1. We use `hy-eval` to compare a keyword-only RAG baseline (modeled on the `RAG_zvec` chapter) against a graph-enhanced RAG pipeline (modeled on the knowledge graph chapters) and to test an agent trajectory modeled on the `agents_agno` web-scraping agent. Everything runs offline by default using a deterministic `FakeModel`, with an optional flag to run against a local Ollama server.

```text
+-----------------------------------------------------------------------+
|                        hy-eval Toolkit Flow                           |
+-----------------------------------------------------------------------+
|                                                                       |
|  JSONL Dataset (data/eval_cases.jsonl + data/corpus.jsonl)            |
|        |                                                              |
|        v                                                              |
|  Declarative Hy DSL: (defeval suite (case "id" (expect ...)))         |
|        |                                                              |
|        v                                                              |
|  ModelRouter ---> [1. Prompt Injection Guardrail]                     |
|              ---> [2. Deterministic ResponseCache]                    |
|              ---> [3. USD & Token BudgetTracker]                      |
|              ---> [4. Primary Model (OllamaModel) -> FallbackModel]   |
|              ---> [5. Tracer (PII/Secret Redaction -> JSONL Sink)]    |
|        |                                                              |
|        +---> RAG Evaluators (Recall@k, Precision@k, Groundedness,     |
|        |                     Citation Accuracy)                       |
|        +---> Structured Output Loop (Pydantic + Self-Healing Retry)   |
|        +---> Agent Evaluators (Tool Sequence, Argument Correctness,   |
|        |                       ToolAllowlist SSRF Gate)               |
|        +---> Metrics & Judges (Exact, Token F1, BoW Cosine,           |
|                                LLMJudge, Debiased Pairwise Judge)     |
|        |                                                              |
|        v                                                              |
|  ASCII Comparison Tables + Failure Inspector + JSON Report            |
+-----------------------------------------------------------------------+
```

## Why It Matters

Demos fail in production for four reasons:

1. **Nondeterminism and prompt sensitivity.** A minor wording change in a system prompt can fix one question while breaking three others, or cause a model to wrap JSON output in markdown prose that crashes a parser.
2. **Silent retrieval failures in RAG.** When a RAG pipeline gives a bad answer, you cannot tell from the final text alone whether the retriever missed the relevant document chunk or the generator ignored the context it received.
3. **Unbounded agent actions and prompt injection.** An agent equipped with a web scraper or shell tool can be tricked by untrusted text into reading internal network metadata (`http://169.254.169.254`) or leaking secrets into log files.
4. **Uncontrolled latency and token spend.** Calling a large model repeatedly on identical inputs wastes money and time without a response cache, token budget, and fallback router.

## The Hy Angle

Lisp macros let us turn repetitive evaluation boilerplate into a compact specification language. In `hy-eval`, three macros (`defeval`, `case`, and `expect`) capture both the runtime value and the unevaluated Hy source expression at compile time. When a check fails, the report knows which expression produced the value without requiring bytecode decompilation or heavy test-runner plugins.

## Python Equivalent and Macro Expansion

In plain Python, recording the source expression alongside a check result requires either repeating the expression as a string label or writing a custom `pytest` AST rewriter:

```python
# Python: manual ceremony to time a case and label each assertion
def smoke():
    def _case_c1():
        return run_expect(ask(q), expr="ask(q)", contains="Krampton")
    return summarize_suite("smoke", [execute_case("c1", _case_c1)])
```

In Hy, we write the same evaluation suite declaratively:

```hy
(require hy_eval [defeval case expect])

(defeval smoke
  (case "c1"
    (expect (ask q) :contains "Krampton")))
```

We can inspect what `expect` expands to at compile time with `hy.macroexpand-1`:

```hy
'(hy.I.hy_eval/harness.run-expect (ask q) :expr "'(ask q)" :contains "Krampton")
```

Running `uv run hy2py` on the `defeval` snippet shows the exact Python code that Hy generates:

```python
import hy
hy.macros.require('hy_eval', None, target_module_name='<stdin>', assignments=[['defeval', 'defeval'], ['case', 'case'], ['expect', 'expect']], prefix='')

def smoke():

    def _hy_gensym_case_fn_1():
        return hy.I.hyx_hy_evalXsolidusXharness.run_expect(ask(q), expr="'(ask q)", contains='Krampton')
    return hy.I.hyx_hy_evalXsolidusXharness.summarize_suite('smoke', [hy.I.hyx_hy_evalXsolidusXharness.execute_case('c1', _hy_gensym_case_fn_1)])
```

## Input Data Format

Before looking at the code, let us inspect the two JSON Lines (`.jsonl`) files in `data/`. Keeping evaluation data in line-oriented JSON files lets us track changes in Git and add regression cases whenever we find a bug.

The fixture corpus in `data/corpus.jsonl` holds six document chunks spanning the economics examples from the `RAG_zvec` chapter, the Hy compiler, the NSK query engine, and the Agno agent chapter:

```json
{"id": "econ-1", "title": "Microeconomics vs Macroeconomics", "text": "Microeconomics studies the decisions of individuals, households, and firms in specific markets, focusing on supply, demand, pricing, and resource allocation. Macroeconomics analyzes the economy as a whole, examining aggregate indicators such as inflation, national income, gross domestic product (GDP), unemployment, and fiscal or monetary policy.", "entities": ["Microeconomics", "Macroeconomics", "GDP"]}
{"id": "econ-2", "title": "Blendergast on Economic Models", "text": "Pauli Blendergast, a senior economist at the University of Krampton Ohio, famously argued in his 2024 lecture that 'economics is bullshit' when mathematical equilibrium models ignore institutional friction and human irrationality.", "entities": ["Pauli Blendergast", "University of Krampton Ohio"]}
{"id": "econ-3", "title": "Krampton Department Periodicals", "text": "The Krampton Ohio Department of Economics edits the quarterly Journal of Skeptical Economics, studying empirical market failures and behavioral anomalies.", "entities": ["University of Krampton Ohio", "Journal of Skeptical Economics"]}
```

Notice how `econ-2` connects `Pauli Blendergast` to `University of Krampton Ohio`, while `econ-3` connects the Krampton department to the `Journal of Skeptical Economics` without repeating the phrase `"Pauli Blendergast"` or `"University"`. A multi-hop question that asks which journal is published where Blendergast teaches will test whether our retriever can follow entity links across chunks.

The evaluation dataset in `data/eval_cases.jsonl` pairs each question with gold document IDs, a reference answer, required and forbidden keywords, and a flag indicating whether the model should refuse to answer:

```json
{"id": "q-blendergast", "question": "Who says economics is bullshit and at which university does he teach?", "relevant_docs": ["econ-2"], "reference_answer": "Pauli Blendergast, an economist at the University of Krampton Ohio, stated that economics is bullshit [econ-2].", "required_keywords": ["Pauli Blendergast", "Krampton"], "forbidden_keywords": [], "expect_refusal": false}
{"id": "q-krampton-journal", "question": "Which journal is published by the university where Pauli Blendergast teaches?", "relevant_docs": ["econ-2", "econ-3"], "reference_answer": "Pauli Blendergast teaches at the University of Krampton Ohio [econ-2], which publishes the Journal of Skeptical Economics [econ-3].", "required_keywords": ["Journal of Skeptical Economics", "Krampton"], "forbidden_keywords": [], "expect_refusal": false}
{"id": "q-chemistry-refusal", "question": "What titration procedures are performed in organic chemistry labs?", "relevant_docs": [], "reference_answer": "The provided context does not contain information about chemistry lab procedures.", "required_keywords": ["does not contain"], "forbidden_keywords": ["burette", "phenolphthalein", "molarity"], "expect_refusal": true}
```

Including `q-chemistry-refusal` (inspired by the unanswerable chemistry query in the `RAG_zvec` chapter) verifies that our system abstains when the corpus lacks evidence instead of inventing laboratory procedures.

## Run It

Synchronize the environment and run the evaluation demo:

```bash
cd source_code_for_examples/llm_eval
uv sync
uv run hy run_evals.hy
```

The default run uses `FakeModel` so it finishes in under a second with no API keys or local daemon required. Passing `uv run hy run_evals.hy --live-ollama` attempts to query a local `qwen3:1.7b` model via Ollama and falls back to `FakeModel` with a note if Ollama is not running.

Here is the real output from `uv run hy run_evals.hy`:

```text
=== 1. RAG System Comparison: Baseline Keyword vs Graph-Enhanced ===
+-------------------------+----------------+----------------+------------+
| Metric                  | Baseline RAG   | Graph RAG      | Delta      |
+-------------------------+----------------+----------------+------------+
| Retrieval Recall@2      | 0.900          | 1.000          | +0.100     |
| Context Precision@2     | 1.000          | 1.000          | +0.000     |
| Answer Token F1         | 0.763          | 0.892          | +0.129     |
| BoW Cosine Similarity   | 0.790          | 0.905          | +0.115     |
| Groundedness            | 0.877          | 0.924          | +0.047     |
| Citation Accuracy       | 0.200          | 1.000          | +0.800     |
| LLM Judge Score         | 0.830          | 0.950          | +0.120     |
| Suite Pass Rate         | 0.200          | 1.000          | +0.800     |
+-------------------------+----------------+----------------+------------+

=== 2. Pairwise Position-Debiased Judge (Multi-Hop Krampton Case) ===
Winner: System B (order-consistent=True, AB=B, BA=A)

=== 3. Per-Case Suite Reports ===
Suite: baseline-keyword-rag  (1/5 passed, pass_rate=20.0%, mean_score=0.706)
+------------------------+--------+---------+------------+----------------------------+
| Case ID                | Status | Score   | Latency ms | Failed Checks              |
+------------------------+--------+---------+------------+----------------------------+
| q-blendergast          | FAIL   | 0.790   | 0.12       | citation_accuracy==1.0     |
| q-krampton-journal     | FAIL   | 0.170   | 0.05       | retrieval_recall==1.0, req |
| q-micro-macro          | FAIL   | 0.790   | 0.04       | citation_accuracy==1.0     |
| q-chemistry-refusal    | PASS   | 0.990   | 0.03       | -                          |
| q-hy-nsk-macros        | FAIL   | 0.790   | 0.03       | citation_accuracy==1.0     |
+------------------------+--------+---------+------------+----------------------------+

Suite: graph-enhanced-rag  (5/5 passed, pass_rate=100.0%, mean_score=0.990)
+------------------------+--------+---------+------------+----------------------------+
| Case ID                | Status | Score   | Latency ms | Failed Checks              |
+------------------------+--------+---------+------------+----------------------------+
| q-blendergast          | PASS   | 0.990   | 0.03       | -                          |
| q-krampton-journal     | PASS   | 0.990   | 0.04       | -                          |
| q-micro-macro          | PASS   | 0.990   | 0.03       | -                          |
| q-chemistry-refusal    | PASS   | 0.990   | 0.02       | -                          |
| q-hy-nsk-macros        | PASS   | 0.990   | 0.03       | -                          |
+------------------------+--------+---------+------------+----------------------------+

=== 4. Failure Inspection (Baseline RAG) ===
  - [q-blendergast] citation_accuracy==1.0 (score=0.0): value=0.0
  - [q-krampton-journal] retrieval_recall==1.0 (score=0.0): value=0.5
  - [q-krampton-journal] required_keywords (score=0.5): missing=['Journal of Skeptical Economics'], forbidden=[]
  - [q-krampton-journal] groundedness>=0.75 (score=0.0): value=0.6667
  - [q-krampton-journal] citation_accuracy==1.0 (score=0.0): value=0.0
  - [q-krampton-journal] llm_judge (score=0.35): Misses the specific journal name Journal of Skeptical Economics because chunk econ-3 was not retrieved.
  - [q-micro-macro] citation_accuracy==1.0 (score=0.0): value=0.0
  - [q-hy-nsk-macros] citation_accuracy==1.0 (score=0.0): value=0.0

=== 5. Operational Readiness Suite (Structured Retry, Agent, Guardrails, Cache) ===
Suite: operational-readiness-suite  (4/4 passed, pass_rate=100.0%, mean_score=1.000)
+------------------------+--------+---------+------------+----------------------------+
| Case ID                | Status | Score   | Latency ms | Failed Checks              |
+------------------------+--------+---------+------------+----------------------------+
| structured-output-self | PASS   | 1.000   | 0.66       | -                          |
| agno-agent-trajectory  | PASS   | 1.000   | 0.08       | -                          |
| guardrails-injection-a | PASS   | 1.000   | 0.04       | -                          |
| cache-and-pii-redactio | PASS   | 1.000   | 0.10       | -                          |
+------------------------+--------+---------+------------+----------------------------+

=== 6. Trace & Budget Telemetry Summary ===
{
  "trace_id": "demo0001",
  "total_spans": 13,
  "total_tokens": 1075,
  "total_cost_usd": 0.000518,
  "cache_hits": 1,
  "total_redactions": 4,
  "budget_remaining_usd": 0.049482
}
```

## Interpreting the Results: Avoid Metric Worship

Look closely at the numbers for `Baseline RAG` in Section 1 of the output above. Its average `Context Precision@2` is `1.000`, its `Retrieval Recall@2` is `0.900`, its `Groundedness` is `0.877`, and its average `LLM Judge Score` is `0.830`. If a team only tracked aggregate averages on a dashboard, they might ship `Baseline RAG` thinking it is 85% to 90% accurate.

Yet the `Suite Pass Rate` is `0.200` (only 1 of 5 cases passed). Section 4 (`Failure Inspection`) shows why aggregate averages can mislead you:

1. **Multi-hop retrieval failure on `q-krampton-journal`.** Keyword retrieval found `econ-2` (because the question mentions `Pauli Blendergast`), giving a 50% recall on that question and a 90% recall average across the five questions. Because it missed `econ-3`, the generator did not know the title *Journal of Skeptical Economics* and guessed `"an economics review"`. That single missing chunk caused four downstream checks to fail: `retrieval_recall`, `required_keywords`, `groundedness`, and `llm_judge`.
2. **Missing source citations.** On `q-blendergast`, `q-micro-macro`, and `q-hy-nsk-macros`, the baseline prose was factually right, so token F1 and the LLM judge scored it high, but it omitted bracketed `[doc-id]` citations. Only the chemistry refusal case passed all five checks.

The lesson is simple: **do not worship aggregate metrics**. Prefer a small, well-understood evaluation set where you inspect every failed check over a large, noisy benchmark that reduces system behavior to a single number.

## How It Works

The `hy_eval` package is organized into nine focused modules. Let us walk through each component.

### 1. Model Abstraction: `hy_eval/models.hy`

To run fast, deterministic evaluations in continuous integration (CI) while supporting live local models when needed, `hy_eval/models.hy` defines a uniform `ModelResponse` dataclass and two model classes: `FakeModel` and `OllamaModel`.

```hy
(defclass [(dataclass :frozen True)] ToolCall []
  "A structured tool call emitted by a model or agent."
  #^ str name
  #^ dict arguments)


(defclass [dataclass] ModelResponse []
  "Standardized model response with token, latency, cost, and tool telemetry."
  #^ str text
  #^ str model
  (setv #^ int prompt-tokens 0
        #^ int completion-tokens 0
        #^ float latency-ms 0.0
        #^ float cost-usd 0.0
        #^ bool cached False
        #^ list tool-calls (field :default-factory list)))
```

`FakeModel` matches substrings in the combined system and user prompt against a dictionary of recorded responses. An entry in `responses` can be a string, a dictionary containing `tool_calls`, a callable, or a list of responses consumed in sequence across successive calls. Returning a sequence of replies lets us test retry loops where the first model call returns malformed JSON and the second call succeeds:

```hy
(defclass FakeModel []
  "Deterministic, offline model for tests and reproducible evaluations.

  `responses` maps a prompt substring to one of:
    - a plain string reply
    - a dict with keys 'text', optional 'tool_calls', optional 'latency_ms'
    - a list of replies consumed in order (useful for testing retries)
    - a callable (fn [prompt system] ...) returning a string or dict"

  (defn __init__ [self
                  [name "fake-qwen3:1.7b"]
                  [responses None]
                  [default-response "The provided context does not contain enough information."]
                  [cost-per-1k-tokens 0.0005]
                  [simulated-latency-ms 4.2]]
    (setv self.name name
          self.responses (if (is responses None) {} (dict responses))
          self.default-response default-response
          self.cost-per-1k-tokens cost-per-1k-tokens
          self.simulated-latency-ms simulated-latency-ms
          self.history []
          self._cursors {}))

  (defn _resolve-entry [self key entry prompt system]
    (cond
      (isinstance entry list)
      (do
        (setv idx (.get self._cursors key 0))
        (setv chosen (get entry (min idx (- (len entry) 1))))
        (setv (get self._cursors key) (+ idx 1))
        chosen)

      (callable entry)
      (entry prompt system)

      True
      entry))
```

`OllamaModel` uses Python's standard `urllib.request` module (just like the `RAG_zvec` chapter) to call `/api/chat` on a local Ollama daemon, and falls back to `self.fallback` if the daemon is unreachable.

### 2. Metrics and Position-Debiased Judges: `hy_eval/metrics.hy`

A practical evaluation suite mixes fast deterministic checks with rubric-based model judges:

- `exact-match`: normalizes case, punctuation, and whitespace before comparing strings.
- `token-f1`: computes multiset token precision, recall, and F1 overlap using `collections.Counter`.
- `keyword-check` and `regex-check`: verify that required domain terms appear and forbidden hallucination terms do not.
- `bow-cosine-similarity`: computes bag-of-words cosine similarity over lightly stemmed tokens using standard-library `math.sqrt`, avoiding heavy neural embedding dependencies in unit tests.
- `LLMJudge` and `pairwise-judge`: grade open-ended answers against a rubric.

```hy
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
```

When using an LLM to compare two system outputs (`A` and `B`), models exhibit **position bias**: weak judges often favor whichever candidate is listed first. Our `pairwise-judge` function calls the judge model twice, first in order `(A, B)` and then in swapped order `(B, A)`. It declares a winner only if both passes agree on the same underlying answer:

```hy
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
```

### 3. The Evaluation Harness and Macro DSL: `hy_eval/harness.hy`

`hy_eval/harness.hy` provides JSONL dataset helpers (`load-jsonl` and `save-jsonl`), the runtime check dispatcher `run-expect`, and the three macros `expect`, `case`, and `defeval`.

A small stack (`_collector-stack`) lets `expect` work both as a standalone assertion in a REPL or test function and as a check collector inside a `case` block:

```hy
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


(defmacro expect [actual-form #* options]
  "Declarative expectation macro that captures the source form and runs `run-expect`."
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
  "Define a reusable evaluation suite function that returns a SuiteReport."
  `(defn ~suite-name []
     (hy.I.hy_eval/harness.summarize-suite
       ~(str suite-name)
       [~@cases])))
```

Notice the hygiene in `case`: `(hy.gensym "case_fn")` creates a unique temporary function symbol so nested or adjacent cases never collide with user variables.

### 4. Tracing and PII Redaction: `hy_eval/tracing.hy`

When an LLM application misbehaves in production, you need the exact prompt, response, token count, latency, and cost written to an inspectable log. At the same time, user prompts often contain email addresses, phone numbers, Social Security numbers, or accidentally pasted API keys that must never land in plain text on disk.

`hy_eval/tracing.hy` runs every prompt and response through `redact-with-stats` before storing a `SpanRecord` in memory or appending it to a `.jsonl` trace file:

```hy
(setv _REDACTION_PATTERNS
  [#("API_KEY"
     (re.compile r"(?:sk-[A-Za-z0-9_-]{12,}|Bearer\s+[A-Za-z0-9._-]{12,}|(?:OPENAI|ANTHROPIC|GEMINI)_API_KEY\s*=\s*\S+)"))
   #("EMAIL"
     (re.compile r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"))
   #("SSN"
     (re.compile r"\b\d{3}-\d{2}-\d{4}\b"))
   #("PHONE"
     (re.compile r"(?<!\d)(?:\+1[-.\s]?)?\(?\d{3}\)?[-.\s]\d{3}[-.\s]\d{4}(?!\d)"))])


(defn redact-with-stats [#^ str text]
  "Replace secrets and PII tokens in `text`. Return #(redacted_text count)."
  (when (not text)
    (return #("" 0)))
  (setv out text
        total-count 0)
  (for [[label pattern] _REDACTION_PATTERNS]
    (setv [out n] (.subn pattern f"[REDACTED_{label}]" out))
    (+= total-count n))
  #(out total-count))
```

### 5. Structured Output Validation and Retry Loop: `hy_eval/structured.hy`

Downstream code often expects a typed structure rather than free-form prose. `hy_eval/structured.hy` defines Pydantic models (`CitedAnswer` and `ExtractedTriple`) and a `generate-structured` function. If the model wraps its JSON in markdown code fences, `extract-json-block` strips the fences; if `json.loads` or Pydantic's `.model_validate` raises an error, `generate-structured` feeds the exact validation error message back to the model in a repair prompt up to `max-retries` times:

```hy
(defclass CitedAnswer [BaseModel]
  "Structured RAG answer with required source citations and confidence score."
  #^ str answer
  (setv #^ (get list str) citations (Field :default-factory list)
        #^ float confidence (Field :ge 0.0 :le 1.0)
        #^ bool abstained False)

  (defn [(field_validator "answer")] non-empty-answer [cls v]
    (when (not (.strip v))
      (raise (ValueError "answer must not be empty")))
    v))


(defn generate-structured [model schema-cls #^ str prompt [system ""] [max-retries 2]]
  "Generate a response validated against `schema-cls` (a Pydantic BaseModel).

  On invalid JSON or schema validation failure, feeds the error back to the
  model up to `max-retries` times."
  (setv schema-json (json.dumps (.model_json_schema schema-cls))
        full-system
        (+ (if system (+ system "\n\n") "")
           "Respond ONLY with valid JSON conforming to this JSON Schema:\n"
           schema-json)
        current-prompt prompt
        errors []
        last-raw "")

  (for [attempt (range (+ max-retries 1))]
    (setv resp (.generate model current-prompt :system full-system)
          last-raw resp.text)
    (try
      (setv candidate (extract-json-block resp.text)
            parsed (json.loads candidate)
            validated (.model_validate schema-cls parsed))
      (return {"valid" True
               "data" validated
               "attempts" (+ attempt 1)
               "errors" errors
               "raw_response" last-raw})
      (except [e #(json.JSONDecodeError ValidationError ValueError)]
        (setv err-msg (str e))
        (.append errors err-msg)
        (setv current-prompt
          (+ prompt
             f"\n\n[VALIDATION_RETRY_{attempt}]\n"
             f"Your previous output was invalid:\n{resp.text}\n"
             f"Validation error:\n{err-msg}\n"
             "Return ONLY corrected JSON matching the schema.")))))

  {"valid" False
   "data" None
   "attempts" (+ max-retries 1)
   "errors" errors
   "raw_response" last-raw})
```

### 6. Evaluating RAG Retrieval and Groundedness: `hy_eval/rag.hy`

In the `RAG_zvec` chapter, we built an offline vector RAG pipeline over local text files. Evaluating a RAG system requires measuring the **retriever** and the **generator** separately:

1. **Retrieval Recall@k (`retrieval-recall-at-k`)**: what fraction of the gold relevant document IDs appear in the top `k` retrieved chunks?
2. **Context Precision@k (`context-precision-at-k`)**: are the relevant chunks ranked near the top of the retrieved list?
3. **Groundedness (`groundedness-score`)**: what fraction of content words in the answer are supported by the retrieved chunks (or did the model properly abstain)?
4. **Citation Accuracy (`citation-accuracy`)**: do the bracketed `[doc-id]` citations in the answer refer to chunks that were actually retrieved, with zero hallucinated IDs?

`hy_eval/rag.hy` also compares `keyword-retrieve` against `graph-retrieve`, which expands one hop across entity edges (`DEFAULT_GRAPH_EDGES`) to pull in connected evidence chunks:

```hy
(defn graph-retrieve [corpus #^ str query [graph-edges None] [top-k 2]]
  "Retrieve initial chunks by keyword overlap, then expand 1 hop over entity edges."
  (setv edges (if (is graph-edges None) DEFAULT_GRAPH_EDGES graph-edges)
        initial (keyword-retrieve corpus query :top-k top-k)
        by-id (dfor doc corpus (get doc "id") doc)
        seen-ids (set (gfor d initial (get d "id")))
        results (list initial)
        seed-entities (set))

  (for [doc initial]
    (for [ent (.get doc "entities" [])]
      (.add seed-entities (.lower ent))))
  (setv q-lower (.lower query))
  (for [edge edges]
    (when (in (.lower (get edge "source")) q-lower)
      (.add seed-entities (.lower (get edge "source"))))
    (when (in (.lower (get edge "target")) q-lower)
      (.add seed-entities (.lower (get edge "target")))))

  ;; Expand one hop along matching graph edges
  (for [edge edges]
    (setv src (.lower (get edge "source"))
          tgt (.lower (get edge "target"))
          target-doc-id (get edge "doc_id"))
    (when (and (or (in src seed-entities) (in tgt seed-entities))
               (in target-doc-id by-id)
               (not (in target-doc-id seen-ids))
               (< (len results) top-k))
      (.add seen-ids target-doc-id)
      (.append results (get by-id target-doc-id))))

  (cut results 0 top-k))
```

### 7. Agent Trajectory Evaluation and Guardrails: `hy_eval/agent_eval.hy` and `hy_eval/guardrails.hy`

In the `agents_agno` chapter, an agent called `scrape-website-content` on `https://markwatson.com` to answer a question about musical instruments. Evaluating an agent requires checking **how** it reached its answer:

- Did it invoke the expected sequence of tools (`tool-sequence-score`)?
- Did it pass the right arguments (`argument-correctness`)?
- Did it stay within the step budget (`evaluate-trajectory`)?

Before executing any tool call or model prompt, `hy_eval/guardrails.hy` enforces two defenses:

1. `detect-prompt-injection` scans untrusted inputs for instruction overrides (`"Ignore all previous instructions"`), system prompt extraction attempts, role hijacks (`"You are now DAN"`), and delimiter escapes.
2. `ToolAllowlist` implements a deny-by-default permission gate. Even when `scrape_website_content` is on the allowlist, `ToolAllowlist` inspects any `url` argument to block `file://` schemes, loopback addresses (`localhost`, `127.0.0.1`), cloud metadata endpoints (`169.254.169.254`), and domains outside `allowed_domains`:

```hy
(defclass ToolAllowlist []
  "Deny-by-default permission gate for agent tools and URL arguments."

  (defn __init__ [self allowed-tools [allowed-domains None]]
    (setv self.allowed-tools (set allowed-tools)
          self.allowed-domains (if (is allowed-domains None)
                                 None
                                 (set (gfor d allowed-domains (.lower d))))))

  (defn validate-call [self #^ str tool-name [arguments None]]
    "Return {\"allowed\": bool, \"reason\": str} for a proposed tool call."
    (setv args (if (is arguments None) {} (dict arguments)))
    (when (not (in tool-name self.allowed-tools))
      (return {"allowed" False
               "reason" f"Tool '{tool-name}' is not in the allowlist."}))

    (when (in "url" args)
      (setv raw-url (str (get args "url"))
            parsed (urlparse raw-url)
            scheme (.lower (or parsed.scheme ""))
            host (.lower (or parsed.hostname "")))
      (when (not (in scheme #{"http" "https"}))
        (return {"allowed" False
                 "reason" f"Disallowed URL scheme '{scheme}' in {(repr raw-url)}."}))
      (when (or (not host) (_is-private-host host))
        (return {"allowed" False
                 "reason" f"Blocked private or loopback host '{host}'."}))
      (when (not (is self.allowed-domains None))
        (setv domain-ok (any (gfor d self.allowed-domains
                                   (or (= host d) (.endswith host (+ "." d))))))
        (when (not domain-ok)
          (setv allowed-list (sorted self.allowed-domains))
          (return {"allowed" False
                   "reason" f"Host '{host}' is outside allowed domains {allowed-list}."}))))

    {"allowed" True "reason" "ok"}))
```

### 8. Operations: Cache, Budgets, and Fallback Routing: `hy_eval/ops.hy`

`ModelRouter` wraps a primary model and a list of fallback models with `detect-prompt-injection`, `ResponseCache`, `BudgetTracker`, and `Tracer`. When a request arrives:

1. The router checks the prompt against the injection guardrail.
2. It checks `ResponseCache`. On a cache hit, it returns a copy of the cached `ModelResponse` with `cached=True` and `cost_usd=0.0`.
3. It checks `BudgetTracker` to ensure cumulative USD spend and token usage remain below their hard ceilings.
4. It calls the primary model. If the primary model raises a network or timeout error, it iterates through `self.fallbacks` and records the fallback index in the trace tags.

## Putting Evaluations in Continuous Integration (CI)

A good evaluation workflow splits tests into two tiers:

1. **Fast smoke evaluations on every pull request (under 5 seconds).** Run `uv run pytest -q` and `uv run hy run_evals.hy` using `FakeModel` and recorded fixtures. Every PR verifies that prompt templates, structured-output Pydantic schemas, retrieval logic, citation parsers, guardrails, PII redaction, and agent trajectory checks pass 100% deterministically with zero API cost.
2. **Scheduled nightly evaluations against live models.** On a nightly cron job (or before cutting a release), run the full dataset against your live local Ollama model (`uv run hy run_evals.hy --live-ollama`) or cloud provider, export the JSON report with `export-report-json`, and alert when retrieval recall, groundedness, or pass rate drops below your baseline threshold.

## Tests

The project includes four offline test suites (`test_metrics.hy`, `test_harness.hy`, `test_structured.hy`, and `test_guardrails.hy`) containing 18 tests covering deterministic metrics, debiased pairwise judges, macro expansion, JSONL round-tripping, self-healing Pydantic retries, agent trajectories, SSRF blocking, PII redaction, caching, and budget enforcement.

Run the test suite with `pytest`:

```bash
$ uv run pytest -q
..................                                                       [100%]
18 passed in 0.11s
```

## Wrap Up

In this chapter, we moved from one-off LLM demos to an observable, testable engineering workflow. We built `hy-eval` in Hy 1.3.1 using macros (`defeval`, `case`, `expect`) for readable evaluation suites, combined deterministic metrics with a position-debiased pairwise judge, validated structured outputs with Pydantic retry loops, measured RAG retrieval separately from generation, enforced deny-by-default tool allowlists, and traced every call with automatic PII redaction. Most importantly, our side-by-side comparison of keyword RAG and graph-enhanced RAG showed why engineers must inspect individual failure cases rather than trusting high aggregate metric averages.

## Optional Practice Problems

1. **Add a Latency SLA Expectation (Small)**:
   Extend `run-expect` in `hy_eval/harness.hy` to support a `:max-latency-ms` keyword option when passed a `ModelResponse`. Add a test case in `test_harness.hy` asserting that a cached response from `ModelRouter` finishes in under `1.0` millisecond.
2. **Evaluate Live `zvec` and Agno Pipelines (Open-Ended)**:
   Import `hy_eval` into the `RAG_zvec` or `agents_agno` example directory. Record five real responses from your local Ollama model into a `.jsonl` fixture file, write a `defeval` suite that checks groundedness and tool argument safety, and compare `qwen3:1.7b` against another local model using `format-comparison-table`.

## Further Reading

- Chip Huyen, *AI Engineering* (O'Reilly, 2025), Chapters 3-6 and 10 on evaluation methodology, RAG evaluation, guardrails, and observability.
- Paul Iusztin and Maxime Labonne, *LLM Engineer's Handbook* (Packt, 2024), on end-to-end RAG evaluation and monitoring pipelines.
- Tomaž Bratanič and Oskar Hane, *Essential GraphRAG* (Manning, 2025), on combining structured graph traversal with text retrieval for traceable answers.
- [Hy 1.3.1 Macros Manual](https://hylang.org/hy/doc/v1.3.1/macros) for details on `defmacro`, `hy.gensym`, `require`, and `hy.macroexpand-1`.
