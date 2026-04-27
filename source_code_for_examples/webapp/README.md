# Writing Web Applications

**Book Chapter:** [Writing Web Applications](https://leanpub.com/read/hy-lisp-python/leanpub-auto-writing-web-applications) — *A Lisp Programmer Living in Python-Land* (free to read online).

This directory contains three progressively richer [Flask](https://flask.palletsprojects.com/) web application examples written in Hy:

- **`flask_test.hy`** — minimal "Hello World" Flask app.
- **`jinja2_test.hy`** — adds Jinja2 HTML templates and a form that accepts user input.
- **`cookie_test.hy`** — extends the Jinja2 example with cookie handling.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager

## Running the Examples

```bash
uv sync

# Start any of the three servers (each runs on http://127.0.0.1:5000):
uv run hy flask_test.hy
uv run hy jinja2_test.hy
uv run hy cookie_test.hy
```

Open `http://127.0.0.1:5000` in your browser after starting a server.
