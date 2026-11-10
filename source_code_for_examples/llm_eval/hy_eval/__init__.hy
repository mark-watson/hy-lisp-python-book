;; hy_eval/__init__.hy -- Public exports and macro requirements for hy-eval.

(import hy_eval.models [ToolCall ModelResponse FakeModel OllamaModel estimate-tokens])
(import hy_eval.metrics [normalize-text tokenize exact-match token-f1 token-f1-score
                         keyword-check regex-check bow-cosine-similarity LLMJudge pairwise-judge])
(import hy_eval.harness [CheckResult CaseResult SuiteReport load-jsonl save-jsonl
                         run-expect execute-case summarize-suite])
(import hy_eval.tracing [redact-pii redact-with-stats SpanRecord Tracer])
(import hy_eval.structured [CitedAnswer ExtractedTriple extract-json-block generate-structured])
(import hy_eval.rag [DEFAULT_GRAPH_EDGES keyword-retrieve graph-retrieve
                     retrieval-recall-at-k context-precision-at-k groundedness-score citation-accuracy])
(import hy_eval.agent_eval [tool-sequence-score argument-correctness evaluate-trajectory])
(import hy_eval.guardrails [GuardrailViolation detect-prompt-injection ToolAllowlist])
(import hy_eval.ops [BudgetExceededError ResponseCache BudgetTracker ModelRouter])
(import hy_eval.report [format-suite-table format-comparison-table inspect-failures export-report-json])
(require hy_eval.harness [defeval case expect])

(setv __version__ "0.1.0")
