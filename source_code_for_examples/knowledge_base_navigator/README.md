# Knowledge Base Navigator

**Book Chapter:** [Knowledge Base Navigator](https://leanpub.com/read/hy-lisp-python/leanpub-auto-knowledge-base-navigator-building-an-ai-powered-information-system) — *A Lisp Programmer Living in Python-Land* (free to read online).

An AI-powered interactive knowledge exploration tool. Uses Google's Gemini API with web search grounding to extract entities from natural language, then retrieves detailed encyclopedic information and discovers relationships between selected entities.

This is a modern evolution of the KGN (Knowledge Graph Navigator) example — replacing SPARQL/DBPedia queries with an AI-driven pipeline powered by Gemini.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager
- `GOOGLE_API_KEY` environment variable set with your Google AI API key

## Running

```bash
uv sync
uv run hy knowledge_base_navigator.hy
```

Then enter entity names or descriptive sentences at the prompt. The navigator will identify entities, let you select which ones to explore, and provide detailed facts and relationship analysis.
