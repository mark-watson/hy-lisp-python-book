# Using the Brave Search APIs

**Book Chapter:** [Using the Brave Search APIs](https://leanpub.com/read/hy-lisp-python/leanpub-auto-using-the-brave-search-apis) — *A Lisp Programmer Living in Python-Land* (free to read online).

This example demonstrates calling the [Brave Search API](https://brave.com/search/api/) from Hy. The `brave.hy` module provides a `brave-search` function that returns structured search results (title, URL, description). It is designed to be loaded interactively so you can experiment with different queries in the REPL.

![Brave Search API client architecture: query flow through REST API to structured results](FIG_brave_search.png)

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager
- A Brave Search API key set as the `BRAVE_API_KEY` environment variable (see book for details on obtaining a key)

## Running the Example

```bash
uv sync
uv run hy -i brave.hy
```

Then call `brave-search` from the REPL:

```lisp
=> (brave-search "site:wikidata.org Sedona Arizona")
[["Sedona - Wikidata" "https://www.wikidata.org/wiki/Q80041" "city in counties of Yavapai and Coconino, ...]]
```

## Running the Tests

The tests are written in Hy in `test_brave.hy`. Run them with:

```bash
uv run pytest
```

No API key or network access is needed: `requests.get` is replaced with a fake Brave Search response.

By default pytest does not collect `.hy` files, so `conftest.py` adds a small hook that tells it to collect any file named `test_*.hy`. To add more tests, create another `test_*.hy` file or add `test-` functions to `test_brave.hy`.
