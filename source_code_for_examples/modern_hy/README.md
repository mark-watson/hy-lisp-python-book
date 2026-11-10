# Modern Hy 1.3 and Python 3.12–3.15

Companion examples for the "Modern Hy and Python 3.14/3.15" section in `manuscript/hytutorial.md`.

## Files

- `modern_features.hy` — chained `setv`, `setx`, `let` + `nonlocal`, PEP 695 `deftype`, `#^` type annotations, structural `match`/`case` over dataclasses and `hy.models`, bracket strings, PEP 750 t-strings (on Python 3.14+), and PEP 798 unpacking in comprehensions (`#*` inside `lfor`).
- `umls_modern.hy` — a modernized, typed refactor of the triple parser and summarizer from `plots_with_graphviz/UMLS_graph.hy`.
- `demo.hy` — runs the tour and prints output.
- `test_modern_hy.hy` — pytest suite including a `hy2py` translation check.

## Running

```bash
uv sync
uv run hy demo.hy
uv run pytest
uv run hy2py umls_modern.hy > /tmp/umls_modern.py
uv run mypy /tmp/umls_modern.py
```
