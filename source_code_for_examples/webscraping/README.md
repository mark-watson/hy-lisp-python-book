# Responsible Web Scraping

**Book Chapter:** [Responsible Web Scraping](https://leanpub.com/read/hy-lisp-python/leanpub-auto-responsible-web-scraping) — *A Lisp Programmer Living in Python-Land* (free to read online).

This directory contains web scraping examples using [BeautifulSoup](https://www.crummy.com/software/BeautifulSoup/) from Hy:

- **`get_web_page.hy`** — utility module for fetching raw HTML from a URL or from a local file.
- **`get_page_data.hy`** — parses a live web page and extracts structured element data (text, tag name, class, href).
- **`democracynow_front_page.hy`** — extracts article links from a cached Democracy Now front page.
- **`npr_front_page_summary.hy`** — extracts and summarizes headline links from a cached NPR front page.

The cached-page examples require running `make data` first to download sample HTML files for offline development and testing.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager

## Running the Examples

```bash
uv sync

# Live scraping example
uv run hy get_page_data.hy

# Cached page examples (download sample HTML first)
make data
uv run hy democracynow_front_page.hy
uv run hy npr_front_page_summary.hy
```
