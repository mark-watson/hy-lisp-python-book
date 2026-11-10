# Hy Tooling, Packaging, REPL, and Types

Running a single `.hy` script is easy. Turning that script into an installable library that both Hy and Python projects can import, test with `pytest`, type-check with `mypy`, and test in continuous integration takes a few specific rules. Every example in this book uses `uv`, `pyproject.toml`, and `pytest`, and in this chapter I show you how all of the pieces fit together.

The code for this chapter is in the directory **source_code_for_examples/hy_kg_utils**.

## What You Will Build

We will build and package `hy-kg-utils`, an installable Hy library using the standard `src/` layout. It exports:

1. A typed class `GraphClient` that stores `(subject, predicate, object)` triples in memory and imports or exports tab-separated (TSV) files.
2. A typed function `query->rows` (and its Python alias `query_to_rows`) that queries a `GraphClient` and returns sorted dictionary rows.
3. A hygienic macro `with-graph` that creates a temporary `GraphClient`, optionally loads seed triples, runs a body of forms, and closes the client inside a `finally` block.

Along with the package itself, the project includes a `pytest` suite written in Hy and Python, an interactive `HYSTARTUP` file, a `scripts/typecheck.sh` pipeline that translates `.hy` to `.py` with `hy2py` and runs `mypy --strict`, and a GitHub Actions workflow.

```text
+-----------------------+       hy2py        +-------------------------+
| src/hy_kg_utils/*.hy  | -----------------> | build/typecheck/*.py    |
| (core.hy, macros.hy)  |                    | (checked by mypy)       |
+-----------+-----------+                    +-------------------------+
            |
            | imported via src/hy_kg_utils/__init__.py (starts with `import hy`)
            v
+-----------+-----------+--------------------+-------------------------+
|                       |                    |                         |
v                       v                    v                         v
Hy callers              Python callers       pytest suite              uv build
(import + require)      (import hy_kg_utils) (test_*.hy + test_*.py)   (.whl + .tar.gz)
```

## Why It Matters

Hy compiles directly to Python abstract syntax trees (ASTs), so it shares Python's runtime and package ecosystem. Still, three practical differences trip up developers who package a Hy project for the first time:

- Python's import machinery does not recognize `.hy` files until `import hy` has executed at least once in the process.
- Build backends such as Hatchling or Setuptools may omit `.hy` files from wheels unless you configure package inclusion rules.
- Static type checkers (`mypy`, `pyright`) read Python syntax, not S-expressions, so type-checking Hy requires translating `.hy` modules to Python with `hy2py` first.

Once you solve these three details in a reusable project template, developing a library in Hy is as fast and repeatable as developing one in pure Python.

## The Hy Angle

In Python, resource cleanup requires writing a context manager class with `__enter__` and `__exit__` methods or decorating a generator with `@contextlib.contextmanager`. In Hy, we can ship classes and functions for Python and Hy callers while also exporting compile-time macros like `with-graph` for Hy callers. Better yet, by referencing `hy.I.hy_kg_utils.core.GraphClient` inside the macro expansion, `with-graph` resolves `GraphClient` automatically without forcing the caller to import `GraphClient` into their own namespace.

## Python Equivalent

Here is how a caller uses `hy-kg-utils` in Hy with the `with-graph` macro versus the equivalent code in plain Python:

```hy
;; Hy caller
(require hy_kg_utils [with-graph])
(import hy_kg_utils.core [query->rows])

(setv rows
  (with-graph [g [#("hy" "is-a" "lisp")]]
    (query->rows g :s "hy")))
```

```python
# Python caller
from hy_kg_utils import GraphClient, query_to_rows

g = GraphClient()
try:
    g.add_many([("hy", "is-a", "lisp")])
    rows = query_to_rows(g, s="hy")
finally:
    g.close()
```

Both snippets execute the same underlying bytecode and return the same list of dictionaries.

## Run It

No external services or API keys are required. As of this edition (November 2026), we use `uv` with Python 3.12 through 3.14 and Hy 1.3.1.

Change into **source_code_for_examples/hy_kg_utils**, install the environment, and run the Hy demo, the Python caller script, the test suite, and the type-checking script:

```bash
cd source_code_for_examples/hy_kg_utils
uv sync
uv run hy examples/demo.hy
uv run python examples/python_caller.py
uv run pytest -v
bash scripts/typecheck.sh
```

Here is the actual output from `uv run hy examples/demo.hy`:

```text
=== 1. Using with-graph macro and query->rows from Hy ===
Graph 'default' has 5 triples; predicates: ['builds', 'checks', 'compiles-to', 'is-a', 'supports']
  {'subject': 'hy', 'predicate': 'compiles-to', 'object': 'python-ast'}
  {'subject': 'hy', 'predicate': 'is-a', 'object': 'lisp'}
  {'subject': 'hy', 'predicate': 'supports', 'object': 'macros'}
After with-graph block, g.closed = True

=== 2. Inspecting macro expansion and name mangling ===
mangle('query->rows')  -> hyx_query_XgreaterHthan_signXrows
unmangle(mangled)      -> query->rows
mangle('query-to-rows') -> query_to_rows
macroexpand-1 of (with-graph [g] (.count g)):
'(do (setv g (hy.I.hy_kg_utils.core.GraphClient)) (try (setv _hy_gensym_seed_2 []) (when _hy_gensym_seed_2 (.add-many g (list _hy_gensym_seed_2))) (.count g) (finally (.close g))))
```

Here is the output from `uv run python examples/python_caller.py`:

```text
=== Calling hy_kg_utils from plain Python ===
  hy_kg_utils --[exposes]--> GraphClient
  hy_kg_utils --[exposes]--> query_to_rows
  python --[imports]--> hy_kg_utils
Client closed: True

=== Evaluating a Hy macro from Python via hy.eval ===
  [{'subject': 'hy.eval', 'predicate': 'runs', 'object': 'with-graph'}]
```

Here is the output from `uv run pytest -v`:

```text
============================= test session starts ==============================
platform darwin -- Python 3.14.7, pytest-9.2.0, pluggy-1.7.0
cachedir: .pytest_cache
rootdir: /Users/markw/GITHUB/hy-lisp-python-book/source_code_for_examples/hy_kg_utils
configfile: pyproject.toml
testpaths: tests
collecting ... collected 11 items

tests/test_hy_kg_utils.hy::test_fixture_and_predicates PASSED            [  9%]
tests/test_hy_kg_utils.hy::test_query_to_rows_parametrized[hy-None-None-2] PASSED [ 18%]
tests/test_hy_kg_utils.hy::test_query_to_rows_parametrized[None-is-a-lisp-1] PASSED [ 27%]
tests/test_hy_kg_utils.hy::test_query_to_rows_parametrized[uv-manages-None-1] PASSED [ 36%]
tests/test_hy_kg_utils.hy::test_query_to_rows_parametrized[unknown-None-None-0] PASSED [ 45%]
tests/test_hy_kg_utils.hy::test_raises_on_empty_term_and_closed_client PASSED [ 54%]
tests/test_hy_kg_utils.hy::test_monkeypatch_default_graph_name PASSED    [ 63%]
tests/test_hy_kg_utils.hy::test_tmp_path_tsv_roundtrip PASSED            [ 72%]
tests/test_hy_kg_utils.hy::test_with_graph_macro_closes_on_exit PASSED   [ 81%]
tests/test_python_interop.py::test_python_imports_hy_package PASSED      [ 90%]
tests/test_python_interop.py::test_hy_name_mangling_and_eval PASSED      [100%]

============================== 11 passed in 0.09s ==============================
```

And here is the output from `bash scripts/typecheck.sh`:

```text
=== Translated Python modules in build/typecheck/hy_kg_utils ===
__init__.py
core.py
macros.py
=== Running mypy on translated core.py and __init__.py ===
Success: no issues found in 2 source files
```

## 1. The 10-Minute `uv` Workflow

Throughout this book, every project uses [uv](https://docs.astral.sh/uv/) to manage Python versions, virtual environments, lockfiles, and package builds. As of this edition (November 2026), creating a new Hy project from scratch takes four commands:

```bash
uv init --package my-hy-pkg
cd my-hy-pkg
uv add "hy>=1.3.1"
uv add --dev "pytest>=9.2.0" "mypy>=1.18"
```

Key `uv` commands you will use daily with Hy:

- `uv sync`: Creates `.venv`, resolves dependencies, writes `uv.lock`, and installs the current package in editable mode.
- `uv run hy`: Launches the Hy REPL inside the project environment.
- `uv run hy path/to/script.hy`: Runs a Hy script.
- `uv run pytest`: Runs tests across both `.py` and `.hy` files (once `conftest.py` is present).
- `uv build`: Builds a source distribution (`.tar.gz`) and wheel (`.whl`) in `dist/`.

Committing `uv.lock` to version control ensures that every machine and CI runner installs the exact same versions of `hy`, `funcparserlib`, and test dependencies.

## 2. Project Layout: Scripts vs. Libraries

For a standalone script or demo, placing `.hy` files in the project root next to `pyproject.toml` is fine. For a reusable library, use the `src/` layout:

```text
hy_kg_utils/
├── .github/
│   └── workflows/
│       └── ci.yml
├── conftest.py
├── examples/
│   ├── demo.hy
│   ├── hystartup.hy
│   └── python_caller.py
├── pyproject.toml
├── scripts/
│   └── typecheck.sh
├── src/
│   └── hy_kg_utils/
│       ├── __init__.py
│       ├── core.hy
│       └── macros.hy
└── tests/
    ├── test_hy_kg_utils.hy
    └── test_python_interop.py
```

The `src/` layout prevents `pytest` or Python from accidentally importing un-packaged local files from the working directory instead of the installed package in `.venv`.

Notice that the package entry point is `src/hy_kg_utils/__init__.py`, a `.py` file, not `__init__.hy`. When a Python program runs `import hy_kg_utils`, Python has not necessarily imported `hy` yet. If the package only had `__init__.hy`, Python's default import machinery would ignore it and fail with `ModuleNotFoundError`. Starting `__init__.py` with `import hy` registers Hy's import hook before importing the `.hy` submodules:

```python
"""hy_kg_utils: tiny knowledge-graph helpers written in Hy."""

import hy  # register the .hy import hook before importing Hy modules

from hy_kg_utils.core import GraphClient, MaybeStr, Row, Triple, query_to_rows

hy.macros.require("hy_kg_utils.macros", None, assignments="EXPORTS")

__version__ = "0.1.0"
__all__ = ["GraphClient", "MaybeStr", "Row", "Triple", "query_to_rows", "__version__"]
```

That call to `hy.macros.require("hy_kg_utils.macros", None, assignments="EXPORTS")` attaches the exported macros from `hy_kg_utils.macros` onto the top-level `hy_kg_utils` module as well, so Hy users can write either `(require hy_kg_utils [with-graph])` or `(require hy_kg_utils.macros [with-graph])`.

## 3. Interop Between Hy and Python

Hy and Python share the same runtime objects, classes, and modules. You have four primary interop tools when crossing the boundary:

1. **Importing Python into Hy**: Use `(import pathlib [Path])` or `hy.I` (for example `(hy.I.math.sqrt 16)`). `hy.I` imports on demand without binding a name in the current scope, which makes it ideal inside macros.
2. **Importing Hy into Python**: Import the package after `import hy` (or import a package whose `__init__.py` starts with `import hy`).
3. **Identifier mangling (`hy.mangle` and `hy.unmangle`)**: Hy converts Lisp names into valid Python identifiers. Single dashes become underscores (`add-many` becomes `add_many`), while punctuation characters use a `hyx_` prefix and Unicode character names:

```hy
(hy.mangle "add-many")     ; => "add_many"
(hy.mangle "query->rows")  ; => "hyx_query_XgreaterHthan_signXrows"
(hy.unmangle "hyx_query_XgreaterHthan_signXrows") ; => "query->rows"
```

Because `query->rows` mangles to `hyx_query_XgreaterHthan_signXrows`, we define a friendly alias `(setv query-to-rows query->rows)` in `core.hy` so Python callers can import `query_to_rows`.

4. **Evaluating Hy from Python (`hy.read_many` and `hy.eval`)**: Python code cannot expand a Hy macro directly with Python syntax, but it can parse and evaluate S-expressions at runtime:

```python
import hy

forms = hy.read_many(
    "(do (require hy_kg_utils [with-graph])"
    "    (import hy_kg_utils.core [query->rows])"
    '    (with-graph [g [#("hy.eval" "runs" "with-graph")]]'
    "      (query->rows g)))"
)
result = hy.eval(forms)
```

Similarly, inside Hy, `hy.R` lets you call a macro without importing it at the top of the file: `(hy.R.hy_kg_utils.macros.with-graph [g] (.count g))`.

## 4. Packaging a Hy Library (`pyproject.toml` and Wheels)

Here is `source_code_for_examples/hy_kg_utils/pyproject.toml`:

```toml
[project]
name = "hy-kg-utils"
version = "0.1.0"
description = "Tiny knowledge-graph helpers written in Hy: a function, a class, and a macro, packaged as a wheel."
readme = "README.md"
requires-python = ">=3.12"
license = "Apache-2.0"
authors = [{ name = "Mark Watson" }]
keywords = ["hy", "lisp", "knowledge-graph", "triples"]
classifiers = [
    "Programming Language :: Hy",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.12",
    "Programming Language :: Python :: 3.13",
    "Programming Language :: Python :: 3.14",
    "Topic :: Software Development :: Libraries",
]
dependencies = ["hy>=1.3.1"]

[project.optional-dependencies]
typecheck = ["mypy>=1.18"]

[dependency-groups]
dev = ["pytest>=9.2.0", "mypy>=1.18"]

[build-system]
requires = ["hatchling>=1.27"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/hy_kg_utils"]
# Hatchling only picks up files git would track; be explicit so .hy
# sources always land in the wheel next to __init__.py.
include = ["src/hy_kg_utils/*.py", "src/hy_kg_utils/*.hy"]

[tool.hatch.build.targets.sdist]
include = ["src", "tests", "examples", "scripts", "conftest.py", "README.md"]

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.mypy]
strict = true

[[tool.mypy.overrides]]
module = ["hy", "hy.*"]
ignore_missing_imports = true

[tool.uv]
exclude-newer = "2 days"
```

Pay attention to three packaging details:

1. **Classifier**: Include `"Programming Language :: Hy"` in `classifiers` so PyPI indexes your package under Hy packages.
2. **Explicit `.hy` inclusion**: In `[tool.hatch.build.targets.wheel]`, specify `include = ["src/hy_kg_utils/*.py", "src/hy_kg_utils/*.hy"]`. When a user installs the wheel, Hy compiles the `.hy` files to bytecode on import.
3. **Exporting objects and macros**: In `src/hy_kg_utils/macros.hy`, we use `(export :objects [] :macros [with-graph])` to populate `__all__` and `_hy_export_macros`:

```hy
"Compile-time macros for hy_kg_utils."


(defmacro with-graph [binding #* body]
  "Bind a fresh GraphClient (with optional seed triples) and close it on exit.

  Usage:
    (with-graph [g]
      (.add g \"hy\" \"is-a\" \"lisp\"))

    (with-graph [g [#(\"hy\" \"is-a\" \"lisp\")]]
      (query->rows g :s \"hy\"))"
  (when (or (not (isinstance binding hy.models.Sequence))
            (< (len binding) 1)
            (> (len binding) 2))
    (raise (SyntaxError
             "with-graph expects [client-sym] or [client-sym seed-triples]")))
  (setv client-sym (get binding 0))
  (setv seed-expr (if (= (len binding) 2) (get binding 1) '[]))
  (setv seed-var (hy.gensym "seed"))
  `(do
     (setv ~client-sym (hy.I.hy_kg_utils.core.GraphClient))
     (try
       (setv ~seed-var ~seed-expr)
       (when ~seed-var
         (.add-many ~client-sym (list ~seed-var)))
       ~@body
       (finally
         (.close ~client-sym)))))


(export
  :objects []
  :macros [with-graph])
```

Notice how `with-graph` uses `(hy.gensym "seed")` so `seed-expr` is evaluated at most once without risking variable capture in the caller's `body`.

### Building and Verifying the Wheel in a Clean Environment

Let's build the wheel with `uv build`, inspect its contents, and install it into an isolated temporary virtual environment to verify that all `.hy` files were packaged properly:

```bash
uv build
unzip -l dist/hy_kg_utils-0.1.0-py3-none-any.whl
```

Output:

```text
Building source distribution...
Building wheel from source distribution...
Successfully built dist/hy_kg_utils-0.1.0.tar.gz
Successfully built dist/hy_kg_utils-0.1.0-py3-none-any.whl
Archive:  dist/hy_kg_utils-0.1.0-py3-none-any.whl
  Length      Date    Time    Name
---------  ---------- -----   ----
      394  02-02-2020 00:00   hy_kg_utils/__init__.py
     3997  02-02-2020 00:00   hy_kg_utils/core.hy
      976  02-02-2020 00:00   hy_kg_utils/macros.hy
     3244  02-02-2020 00:00   hy_kg_utils-0.1.0.dist-info/METADATA
       87  02-02-2020 00:00   hy_kg_utils-0.1.0.dist-info/WHEEL
      450  02-02-2020 00:00   hy_kg_utils-0.1.0.dist-info/RECORD
---------                     -------
     9148                     6 files
```

Now create a fresh virtual environment outside the repository, install the wheel, and test both `hy -c` and `python -c`:

```bash
uv venv /tmp/hy_wheel_check
uv pip install --python /tmp/hy_wheel_check/bin/python dist/hy_kg_utils-0.1.0-py3-none-any.whl
/tmp/hy_wheel_check/bin/hy -c '(require hy_kg_utils [with-graph]) (import hy_kg_utils.core [query->rows]) (print (with-graph [g [#("wheel" "works-in" "hy")]] (query->rows g)))'
/tmp/hy_wheel_check/bin/python -c 'from hy_kg_utils import GraphClient, query_to_rows; g = GraphClient("wheel-check"); g.add("wheel", "works-in", "python"); print(query_to_rows(g)); g.close()'
rm -rf /tmp/hy_wheel_check dist
```

Output:

```text
[{'subject': 'wheel', 'predicate': 'works-in', 'object': 'hy'}]
[{'subject': 'wheel', 'predicate': 'works-in', 'object': 'python'}]
```

## 5. Testing Hy Packages with `pytest`

By default, `pytest` only looks for `test_*.py` and `*_test.py` files. A six-line `conftest.py` at the project root teaches `pytest` to collect `test_*.hy` files as standard Python test modules:

```python
import hy  # noqa: F401  -- enables importing .hy modules
import pytest


def pytest_collect_file(file_path, parent):
    """Let pytest collect Hy test files named test_*.hy."""
    if file_path.suffix == ".hy" and file_path.name.startswith("test_"):
        return pytest.Module.from_parent(parent, path=file_path)
```

Because Hy functions compile to regular Python function objects and Hy decorators (`(defn [decorator] name [args] ...)`) attach standard attributes, every `pytest` feature works in Hy: fixtures with `yield`, `@(pytest.mark.parametrize ...)`, `(pytest.raises ...)`, `monkeypatch`, and `tmp_path` (which Hy's mangler matches to the parameter `tmp-path`!).

Here is `tests/test_hy_kg_utils.hy`:

```hy
"Pytest suite written in Hy covering fixtures, parametrize, raises, monkeypatch, tmp_path, and macros."

(import pytest)
(import hy_kg_utils [GraphClient])
(import hy_kg_utils.core [query->rows])
(require hy_kg_utils.macros [with-graph])


(defn [(pytest.fixture)] seeded-client []
  "Provide a GraphClient preloaded with four sample triples."
  (setv client (GraphClient :name "fixture-graph"))
  (.add-many client
    [#("hy" "compiles-to" "python-ast")
     #("hy" "is-a" "lisp")
     #("uv" "manages" "packages")
     #("mypy" "checks" "types")])
  (yield client)
  (.close client))


(defn test-fixture-and-predicates [seeded-client]
  (assert (= (.count seeded-client) 4))
  (assert (= (.predicates seeded-client)
             ["checks" "compiles-to" "is-a" "manages"]))
  (assert (= (.add seeded-client "hy" "is-a" "lisp") False)))


(defn [(pytest.mark.parametrize
         "s,p,o,expected_count"
         [#("hy" None None 2)
          #(None "is-a" "lisp" 1)
          #("uv" "manages" None 1)
          #("unknown" None None 0)])]
  test-query-to-rows-parametrized [seeded-client s p o expected-count]
  (setv rows (query->rows seeded-client :s s :p p :o o))
  (assert (= (len rows) expected-count))
  (when (> expected-count 0)
    (assert (= (set (.keys (get rows 0)))
               #{"subject" "predicate" "object"}))))


(defn test-raises-on-empty-term-and-closed-client []
  (setv client (GraphClient))
  (with [(pytest.raises ValueError :match "subject must be a non-empty string")]
    (.add client "   " "is-a" "lisp"))
  (.close client)
  (with [(pytest.raises RuntimeError :match "is closed")]
    (.add client "hy" "is-a" "lisp"))
  (with [(pytest.raises RuntimeError :match "is closed")]
    (query->rows client)))


(defn test-monkeypatch-default-graph-name [monkeypatch]
  (.setenv monkeypatch "HY_KG_DEFAULT_GRAPH" "patched-kg")
  (setv client (GraphClient))
  (assert (= client.name "patched-kg")))


(defn test-tmp-path-tsv-roundtrip [seeded-client tmp-path]
  (setv tsv-file (/ tmp-path "graph.tsv"))
  (setv written (.save-tsv seeded-client tsv-file))
  (assert (= written 4))
  (assert (.exists tsv-file))

  (setv fresh (GraphClient :name "reloaded"))
  (setv loaded (.load-tsv fresh tsv-file))
  (assert (= loaded 4))
  (assert (= (query->rows fresh :s "hy")
             (query->rows seeded-client :s "hy")))

  (setv bad-file (/ tmp-path "bad.tsv"))
  (.write-text bad-file "only-two\tcolumns\n" :encoding "utf-8")
  (with [(pytest.raises ValueError :match "Expected 3 tab-separated columns")]
    (.load-tsv fresh bad-file)))


(defn test-with-graph-macro-closes-on-exit []
  (setv rows
    (with-graph [g [#("hy" "supports" "macros")
                    #("hy" "targets" "python")]]
      (.add g "pytest" "runs" "hy-tests")
      (query->rows g :s "hy")))
  (assert (= (len rows) 2))
  (assert (= (get (get rows 0) "predicate") "supports"))
  (assert (= g.closed True))

  (setv expanded (hy.repr (hy.macroexpand-1 '(with-graph [g] (.count g)))))
  (assert (in "GraphClient" expanded))
  (assert (in "finally" expanded)))
```

Notice how `(defn [(pytest.fixture)] seeded-client [] ...)` defines `seeded_client`, and any test function declaring `[seeded-client]` receives that fixture automatically.

## 6. Interactive REPL Workflow (`HYSTARTUP`, `--spy`, and `hy2py`)

A fast REPL loop is one of the best reasons to write Hy. Three tools make the Hy REPL far more informative than a default session:

### `HYSTARTUP`

When the environment variable `HYSTARTUP` points to a `.hy` file, Hy executes that file before showing the first prompt. Here is `examples/hystartup.hy`:

```hy
"Example HYSTARTUP file for interactive Hy REPL sessions.

Launch a REPL with this file:
  HYSTARTUP=examples/hystartup.hy uv run hy
"

(import importlib [reload])
(import pprint [pprint])
(import hy_kg_utils [GraphClient])
(import hy_kg_utils.core [query->rows])
(require hy_kg_utils [with-graph])

(setv repl-output-fn hy.repr)


(defn expand [form]
  "Pretty-print one step of macroexpansion for a quoted form."
  (print (hy.repr (hy.macroexpand-1 form))))


(print "Loaded examples/hystartup.hy: GraphClient, query->rows, with-graph, reload, expand ready.")
```

Setting `(setv repl-output-fn hy.repr)` tells the REPL to print results using Hy syntax (`#[...]`, `#(...)`, `:keywords`) instead of Python's `repr`.

### `hy --spy`

Launching the REPL with `uv run hy --spy` prints the exact Python code generated for every S-expression before executing it:

```text
$ HYSTARTUP=examples/hystartup.hy uv run hy --spy
Loaded examples/hystartup.hy: GraphClient, query->rows, with-graph, expand ready.
=> (with-graph [g [#("hy" "is-a" "lisp")]] (.count g))
g = hy.I.hy_kg_utils.core.GraphClient()
try:
    _hy_gensym_seed_1 = [('hy', 'is-a', 'lisp')]
    if _hy_gensym_seed_1:
        g.add_many(list(_hy_gensym_seed_1))
        _hy_anon_var_1 = None
    else:
        _hy_anon_var_1 = None
    _hy_anon_var_2 = g.count()
finally:
    g.close()
_hy_anon_var_2
1
```

Whenever you wonder how a Hy comprehension, pattern match, or macro compiles to Python, `--spy` gives you the answer immediately. For an entire file, run `uv run hy2py path/to/file.hy`.

## 7. Debugging with `breakpoint`, `pdb`, and Name-Mangling Surprises

Because Hy compiles to Python AST nodes with line numbers attached, Python tracebacks and `pdb` point directly to your `.hy` source file and line number. You can drop into the debugger anywhere in a `.hy` file by calling `(breakpoint)`:

```hy
(defn debug-query [client subject]
  (breakpoint)
  (query->rows client :s subject))
```

Inside `pdb`, keep two name-mangling rules in mind when inspecting variables:

1. **Dashes become underscores**: If your Hy code binds `(setv raw-line "a\tb\tc")`, in `pdb` you inspect `p raw_line`, not `raw-line` (which Python parses as subtraction: `raw - line`).
2. **Special characters use `hyx_` and `X...X`**: A function named `query->rows` is stored in the module dictionary as `hyx_query_XgreaterHthan_signXrows`, and a predicate named `empty?` becomes `hyx_emptyXquestion_markX`. If you need to look up a symbol dynamically in `pdb`, call `hy.mangle("query->rows")` or inspect `[hy.unmangle(k) for k in dir(mod)]`.

## 8. Static Type Checking with `#^`, `deftype`, `hy2py`, and `mypy`

Hy supports Python's full type annotation model through the `#^` reader macro and `deftype` (which emits Python 3.12+ `type Name = ...` statements). Here is the complete `src/hy_kg_utils/core.hy`:

```hy
"Core runtime classes and functions for hy_kg_utils."

(import os)
(import pathlib [Path])

(deftype Triple (get tuple #(str str str)))
(deftype Row (get dict #(str str)))
(deftype MaybeStr (| str None))


(defn #^ str _clean-term [#^ str value #^ str field-name]
  "Strip whitespace and reject empty triple terms."
  (setv cleaned (.strip value))
  (when (= cleaned "")
    (raise (ValueError f"{field-name} must be a non-empty string")))
  cleaned)


(defclass GraphClient []
  "A small in-memory triple store with TSV import/export."

  (defn #^ None __init__ [self #^ MaybeStr [name None]]
    (setv default-name (os.environ.get "HY_KG_DEFAULT_GRAPH" "default"))
    (setv #^ str self.name (if (is name None) default-name name))
    (setv #^ (get list Triple) self._triples [])
    (setv #^ bool self.closed False))

  (defn #^ None _check-open [self]
    (when self.closed
      (raise (RuntimeError f"GraphClient '{self.name}' is closed"))))

  (defn #^ bool add [self #^ str s #^ str p #^ str o]
    "Add (s, p, o) if not already present. Return True when added."
    (._check-open self)
    (setv triple #((_clean-term s "subject")
                   (_clean-term p "predicate")
                   (_clean-term o "object")))
    (if (in triple self._triples)
        False
        (do
          (.append self._triples triple)
          True)))

  (defn #^ int add-many [self #^ (get list Triple) triples]
    "Add multiple triples and return the number of newly inserted triples."
    (._check-open self)
    (setv added 0)
    (for [[s p o] triples]
      (when (.add self s p o)
        (+= added 1)))
    added)

  (defn #^ int count [self]
    "Return the total number of stored triples."
    (len self._triples))

  (defn #^ (get list Triple) match [self
                                    #^ MaybeStr [s None]
                                    #^ MaybeStr [p None]
                                    #^ MaybeStr [o None]]
    "Return all triples matching the non-None subject, predicate, and object filters."
    (._check-open self)
    (lfor [ts tp to] self._triples
          :if (and (or (is s None) (= ts s))
                   (or (is p None) (= tp p))
                   (or (is o None) (= to o)))
          #(ts tp to)))

  (defn #^ (get list str) predicates [self]
    "Return sorted distinct predicate names."
    (._check-open self)
    (sorted (sfor [_ tp _] self._triples tp)))

  (defn #^ int save-tsv [self #^ Path path]
    "Write triples to a tab-separated file and return the row count."
    (._check-open self)
    (setv lines (lfor [s p o] self._triples f"{s}\t{p}\t{o}\n"))
    (.write-text (Path path) (.join "" lines) :encoding "utf-8")
    (len lines))

  (defn #^ int load-tsv [self #^ Path path]
    "Load triples from a tab-separated file and return the count of new triples."
    (._check-open self)
    (setv text (.read-text (Path path) :encoding "utf-8"))
    (setv added 0)
    (for [raw-line (.splitlines text)]
      (setv line (.strip raw-line))
      (when (and line (not (.startswith line "#")))
        (setv parts (.split line "\t"))
        (when (!= (len parts) 3)
          (raise (ValueError f"Expected 3 tab-separated columns, got: {raw-line}")))
        (when (.add self (get parts 0) (get parts 1) (get parts 2))
          (+= added 1))))
    added)

  (defn #^ None close [self]
    "Mark the client closed."
    (setv self.closed True)))


(defn #^ (get list Row) query->rows [#^ GraphClient client
                                     #^ MaybeStr [s None]
                                     #^ MaybeStr [p None]
                                     #^ MaybeStr [o None]]
  "Query client and return sorted dictionary rows with subject/predicate/object keys."
  (setv matches (sorted (.match client :s s :p p :o o)))
  (lfor [ts tp to] matches
        {"subject" ts
         "predicate" tp
         "object" to}))


(setv query-to-rows query->rows)


(export
  :objects [Triple Row MaybeStr GraphClient query->rows query-to-rows])
```

Two syntax rules in `core.hy` are worth memorizing:

1. **Generic subscripting uses `(get ...)`**: In Python, generic types use square brackets (`list[Triple]`, `tuple[str, str, str]`, `dict[str, str]`). In Hy, `(list Triple)` is a function call `list(Triple)`, which `mypy` rejects as an invalid type annotation. Always write `(get list Triple)` for single-argument generics and `(get tuple #(str str str))` for multi-argument generics.
2. **Annotating parameters with default values**: Place `#^ Type` *outside* the `[param default]` bracket: write `#^ MaybeStr [s None]`, not `[#^ MaybeStr s None]`.

When we run `uv run hy2py src/hy_kg_utils/core.hy`, Hy emits standard annotated Python:

```python
type Triple = tuple[str, str, str]
type Row = dict[str, str]
type MaybeStr = str | None

def _clean_term(value: str, field_name: str) -> str:
    """Strip whitespace and reject empty triple terms."""
    cleaned = value.strip()
    if cleaned == '':
        raise ValueError(f'{field_name} must be a non-empty string')
        _hy_anon_1 = None
    else:
        _hy_anon_1 = None
    return cleaned
```

Our `scripts/typecheck.sh` script translates the `.hy` modules into a temporary build directory and runs `mypy` with `strict = true`:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="build/typecheck"
PKG_OUT="${BUILD_DIR}/hy_kg_utils"

rm -rf "${BUILD_DIR}"
mkdir -p "${PKG_OUT}"

cp src/hy_kg_utils/__init__.py "${PKG_OUT}/__init__.py"
uv run hy2py src/hy_kg_utils/macros.hy > "${PKG_OUT}/macros.py"
uv run hy2py src/hy_kg_utils/core.hy > "${PKG_OUT}/core.py"

echo "=== Translated Python modules in ${PKG_OUT} ==="
ls -1 "${PKG_OUT}"

echo "=== Running mypy on translated core.py and __init__.py ==="
MYPYPATH="${BUILD_DIR}" uv run mypy --config-file pyproject.toml "${PKG_OUT}/core.py" "${PKG_OUT}/__init__.py"

rm -rf build .mypy_cache
```

Notice that `scripts/typecheck.sh` translates `macros.hy` so imports resolve, and runs `mypy --strict` on `core.py` and `__init__.py`. Because `defmacro` expands into an untyped compiler helper function that returns `hy.models.Expression` trees, keeping compile-time macros in `macros.hy` and typed runtime code in `core.hy` gives you strict type checking on all runtime APIs without fighting macro expansion internals.

## 9. Editor and LSP Options

As of this edition (November 2026), three community tools provide syntax highlighting, structural editing, and language-server completions for Hy:

- **Hyuga (`hyuga`)**: A Language Server Protocol (LSP) server for Hy (`uv tool install hyuga`). It provides autocomplete, hover docstrings, and jump-to-definition for both Python imports and Hy forms across VS Code, Emacs (`eglot` or `lsp-mode`), and Neovim.
- **tree-sitter-hy**: A Tree-sitter grammar for Hy that powers accurate highlighting and structural selection in Neovim (`nvim-treesitter`), Helix, and Zed.
- **Emacs `hy-mode` + `paredit` / `smartparens`**: Remains a favorite for Lisp programmers who want slurp/barf S-expression editing and `inferior-lisp` REPL evaluation (`C-c C-z`).

## 10. Formatting and Linting

Never run Python formatters such as `ruff format` or `black` directly on `.hy` files; they expect Python syntax and will fail with parse errors. Instead, as of this edition (November 2026):

- Use **Beautifhy** (`beautifhy`) to format `.hy` files according to Lisp indentation conventions (2-space indent inside `defn`, `defclass`, `with`, `let`, and aligned bindings).
- If you want static lint checks for unused imports or unreachable branches, run `hy2py` into `build/typecheck` (just as `scripts/typecheck.sh` does) and run `ruff check` on the generated `.py` files, ignoring Hy's synthetic `_hy_anon_*` variables.

## 11. Continuous Integration and Release Checklist

The example directory includes a ready-to-use GitHub Actions workflow at `source_code_for_examples/hy_kg_utils/.github/workflows/ci.yml` that tests the package across Python 3.12, 3.13, and 3.14, runs the `hy2py` + `mypy` check, and verifies that `uv build` succeeds:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        python-version: ["3.12", "3.13", "3.14"]

    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v6

      - name: Set up Python ${{ matrix.python-version }}
        run: uv python install ${{ matrix.python-version }}

      - name: Sync dependencies
        run: uv sync --python ${{ matrix.python-version }}

      - name: Run pytest suite (Hy and Python tests)
        run: uv run pytest -v

      - name: Run hy2py + mypy typecheck
        run: bash scripts/typecheck.sh

      - name: Build wheel and sdist
        run: uv build
```

When you are ready to publish a release to PyPI:

1. Bump `version` in `pyproject.toml` and `__version__` in `src/<pkg>/__init__.py`.
2. Run `uv sync`, `uv run pytest`, and `bash scripts/typecheck.sh`.
3. Build artifacts with `uv build` and inspect the wheel with `unzip -l dist/*.whl` to confirm all `.hy` files are present.
4. Publish with `uv publish` (using PyPI Trusted Publishing in GitHub Actions or an API token).

## 12. Migration Tools: `hy2py` and `py2hy`

Two translation utilities help when migrating code between Python and Hy (as of this edition, November 2026):

- **`hy2py`** ships with Hy itself (`uv run hy2py file.hy`). Because it runs Hy's own reader, macroexpander, and AST compiler and then unparses the resulting Python AST, `hy2py` is always 100% faithful to the installed Hy version. If you ever need to hand a Hy prototype to a team that only maintains Python, `hy2py` gives you working Python code in one step.
- **`py2hy`** (maintained in the `hylang/py2hy` repository) translates Python source code into Hy S-expressions by walking Python's `ast` module. It is a great starting point when porting an existing Python module to Hy: run `py2hy` to get the mechanical translation, and then refactor verbose Python idioms into idiomatic `lfor`, `match`, or macros.

## Wrap Up

In this chapter we took a Hy codebase from a standalone script to an installable, type-checked, and tested package (`hy-kg-utils`). By starting `__init__.py` with `import hy`, including `*.hy` in the wheel build configuration, separating compile-time macros from typed runtime modules, and wiring `hy2py` into `mypy` and `pytest`, your Hy libraries become first-class citizens of both the Hy and Python ecosystems.

## Exercises

1. **Small exercise (Predicate filter macro)**: Add a macro `(with-predicates [var client] #* body)` to `src/hy_kg_utils/macros.hy` that binds `var` to `(.predicates client)` and executes `body` only when the graph has at least one predicate. Export it and write a test for it in `tests/test_hy_kg_utils.hy`.
2. **Open-ended exercise (CLI entry point and JSONL export)**: Add a `src/hy_kg_utils/cli.hy` module with a `main` function that reads a TSV file of triples, runs a subject/predicate/object filter from `argparse`, and prints matching rows as JSON Lines. Expose it under `[project.scripts]` in `pyproject.toml` (via a wrapper function in `__init__.py`), rebuild the wheel, and verify the installed CLI command in a fresh virtual environment.

## Further Reading

- [Hy 1.3.1 Interop and Packaging Manual](https://hylang.org/hy/doc/v1.3.1/interop)
- [Hy 1.3.1 Command-Line Interface Manual (`hy`, `hy2py`, `hyc`)](https://hylang.org/hy/doc/v1.3.1/cli)
- [uv Documentation: Building and Publishing Packages](https://docs.astral.sh/uv/guides/package/)
- Claudio Jolowicz, *Hypermodern Python Tooling* (O'Reilly, 2024)
