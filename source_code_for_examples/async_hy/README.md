# Async and Concurrent Hy (`async_hy`)

This project contains the runnable code for the "Async and Concurrent Hy" chapter. It covers `asyncio` coroutines, `TaskGroup` structured concurrency, `except*` exception groups, async context managers and generators, bounded `httpx.AsyncClient` requests with retries and rate limiting, NDJSON/SSE LLM token streaming, an `asyncio.Queue` crawl-extract-index pipeline, thread and process pools (`asyncio.to_thread` and `ProcessPoolExecutor`), and an async port of the book's web scraper.

## Project Structure

```text
async_hy/
├── basics.hy          # defn :async, fn :async, TaskGroup, timeout, except*, async generators
├── bounded_fetch.hy   # httpx.AsyncClient, Semaphore, exponential backoff, rate limiter, MockTransport
├── streaming_llm.hy   # Ollama NDJSON and SSE streaming via httpx .stream / .aiter-lines
├── pipeline.hy        # Bounded asyncio.Queue producer/consumer pipeline: crawl -> extract -> index
├── cpu_offload.hy     # asyncio.to_thread, ThreadPoolExecutor, ProcessPoolExecutor, GIL status check
├── async_scraper.hy   # Case study: sequential vs concurrent BeautifulSoup scraper with timings
├── demo.hy            # Guided tour that runs all six modules and prints timings
├── test_async.hy      # Deterministic pytest-asyncio test suite (no live network required)
├── conftest.py        # pytest hook to collect test_*.hy files
└── pyproject.toml     # Project dependencies and pytest-asyncio configuration
```

## Prerequisites

- Python 3.12 or newer
- [`uv`](https://docs.astral.sh/uv/)
- Optional: a local [Ollama](https://ollama.com/) server with `qwen3.5:4b` for the live streaming check in `demo.hy` (falls back automatically to an in-memory mock stream when Ollama is not running).

## Run the Guided Tour

```bash
uv sync
uv run hy demo.hy
```

## Inspect Generated Python (`hy2py`)

```bash
uv run hy2py basics.hy
```

## Run the Tests

All tests use `httpx.MockTransport` and local fixtures, so they run offline:

```bash
uv run pytest -q
```
