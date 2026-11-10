# hy-eval: Evaluating and Operating LLM Applications in Hy

`hy-eval` is a compact evaluation, observability, structured-output validation, and safety toolkit for Large Language Model (LLM) applications written in Hy 1.3.1.

It accompanies the chapter **"Evaluating and Operating LLM Applications"** in *A Lisp Programmer Living in Python-Land*.

## Project Structure

```text
llm_eval/
├── pyproject.toml           <- Project metadata and dependencies (hy, pydantic, pytest)
├── conftest.py              <- Enables pytest collection of test_*.hy files
├── README.md                <- Project overview and usage guide
├── data/
│   ├── corpus.jsonl         <- Offline fixture corpus (economics, Hy, NSK, Agno)
│   └── eval_cases.jsonl     <- Evaluation dataset with questions, gold docs, and rubrics
├── hy_eval/
│   ├── __init__.hy          <- Public exports and macro requirements (defeval, case, expect)
│   ├── models.hy            <- ModelResponse, ToolCall, FakeModel, and OllamaModel
│   ├── metrics.hy           <- Exact match, token F1, keyword/regex, BoW cosine, LLMJudge, pairwise-judge
│   ├── harness.hy           <- Dataset loader, runner, and declarative macros (defeval, case, expect)
│   ├── tracing.hy           <- SpanRecord, Tracer, JSONL sink, and PII/secret redaction
│   ├── structured.hy        <- Pydantic validation (CitedAnswer, ExtractedTriple) + retry repair loop
│   ├── rag.hy               <- Keyword vs graph-enhanced retrieval, recall@k, precision@k, groundedness, citations
│   ├── agent_eval.hy        <- Tool sequence and argument trajectory evaluation
│   ├── guardrails.hy        <- Heuristic prompt-injection detector and deny-by-default ToolAllowlist
│   ├── ops.hy               <- ResponseCache, BudgetTracker, and fallback ModelRouter
│   └── report.hy            <- ASCII report tables, failure inspector, and JSON export
├── run_evals.hy             <- End-to-end CLI demo comparing Baseline RAG vs Graph-Enhanced RAG
├── test_metrics.hy          <- Tests for deterministic metrics, RAG metrics, and LLM judges
├── test_harness.hy          <- Tests for defeval/case/expect macros, JSONL I/O, and failure reports
├── test_structured.hy       <- Tests for Pydantic schema retry loop and agent trajectories
└── test_guardrails.hy       <- Tests for prompt injection, tool allowlists, PII redaction, cache, and router
```

## Prerequisites

- Python >= 3.12
- [`uv`](https://docs.astral.sh/uv/) package manager
- No API keys or running Ollama server are required for the default demo or test suite (`FakeModel` provides deterministic offline execution).
- Optional: a local [Ollama](https://ollama.com/) server with `qwen3:1.7b` when running `run_evals.hy --live-ollama`.

## Install and Run

Synchronize the virtual environment and dependencies:

```bash
uv sync
```

Run the side-by-side RAG comparison and operational readiness evaluation suite:

```bash
uv run hy run_evals.hy
```

To try a local Ollama model (with automatic fallback to `FakeModel` if Ollama is not running):

```bash
uv run hy run_evals.hy --live-ollama
```

## Run the Tests

All tests run offline without network calls or external services:

```bash
uv run pytest -q
```
