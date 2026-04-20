# Tool Use With Ollama Cloud API

**Book Chapter:** [Running Local LLMs Using Ollama](https://leanpub.com/read/hy-lisp-python/leanpub-auto-running-local-llms-using-ollama) — *A Lisp Programmer Living in Python-Land* (free to read online).

These examples use the Ollama Cloud API (https://ollama.com).

## Setup

1. Install **uv** if it is not already installed on your system.
2. Set the `OLLAMA_API_KEY` environment variable with your Ollama API key.

```bash
export OLLAMA_API_KEY="your-api-key-here"
```

## Run Examples

```bash
# Simple completion example
uv run hy completion.hy

# Tools example
uv run hy ollama_tools_examples.hy
```
