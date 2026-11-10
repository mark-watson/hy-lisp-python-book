# hy-kg-utils

An installable Hy library package (`src/` layout) for the chapter **Hy Tooling, Packaging, REPL, and Types**. It packages:

- A typed class `GraphClient` (`src/hy_kg_utils/core.hy`)
- A typed function `query->rows` (`query_to_rows` when imported from Python)
- A hygienic macro `with-graph` (`src/hy_kg_utils/macros.hy`) exported for `(require ...)`
- A Python package entry point (`src/hy_kg_utils/__init__.py`) that starts with `import hy` so both Hy and Python callers can import `hy_kg_utils`

## Project Layout

```text
hy_kg_utils/
├── .github/
│   └── workflows/
│       └── ci.yml               # GitHub Actions matrix (Python 3.12-3.14)
├── conftest.py                  # Pytest hook to collect test_*.hy files
├── examples/
│   ├── demo.hy                  # Hy caller using GraphClient, query->rows, with-graph
│   ├── hystartup.hy             # Example HYSTARTUP file for interactive REPL work
│   └── python_caller.py         # Plain Python script importing hy_kg_utils
├── pyproject.toml               # Hatchling wheel config including *.hy + classifiers
├── scripts/
│   └── typecheck.sh             # Translates .hy -> .py with hy2py and runs mypy --strict
├── src/
│   └── hy_kg_utils/
│       ├── __init__.py          # Starts with `import hy` and re-exports public API
│       ├── core.hy              # GraphClient, query->rows, and type aliases
│       └── macros.hy            # with-graph macro and export table
└── tests/
    ├── test_hy_kg_utils.hy      # Hy pytest suite (fixtures, parametrize, raises, monkeypatch, tmp_path)
    └── test_python_interop.py   # Python pytest suite verifying Python -> Hy interop
```

## Prerequisites

- Python 3.12+
- [uv](https://docs.astral.sh/uv/)

## Quick Start

Install dependencies and the editable package:

```bash
uv sync
```

Run the Hy demo and the Python interop demo:

```bash
uv run hy examples/demo.hy
uv run python examples/python_caller.py
```

Launch a REPL with the custom `HYSTARTUP` file and `--spy` mode:

```bash
HYSTARTUP=examples/hystartup.hy uv run hy --spy
```

## Testing and Type Checking

Run the pytest suite (collects both `test_*.hy` and `test_*.py`):

```bash
uv run pytest -v
```

Translate `.hy` sources with `hy2py` and run `mypy --strict`:

```bash
bash scripts/typecheck.sh
```

## Building and Verifying the Wheel

Build the wheel and source distribution:

```bash
uv build
```
