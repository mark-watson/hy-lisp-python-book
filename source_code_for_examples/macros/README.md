# Macros and Metaprogramming in Hy

Runnable examples for the chapter *Macros and Metaprogramming: The Lisp Advantage*. The code covers ordinary macros (`defmacro`), quasiquotation, macro expansion and Python AST inspection, macro hygiene (`hy.gensym`, `def-gensyms`, `defmacro!`), reader macros (`defreader`), and a compile-time HTML and SVG DSL.

## Project Structure

```text
macros/
├── core_macros.hy    # unless, do-while, swap!, when-let, with-timer, timed, mini-match
├── hygiene.hy        # Broken vs hygienic macros (gensyms, def-gensyms, defmacro!, aif)
├── reader_macros.hy  # Reader macros: #env, #sql (with SQLite runner), and #json
├── html_dsl.hy       # Compile-time HTML and SVG DSL with static string folding
├── demo.hy           # Guided tour script that prints macro expansions and outputs
├── test_macros.hy    # Pytest suite for core macros, hygiene, namespaces, and readers
├── test_html_dsl.hy  # Pytest suite for the HTML and SVG DSL
├── conftest.py       # Pytest hook to collect test_*.hy files
└── pyproject.toml    # Dependencies: hy>=1.3.1, hyrule>=1.0.0, pytest>=9.2.0
```

## Prerequisites

- Python 3.12 or newer
- [uv](https://docs.astral.sh/uv/)

## Run the Demo

```bash
uv sync
uv run hy demo.hy
```

## Run the Test Suite

```bash
uv run pytest -q
```
