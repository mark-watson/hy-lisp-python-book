# Macros and Metaprogramming: The Lisp Advantage

Most chapters in this book use Hy to call Python libraries with Lisp syntax. That is pleasant and productive, yet it leaves out the deepest reason to choose a Lisp. In Python, the language designers decide what control structures, binding forms, and literal notations exist. In Hy, you can add new syntax yourself and compile it down to standard Python abstract syntax trees (ASTs) before the program runs.

The code for this chapter is in the directory **source_code_for_examples/macros**.

## What You Will Build

In this chapter we build four modules and a test suite that cover the full range of Hy metaprogramming:

1. **Core control and timing macros (`core_macros.hy`)**: `unless`, `do-while`, `swap!`, `when-let`, `with-timer`, `timed`, and `mini-match`, plus helpers that expand macros and translate Hy forms into Python source code.
2. **Macro hygiene examples (`hygiene.hy`)**: side-by-side broken and hygienic macros showing multiple evaluation and accidental variable capture, fixed with `hy.gensym`, `def-gensyms`, and `defmacro!`, plus an intentional anaphoric macro (`aif`).
3. **Reader macros (`reader_macros.hy`)**: `#env` for environment lookups, `#json` for compile-time JSON validation and literal emission, and `#sql` for compile-time SQL normalization and placeholder checking backed by SQLite.
4. **A compile-time HTML and SVG DSL (`html_dsl.hy`)**: `html` and `svg` macros that fold static tags, attributes, and text into string constants at compile time while escaping dynamic values at run time.

We also examine the `ask` and `rule` macros from the NSK knowledge graph engine in **source_code_for_examples/nsk-neural-symbolic-graph** to see how a domain-specific query language works in a larger system.

```text
Source text (.hy)
       |
       |  1. Hy Reader (hy.read / defreader)
       v
  Hy Models (Expression, Symbol, Keyword, List, Dict, String, ...)
       |
       |  2. Macro Expansion (defmacro / hy.macroexpand)
       v
Expanded Hy Models
       |
       |  3. Hy Compiler (hy.compiler.hy-compile)
       v
Python AST (ast.Module / ast.expr / ast.stmt)
       |
       |  4. Python Bytecode Compiler + VM
       v
Running Program
```

## Why It Matters

Functions operate on values at run time. Before a Python or Hy function starts executing, Python evaluates every argument expression from left to right. Because of that strict evaluation rule, a regular function cannot:

- Delay or skip evaluating an argument (as `if`, `when`, and `unless` must do).
- Evaluate an argument repeatedly in a loop (as `while` and `do-while` must do).
- Bind a new local variable in the caller's scope (as `setv`, `for`, and `when-let` must do).
- Inspect the symbolic structure of an expression before it turns into a value (as `swap!`, `ask`, and `html` must do).

Macros run at **compile time** (Step 2 in the pipeline above). A macro is a regular Hy function whose arguments are unevaluated **Hy models** representing source code, and whose return value is a new Hy model that replaces the macro call. By the time Python executes the compiled bytecode, the macro call is gone; only the expanded Python AST remains.

## The Hy Angle and the Python Equivalent

Suppose we want `swap!`, which exchanges two assignable targets such as local variables or list elements:

```hy
(swap! left right)
(swap! (get items 0) (get items 1))
```

In Python, you cannot write a function `swap(a, b)` that swaps two caller variables in place, because Python passes object references by value. Rebinding `a` and `b` inside `swap` only mutates the function's local frame. A Python programmer writes tuple unpacking at every call site (`left, right = right, left`), or for timing blocks writes a context manager class or a decorator:

```python
# Python context manager for timing a block
from contextlib import contextmanager
import time

@contextmanager
def with_timer(label: str):
    start = time.perf_counter()
    try:
        yield
    finally:
        print(f"{label} took {time.perf_counter() - start:.4f} s")
```

Python's `with` statement works well when you do not need the block's return value as an expression. In Hy, a `with-timer` macro wraps any sequence of expressions, prints the elapsed time in a `finally` clause, and returns the value of the body directly:

```hy
(setv total (with-timer "sum-squares"
              (sum (gfor x (range 10000) (* x x)))))
```

Even better, when we build the HTML DSL in `html_dsl.hy`, the `html` macro folds static tags and attributes into a single string literal at compile time. A Python template library must parse templates or concatenate tag strings at run time unless it adds a separate code-generation build step.

## Run It

The project directory layout is:

```text
macros/
├── core_macros.hy    # unless, do-while, swap!, when-let, with-timer, timed, mini-match
├── hygiene.hy        # Broken vs hygienic macros (gensym, def-gensyms, defmacro!, aif)
├── reader_macros.hy  # Reader macros: #env, #sql (with SQLite runner), and #json
├── html_dsl.hy       # Compile-time HTML and SVG DSL with static string folding
├── demo.hy           # Guided tour script that prints macro expansions and outputs
├── test_macros.hy    # Pytest suite for core macros, hygiene, namespaces, and readers
├── test_html_dsl.hy  # Pytest suite for the HTML and SVG DSL
├── conftest.py       # Pytest hook to collect test_*.hy files
└── pyproject.toml    # Dependencies: hy>=1.3.1, hyrule>=1.0.0, pytest>=9.2.0
```

Sync the environment, run the guided tour, and run the test suite:

```bash
cd source_code_for_examples/macros
uv sync
uv run hy demo.hy
uv run pytest -q
```

Running `uv run hy demo.hy` produces this output:

```text
=== 1. Core Macros and Expansion ===
unless result: ['initialized']
do-while steps: [0, 1, 2]
after swap!: omega alpha
when-let found version: 1.3.1
HTTP 200 -> OK
HTTP 404 -> Not Found
HTTP 503 -> Server Error

Macroexpansion of (unless ready (boot)):
  '(when (not ready) (boot))
Python AST via form-to-python:
  [a, b] = [b, a]

=== 2. Hygiene: Multiple Evaluation and Capture ===
square-bad(bump):  result=16, calls=2 (evaluated twice!)
square-good(bump): result=16, calls=1
square-o!(bump):   result=16, calls=1
sum-steps-bad  with outer step=10: 3 (captured 'step'!)
sum-steps-good with outer step=10: 30 (outer step preserved)
anaphoric aif: Hello, Mark!

=== 3. Reader Macros (#env, #json, #sql) ===
#env DEMO_ENV_NAME: hy-macros
#env with default:  fallback-value
#json parsed at read time: {'name': 'hy', 'release': 1.3, 'lisp': True}
Compiled SqlQuery: SqlQuery(sql='SELECT name, year FROM languages WHERE lisp = 1 AND year >= ? ORDER BY year', params=(2000,))
Query results: [{'name': 'Clojure', 'year': 2007}, {'name': 'Hy', 'year': 2013}]

=== 4. Compile-Time HTML and SVG DSL ===
Rendered HTML (with automatic escaping):
<div class="card" data-kind="demo"><h2>Topic Summary</h2><p>Viewer: &lt;script&gt;alert(1)&lt;/script&gt;</p><ul><li>Macros</li><li>Reader Macros</li><li>DSLs</li></ul><hr></div>

Macroexpansion of static + dynamic HTML:
  '(hy.I.html_dsl.RawHtml (.join "" ["<div class=\"box\"><h1>Title</h1><p>" (hy.I.html_dsl.render-child user) "</p></div>"]))

Rendered SVG:
<svg xmlns="http://www.w3.org/2000/svg" width="140" height="40" viewBox="0 0 140 40"><rect x="2" y="2" width="136" height="36" rx="6" fill="#eef"></rect><text x="70" y="25" text-anchor="middle">Hy 1.3.1</text></svg>
```

Look closely at the macroexpansion under Section 4 of the output. The input expression had nested `:div`, `:h1`, and `:p` vectors. The `html` macro merged all static opening tags, attributes, and headings into the single literal `"<div class=\"box\"><h1>Title</h1><p>"` before the program ran, leaving only `(hy.I.html_dsl.render-child user)` to run dynamically.

## How It Works

### 1. Code as Models, `defmacro`, and Quasiquotation: `core_macros.hy`

When the Hy reader parses source text, it produces **models** from `hy.models`:

- `hy.models.Expression` for parenthesized calls like `(+ 1 2)`
- `hy.models.Symbol` for identifiers like `ready` or `total`
- `hy.models.Keyword` for keywords like `:else` or `:class`
- `hy.models.List`, `hy.models.Dict`, and `hy.models.Tuple` for `[...]`, `{...}`, and `#(...)`
- `hy.models.String`, `hy.models.Integer`, and `hy.models.Float` for scalar literals

Every model wraps the underlying Python type (`Expression` and `List` subclass `tuple`; `Symbol` and `String` subclass `str`) and records source line and column numbers so tracebacks point to the right file and line.

You can build models by calling constructors directly, or with **quasiquotation** (the backtick `` ` ``):

- `'form` (quote) returns `form` unevaluated as a model.
- `` `form `` (quasiquote) quotes `form` as a template, except where `~` or `~@` appears inside it.
- `~expr` (unquote) evaluates `expr` at macro-expansion time and inserts the resulting value into the template.
- `~@seq` (unquote-splice) evaluates `seq` and splices its elements flat into the surrounding sequence.

Here is the complete listing of `core_macros.hy`:

```hy
;; core_macros.hy -- Control-flow macros, timing macros, and AST inspection.

(import ast)
(import time)
(import hy.compiler [hy-compile])
(import hy.models [Keyword Symbol])


(defmacro unless [test #* body]
  "Evaluate body forms only when test is falsy."
  `(when (not ~test)
     ~@body))


(defmacro do-while [body-form condition]
  "Execute body-form at least once, repeating while condition is truthy."
  `(while True
     ~body-form
     (when (not ~condition)
       (break))))


(defmacro swap! [left right]
  "Swap two assignable places in place."
  `(setv [~left ~right] [~right ~left]))


(defmacro when-let [binding #* body]
  "Bind a symbol to an expression and run body only when the value is truthy.
  Usage: (when-let [user (find-user uid)] (greet user))"
  (when (!= (len binding) 2)
    (raise (SyntaxError "when-let expects a [symbol expr] binding pair")))
  (setv [sym expr] binding)
  `(do
     (setv ~sym ~expr)
     (when ~sym
       ~@body)))


(defmacro with-timer [label #* body]
  "Run body, print elapsed seconds with label, and return the body's value."
  (setv start (hy.gensym "start"))
  `(do
     (setv ~start (hy.I.time.perf-counter))
     (try
       (do ~@body)
       (finally
         (print ~label "took"
                (round (- (hy.I.time.perf-counter) ~start) 4)
                "s")))))


(defmacro timed [expr]
  "Evaluate expr once and return #(result elapsed-seconds)."
  (setv start (hy.gensym "start")
        result (hy.gensym "result"))
  `(do
     (setv ~start (hy.I.time.perf-counter)
           ~result ~expr)
     #(~result (- (hy.I.time.perf-counter) ~start))))


(defmacro mini-match [expr #* clauses]
  "Dispatch expr against [pattern result] clauses without re-evaluating expr.
  Use :else or _ for the wildcard branch."
  (setv target (hy.gensym "target")
        branches [])
  (for [clause clauses]
    (when (!= (len clause) 2)
      (raise (SyntaxError "mini-match clauses must be [pattern result] pairs")))
    (setv [pat result] clause)
    (if (or (= pat :else) (= pat '_))
        (.extend branches [True result])
        (.extend branches [`(= ~target ~pat) result])))
  `(do
     (setv ~target ~expr)
     (cond ~@branches)))


(defn expand-once-str [form [module None]]
  "Return the single-step macro expansion of form as Hy source text."
  (hy.repr (if (is module None)
               (hy.macroexpand-1 form)
               (hy.macroexpand-1 form module))))


(defn form-to-python [form [module-name "__main__"]]
  "Compile a quoted Hy form to formatted Python source code (like hy2py)."
  (setv expanded (hy.macroexpand form)
        py-ast (hy-compile expanded module-name)
        text (.strip (ast.unparse py-ast)))
  (.removeprefix text "import hy\n"))
```

Notice three practical patterns in `core_macros.hy`:

1. **Compile-time validation**: `when-let` and `mini-match` inspect `binding` and `clause` during macro expansion and raise `SyntaxError` immediately if the caller wrote the wrong shape. Errors surface when the module compiles, not hours later when a cold code branch executes.
2. **Self-contained imports with `hy.I`**: `with-timer` calls `(hy.I.time.perf-counter)` instead of `(time.perf-counter)`. The `hy.I` reader macro compiles to `hy.I.time.perf_counter()`, which imports `time` on demand. That way a file that requires `with-timer` does not crash if it forgot to write `(import time)`.
3. **Splicing pairs into `cond`**: `mini-match` collects `[condition-form result-form]` pairs into a flat Python list `branches` at compile time and splices them into `(cond ~@branches)`.

### 2. Expansion and Debugging: `hy.macroexpand-1`, `hy2py`, and `hy --spy`

When a macro produces a surprising error, printing its expansion is the fastest way to see what happened. Hy gives you four tools:

1. **`(hy.macroexpand-1 form)`**: expands the outer macro of `form` by one step and returns the resulting Hy model. Wrap it in `(hy.repr ...)` to print readable Hy syntax.
2. **`(hy.macroexpand form)`**: repeatedly expands outer macros until the head is no longer a macro.
3. **`hy2py`**: a command-line tool that compiles a `.hy` file to a Python AST and prints the generated Python code. Running `uv run hy2py core_macros.hy` shows how Hy compiles `defmacro` itself into a Python function registered with `hy.macros.macro`:

```python
def _hy_anon_1(test, *body):
    """Evaluate body forms only when test is falsy."""
    return hy.models.Expression([
        hy.models.Symbol('when', from_parser=True),
        hy.models.Expression([hy.models.Symbol('not', from_parser=True), test]),
        *(body or [])
    ])
hy.macros.macro('unless')(_hy_anon_1)
```

4. **`hy --spy`**: starting the REPL with `uv run hy --spy` prints the generated Python code before evaluating every REPL input. This lets you watch each macro expand and compile to Python statements in real time.

In our code, `form-to-python` runs the same pipeline programmatically by calling `(hy-compile (hy.macroexpand form) module-name)` followed by `(ast.unparse py-ast)`. That lets unit tests assert on the exact Python code a macro generates.

### 3. Macro Hygiene: `hygiene.hy`

A macro is **hygienic** when its expansion never evaluates caller expressions more times than expected and never collides with variable names in the caller's scope. Lisp macros can fail both ways if you write naive templates.

Here is `hygiene.hy`, which contrasts the broken versions with their hygienic replacements:

```hy
;; hygiene.hy -- Macro hygiene: multiple evaluation, variable capture, and fixes.

(require hyrule [defmacro! def-gensyms])


;; ---------- 1. Multiple evaluation ----------

(defmacro square-bad [x]
  "BROKEN: evaluates x twice when x has side effects."
  `(* ~x ~x))


(defmacro square-good [x]
  "HYGIENIC: binds x to a fresh gensym so x is evaluated once."
  (setv val (hy.gensym "val"))
  `(do
     (setv ~val ~x)
     (* ~val ~val)))


(defmacro! square-o! [o!x]
  "HYGIENIC (via hyrule defmacro!): o!x evaluates once and binds to g!x."
  `(* ~g!x ~g!x))


;; ---------- 2. Accidental variable capture ----------

(defmacro sum-steps-bad [n #* body]
  "BROKEN: leaks loop variable 'step' and accumulator 'total' into caller scope."
  `(do
     (setv total 0)
     (for [step (range ~n)]
       (+= total (do ~@body)))
     total))


(defmacro sum-steps-good [n #* body]
  "HYGIENIC: uses def-gensyms so caller variables named step or total are safe."
  (def-gensyms total step limit)
  `(do
     (setv ~limit ~n
           ~total 0)
     (for [~step (range ~limit)]
       (+= ~total (do ~@body)))
     ~total))


;; ---------- 3. Intentional capture (anaphoric macro) ----------

(defmacro aif [test-form then-form [else-form None]]
  "Anaphoric if: intentionally binds 'it' to the value of test-form."
  `(do
     (setv it ~test-form)
     (if it
         ~then-form
         ~else-form)))
```

Let us examine all three cases:

- **Multiple evaluation (`square-bad` vs `square-good` and `square-o!`)**:
  `(square-bad (bump))` expands to `(* (bump) (bump))`, calling `bump` twice. `square-good` calls `(hy.gensym "val")` at macro-expansion time to generate a unique symbol (such as `_val_1234`), evaluates `~x` once into `~val`, and multiplies `~val` by itself.
  The `hyrule` library provides `defmacro!`, inspired by Doug Hoyte's *Let Over Lambda*. Any parameter prefixed with `o!` (once-only, such as `o!x`) is automatically evaluated once before the macro body and bound to the matching `g!` gensym (`g!x`).
- **Accidental variable capture (`sum-steps-bad` vs `sum-steps-good`)**:
  Because Python and Hy share function-level variable scope, introducing a plain symbol like `step` or `total` inside a macro expansion writes directly into the caller's local scope. When the caller sets `(setv step 10)` and runs `(sum-steps-bad 3 step)`, the macro's `for [step (range 3)]` overwrites the caller's `step` with `0`, `1`, and `2`, returning `3` instead of `30`. `sum-steps-good` uses `hyrule`'s `(def-gensyms total step limit)` to create three fresh symbols at once.
- **Intentional capture (`aif`)**:
  Sometimes you want a macro to introduce a documented symbol into the caller's scope. An **anaphoric macro** like `aif` binds the pronoun `it` to the result of `test-form` so the caller can write `(aif (find-user uid) it.email "none")`. Because `it` is part of the macro's contract, this capture is deliberate rather than a bug.

### 4. Macro Namespaces: `require`, `export`, `hy.R`, and `local-macros`

In Python, `import` runs at run time. Because macros must run while a module is still compiling, Hy separates macro loading from `import`:

- **`(require module [macro-a macro-b])`**: loads `module` at compile time and registers `macro-a` and `macro-b` in the current module's macro table.
- **`(require module :as m)`**: registers macros under a prefix so you can call `(m.unless ready (boot))`.
- **`(require module :readers [sql env])`**: loads reader macros from `module`.
- **`hy.R`**: the compile-time equivalent of `hy.I`. Writing `(hy.R.core_macros.unless False "ok")` requires `core_macros` on the fly and invokes `unless` without a top-level `require` statement.
- **Controlling exports with `(export ...)`**: by default, `(require mod *)` brings in every macro defined in `mod` (and not macros that `mod` itself required from elsewhere). You can restrict what `import *` and `require *` expose using `(export :objects [fn1] :macros [mac1])`, which compiles to `__all__` and `_hy_export_macros`.

### 5. Reader Macros: `reader_macros.hy`

Ordinary macros transform Hy models *after* the reader has already parsed the source text. **Reader macros** hook into Step 1 of the pipeline: they run inside the parser when the reader sees `#tag`.

Inside `(defreader name ...)`, Hy binds the active reader instance to the symbol `&reader`. Calling `(.parse-one-form &reader)` reads and returns the next complete Hy form from the input stream.

Here is `reader_macros.hy`, which defines `#sql`, `#env`, and `#json`:

```hy
;; reader_macros.hy -- Reader macros (#env, #sql, #json) using defreader.

(import dataclasses [dataclass])
(import json)
(import re)
(import sqlite3)
(import hy.models [Dict List String])


(defclass [(dataclass :frozen True)] SqlQuery []
  "A parameterized SQL query checked at read time."
  #^ str sql
  #^ tuple params)


(defn normalize-sql [raw-sql]
  "Collapse internal whitespace and strip leading/trailing spaces."
  (setv cleaned (.strip (re.sub r"\s+" " " (str raw-sql))))
  (when (not cleaned)
    (raise (SyntaxError "#sql query string cannot be empty")))
  cleaned)


(defn compile-sql-form [form]
  "Validate a #sql form at read time and return code constructing SqlQuery."
  (cond
    (isinstance form String)
      (do
        (setv sql-text (normalize-sql form)
              placeholders (.count sql-text "?"))
        (when (!= placeholders 0)
          (raise (SyntaxError
                   f"#sql string has {placeholders} '?' placeholders but no params list")))
        `(hy.I.reader_macros.SqlQuery ~sql-text #()))
    (and (isinstance form List) (>= (len form) 1) (isinstance (get form 0) String))
      (do
        (setv sql-text (normalize-sql (get form 0))
              params (list (cut form 1 None))
              placeholders (.count sql-text "?"))
        (when (!= placeholders (len params))
          (raise (SyntaxError
                   f"#sql has {placeholders} '?' placeholders but {(len params)} params")))
        `(hy.I.reader_macros.SqlQuery ~sql-text #(~@params)))
    True
      (raise (SyntaxError
               "#sql expects a string literal or [\"SQL ...\" param1 param2 ...]"))))


(defreader sql
  (setv form (.parse-one-form &reader))
  (hy.I.reader_macros.compile-sql-form form))


(defn compile-env-form [form]
  "Expand #env \"VAR\" or #env [\"VAR\" \"default\"] into os.environ.get."
  (cond
    (isinstance form String)
      `(hy.I.os.environ.get ~(str form))
    (and (isinstance form List) (= (len form) 2) (isinstance (get form 0) String))
      `(hy.I.os.environ.get ~(str (get form 0)) ~(get form 1))
    True
      (raise (SyntaxError
               "#env expects \"VAR\" or [\"VAR\" default-expr]"))))


(defreader env
  (setv form (.parse-one-form &reader))
  (hy.I.reader_macros.compile-env-form form))


(defn json-to-model [val]
  "Convert parsed JSON values into Hy models for zero-cost runtime literals."
  (cond
    (isinstance val dict)
      (do
        (setv pairs [])
        (for [[k v] (.items val)]
          (.extend pairs [(String k) (json-to-model v)]))
        (Dict pairs))
    (isinstance val list)
      (List (gfor item val (json-to-model item)))
    (isinstance val str)
      (String val)
    True val))


(defn compile-json-form [form]
  "Parse a JSON string literal at read time and emit a Hy data literal."
  (when (not (isinstance form String))
    (raise (SyntaxError "#json expects a string literal")))
  (try
    (setv parsed (json.loads (str form)))
    (except [err json.JSONDecodeError]
      (raise (SyntaxError f"Invalid #json literal: {err.msg}"))))
  (json-to-model parsed))


(defreader json
  (setv form (.parse-one-form &reader))
  (hy.I.reader_macros.compile-json-form form))


(defn execute-sql [conn query]
  "Execute a SqlQuery against a sqlite3 connection and return rows as dicts."
  (when (not (isinstance query SqlQuery))
    (raise (TypeError "execute-sql expects a SqlQuery value")))
  (setv cursor (.execute conn query.sql query.params)
        columns (if cursor.description
                    (lfor col cursor.description (get col 0))
                    []))
  (lfor row (.fetchall cursor)
    (dict (zip columns row))))
```

Notice what `#sql` and `#json` accomplish at read time:

- `#sql` collapses multi-line whitespace into a single clean SQL string and counts the `?` parameter placeholders before the program runs. If a query has two `?` placeholders and you pass one parameter expression, `#sql` raises `SyntaxError` at compile time.
- `#json` calls `json.loads` at read time and converts the parsed structure into `hy.models.Dict` and `hy.models.List` nodes via `json-to-model`. Malformed JSON fails at compile time, and valid JSON compiles directly to a native Python dict or list literal with zero `json.loads` call at run time.

### 6. Case Study: NSK's `ask` and `rule` Macros

Before we build our HTML DSL, let us look at how the NSK knowledge graph chapter (**source_code_for_examples/nsk-neural-symbolic-graph**) uses macros to embed a Datalog query language inside Hy.

In NSK, a query looks like this:

```hy
(ask [?author ?lang]
  [?author :wrote :nsk]
  [?author ~:codes-in ?lang]
  :limit 5)
```

Notice why `ask` must be a macro rather than a function:

1. `?author` and `?lang` are unbound symbols. If `ask` were a function, Python would try to look up a local variable named `hyx_Xquestion_markXauthor` and raise `NameError`.
2. `~:codes-in` uses the unquote prefix `~` to mark a neural predicate. The Hy reader parses `~:codes-in` as the two-element expression `(unquote :codes-in)`. Outside a quasiquote or macro that intercepts it, evaluating `(unquote :codes-in)` is a compile error.
3. Ordinary Hy variables and function calls inside a pattern (such as `[?who :codes-in target-language]`) must still be evaluated normally at run time!

NSK solves all three requirements in 30 lines across `nsk/terms.hy` and `nsk/query.hy`:

```hy
;; From nsk/terms.hy
(defn var-symbol? [form]
  (and (isinstance form Symbol) (> (len form) 1) (.startswith form "?")))

(defn unquote? [form]
  (and (isinstance form Expression) (= (len form) 2)
       (= (get form 0) 'unquote)))

(defn compile-term [form]
  "Macro helper. Like to-term, but it returns code: ?x and ~p are rewritten and
  everything else is left for Hy to evaluate, so a pattern can mention ordinary
  variables and function calls."
  (cond
    (var-symbol? form) `(hy.I.nsk/terms.Var ~(cut (str form) 1 None))
    (unquote? form) `(hy.I.nsk/terms.Neural ~(compile-term (get form 1)))
    ;; A bare keyword in a call would be read as a keyword argument, so quote it.
    (isinstance form Keyword) `(quote ~form)
    True form))

(defn compile-pattern [form]
  (when (not (and (isinstance form List) (= (len form) 3)))
    (raise (ValueError f"a pattern needs exactly three terms: {(hy.repr form)}")))
  `#(~@(map compile-term form)))
```

And in `nsk/query.hy`:

```hy
;; From nsk/query.hy
(defn split-options [forms]
  "Macro helper: separate the [s p o] patterns from trailing :key value pairs."
  (setv patterns (lfor form forms :if (isinstance form List) form))
  #(patterns (cut forms (len patterns) None)))

(defmacro ask [select #* body]
  (setv [patterns options] (hy.I.nsk/query.split-options body))
  `(hy.I.nsk/query.run-query
     [~@(map hy.I.nsk/terms.compile-pattern patterns)]
     [~@(map hy.I.nsk/terms.compile-term select)]
     ~@options))
```

Look at the fourth branch of `compile-term`: `True form`. When a term in a pattern is not a `?variable`, not a `~predicate`, and not a `:keyword`, `compile-term` returns `form` unchanged! That single line is what lets NSK patterns mix logic variables (`?who`) with ordinary Python variables (`target-language`) and function calls seamlessly.

Finally, `nsk/__init__.hy` includes `(require nsk.query [ask rule])` alongside its `(import ...)` forms so a user of the package can write `(require nsk [ask rule])` from the top-level package namespace.

### 7. Project: A Compile-Time HTML and SVG DSL (`html_dsl.hy`)

Now we apply the same selective compilation technique to build `html_dsl.hy`. We want to write HTML and SVG trees as nested Hy vectors starting with a keyword tag name:

```hy
(html
  [:div {:class "card" :data-kind "demo"}
   [:h2 "Topic Summary"]
   [:p "Viewer: " user]
   [:ul (lfor item items (html [:li item]))]
   [:hr]])
```

If we wrote `html` as an ordinary function, every tag vector and attribute dict would be allocated at run time on every page render. By writing `html` as a macro that walks the nested structure at compile time, we get three advantages:

1. **Compile-time string folding**: static tags, static attribute dicts, and literal strings or numbers are escaped and concatenated into plain string constants during macro expansion.
2. **Compile-time validation**: void HTML elements (`<br>`, `<hr>`, `<img>`, `<input>`) are checked at compile time; giving children to `[:br "oops"]` raises `SyntaxError` before the program runs.
3. **Automatic runtime escaping**: any child or attribute value that is not a compile-time literal is wrapped in `(hy.I.html_dsl.render-child expr)` or `(hy.I.html_dsl.render-attr name expr)`, which escapes `<`, `>`, `&`, and quotes unless the value is already a `RawHtml` instance produced by `(html ...)` or `(raw ...)`.

Here is the complete listing of `html_dsl.hy`:

```hy
;; html_dsl.hy -- Compile-time HTML and SVG DSL with static string folding.

(import html :as py-html)
(import hy.models [Dict Expression Float Integer Keyword List String])


(setv VOID-TAGS #{"area" "base" "br" "col" "embed" "hr" "img"
                  "input" "link" "meta" "source" "track" "wbr"})


(defclass RawHtml []
  "Wrapper for pre-rendered HTML/SVG strings that must not be escaped again."
  (defn __init__ [self text]
    (setv self.text (str text)))

  (defn __str__ [self]
    self.text)

  (defn __repr__ [self]
    f"(RawHtml {(hy.repr self.text)})")

  (defn __eq__ [self other]
    (cond
      (isinstance other RawHtml) (= self.text other.text)
      (isinstance other str) (= self.text other)
      True False)))


(defn raw [text]
  "Mark a string as trusted HTML so render-child does not escape it."
  (RawHtml text))


(defn scalar-to-str [value]
  "Convert Hy model scalars (Integer, Float, String) or Python values to str."
  (cond
    (isinstance value Integer) (str (int value))
    (isinstance value Float) (str (float value))
    True (str value)))


(defn escape-html [value]
  "Escape special HTML characters (&, <, >, quotes) in value."
  (py-html.escape (scalar-to-str value) :quote True))


(defn attr-name [key]
  "Convert a keyword or string key into an HTML attribute name."
  (if (isinstance key Keyword)
      key.name
      (str key)))


(defn render-attr [key value]
  "Render one HTML attribute at run time.
  Boolean True renders a bare attribute; False or None omits the attribute."
  (setv name (attr-name key))
  (cond
    (or (is value None) (is value False)) ""
    (is value True) f" {name}"
    True f" {name}=\"{(escape-html value)}\""))


(defn render-child [value]
  "Render a dynamic child value at run time with automatic HTML escaping."
  (cond
    (or (is value None) (is value False)) ""
    (isinstance value RawHtml) value.text
    (isinstance value #(list tuple))
      (.join "" (gfor item value (render-child item)))
    (hasattr value "__iter__")
      (if (isinstance value #(str bytes))
          (escape-html value)
          (.join "" (gfor item value (render-child item))))
    True (escape-html value)))


(defn literal-scalar? [form]
  (isinstance form #(String Integer Float)))


(defn tag-form? [form]
  "True when form is [:tag ...] or (:tag ...) with a Keyword head."
  (and (isinstance form #(List Expression))
       (> (len form) 0)
       (isinstance (get form 0) Keyword)))


(defn compile-attrs [attr-dict]
  "Compile a Hy Dict model of attributes into a list of segments."
  (setv items (list attr-dict))
  (when (% (len items) 2)
    (raise (SyntaxError "Attribute dictionary must have key/value pairs")))
  (setv segments [])
  (for [idx (range 0 (len items) 2)]
    (setv k (get items idx)
          v (get items (+ idx 1))
          name (if (isinstance k #(Keyword String)) (attr-name k) None))
    (cond
      (and name (literal-scalar? v))
        (.append segments f" {name}=\"{(escape-html v)}\"")
      (and name (= v 'True))
        (.append segments f" {name}")
      (and name (or (= v 'False) (= v 'None)))
        None
      name
        (.append segments `(hy.I.html_dsl.render-attr ~(String name) ~v))
      True
        (.append segments `(hy.I.html_dsl.render-attr ~k ~v))))
  segments)


(defn compile-node [form]
  "Compile one DSL node into a list of static strings and runtime expressions."
  (cond
    (tag-form? form)
      (do
        (setv tag (. (get form 0) name)
              rest-forms (list (cut form 1 None))
              has-attrs (and rest-forms (isinstance (get rest-forms 0) Dict))
              attr-form (if has-attrs (get rest-forms 0) None)
              children (if has-attrs (cut rest-forms 1 None) rest-forms)
              segments [f"<{tag}"])
        (when (is-not attr-form None)
          (.extend segments (compile-attrs attr-form)))
        (.append segments ">")
        (if (in tag VOID-TAGS)
            (when children
              (raise (SyntaxError f"Void HTML element <{tag}> cannot have children")))
            (do
              (for [child children]
                (.extend segments (compile-node child)))
              (.append segments f"</{tag}>")))
        segments)
    (literal-scalar? form)
      [(escape-html form)]
    True
      [`(hy.I.html_dsl.render-child ~form)]))


(defn merge-segments [segments]
  "Coalesce adjacent compile-time string segments into single String models."
  (setv merged [])
  (for [seg segments]
    (if (isinstance seg str)
        (if (and merged (isinstance (get merged -1) String))
            (setv (get merged -1) (String (+ (str (get merged -1)) seg)))
            (.append merged (String seg)))
        (.append merged seg)))
  merged)


(defn build-html-expr [nodes]
  "Compile a sequence of nodes into a RawHtml construction form."
  (setv raw-segments [])
  (for [node nodes]
    (.extend raw-segments (compile-node node)))
  (setv merged (merge-segments raw-segments))
  (cond
    (not merged)
      `(hy.I.html_dsl.RawHtml "")
    (and (= (len merged) 1) (isinstance (get merged 0) String))
      `(hy.I.html_dsl.RawHtml ~(get merged 0))
    True
      `(hy.I.html_dsl.RawHtml (.join "" [~@merged]))))


(defmacro html [#* nodes]
  "Compile nested [:tag {:attr val} ...] forms into a RawHtml value.
  Static tags, attributes, and text are folded into string literals at
  compile time; dynamic expressions are escaped at run time."
  (hy.I.html_dsl.build-html-expr nodes))


(defmacro svg [attrs #* children]
  "Compile an inline <svg> element with the default SVG xmlns attribute."
  (when (not (isinstance attrs Dict))
    (raise (SyntaxError "svg expects an attribute dict as its first argument")))
  (setv items (list attrs)
        keys (lfor i (range 0 (len items) 2) (attr-name (get items i)))
        full-items (if (in "xmlns" keys)
                       items
                       [(Keyword "xmlns") (String "http://www.w3.org/2000/svg") #* items])
        svg-node (List [(Keyword "svg") (Dict full-items) #* children]))
  (hy.I.html_dsl.build-html-expr [svg-node]))
```

Two implementation details in `html_dsl.hy` are worth highlighting for your own macros:

1. **`scalar-to-str` and Hy model strings**: in Hy 1.3.1, calling `(str form)` on a `hy.models.Integer` returns `"hy.models.Integer(140)"` rather than `"140"`. Converting `Integer` with `(int value)` and `Float` with `(float value)` before calling `str` produces the clean numeric text `"140"`.
2. **Passing attribute names as strings**: in `compile-attrs`, when an attribute key is a keyword such as `:disabled`, splicing `~k` directly into `(render-attr ~k ~v)` would emit `(render-attr :disabled is-disabled)`, which Hy compiles as a keyword argument `render_attr(disabled=is_disabled)`! Converting `name` to `(String name)` at compile time emits `(render-attr "disabled" is-disabled)` as a positional string argument.

### 8. Macros vs Functions vs Decorators vs `__init_subclass__`

A good rule in Lisp is to use the **least powerful tool** that solves the problem cleanly. Functions are easier to pass around as values, inspect in stack traces, and call from Python.

| Tool | Runs when | Receives | Best for | Avoid when |
| --- | --- | --- | --- | --- |
| **Function (`defn`)** | Run time | Evaluated values | 90% of program logic, data transformations, composable callbacks | You need custom evaluation order, new bindings, or compile-time syntax |
| **Decorator / `with`** | Definition or run time | Function, class, or runtime context | Wrapping functions (caching, auth, retries) or resource cleanup | You need to rewrite expressions inside a function body |
| **`__init_subclass__` / dataclasses** | Class creation time | Subclass object | Registering plugins, validating class attributes | The problem is not naturally a class hierarchy |
| **Macro (`defmacro`)** | Compile time | Unevaluated Hy models | Control flow (`unless`, `do-while`), binding forms (`when-let`), embedded DSLs (`ask`, `html`), compile-time folding | A plain function or context manager would be just as clear |
| **Reader macro (`defreader`)** | Parse time | Active `&reader` stream | Checked literals (`#sql`, `#json`, `#env`), terse domain notation | Ordinary macro syntax `(sql ...)` is already readable |

Also remember Python interoperability: a Python module importing your Hy module can call any `defn` function or `defclass` class directly, whereas a macro only exists at Hy compile time (unless a Python caller invokes `hy.eval`). When you publish a library for both Hy and Python callers, put the runtime engine in ordinary functions (like NSK's `run-query` or `reader_macros.hy`'s `execute-sql`) and make the macro a thin compile-time layer on top.

## Tests

The example includes two pytest files: `test_macros.hy` and `test_html_dsl.hy`. Run them with:

```bash
uv run pytest -q
```

```text
....................                                                     [100%]
20 passed in 0.21s
```

Here are the key tests from `test_macros.hy`, which check single-step expansions with `expand-once-str`, golden Python translations with `form-to-python`, hygiene guarantees, `hy.R` namespace resolution, and compile-time reader errors:

```hy
;; From test_macros.hy

(defn test-unless-expansion-and-behavior []
  (assert (= (expand-once-str '(unless ready (launch)))
             "'(when (not ready) (launch))"))
  (setv log [])
  (unless False
    (.append log "first")
    (.append log "second"))
  (unless True
    (.append log "never"))
  (assert (= log ["first" "second"])))


(defn test-hy2py-golden-translation []
  (setv py-swap (form-to-python '(swap! left right)))
  (assert (= (.strip py-swap) "[left, right] = [right, left]"))

  (setv py-unless (form-to-python '(unless done (step))))
  (assert (in "not done" py-unless))
  (assert (in "step()" py-unless)))


(defn test-multiple-evaluation-hygiene []
  (setv counter 0)
  (defn next-int []
    (nonlocal counter)
    (+= counter 1)
    3)

  (setv bad (square-bad (next-int)))
  (assert (= bad 9))
  (assert (= counter 2))

  (setv counter 0)
  (setv good (square-good (next-int)))
  (assert (= good 9))
  (assert (= counter 1))

  (setv counter 0)
  (setv good-o (square-o! (next-int)))
  (assert (= good-o 9))
  (assert (= counter 1)))


(defn test-variable-capture-hygiene []
  (setv step 10
        total 100)
  ;; Broken macro overwrites caller's 'step' with 0, 1, 2
  (assert (= (sum-steps-bad 3 step) 3))

  (setv step 10
        total 100)
  ;; Hygienic macro preserves caller's 'step' (10 + 10 + 10 = 30) and 'total'
  (assert (= (sum-steps-good 3 step) 30))
  (assert (= step 10))
  (assert (= total 100)))


(defn test-reader-macro-sql []
  (setv conn (sqlite3.connect ":memory:"))
  (.execute conn "CREATE TABLE books (title TEXT, pages INT)")
  (.executemany conn
    "INSERT INTO books VALUES (?, ?)"
    [#("On Lisp" 432)
     #("Practical Common Lisp" 499)
     #("Brief Guide" 90)])

  (setv min-pages 200
        q #sql ["  SELECT title, pages
                   FROM   books
                   WHERE  pages >= ?
                   ORDER BY pages " min-pages])
  (assert (isinstance q SqlQuery))
  (assert (= q.sql "SELECT title, pages FROM books WHERE pages >= ? ORDER BY pages"))
  (assert (= q.params #(200)))

  (setv rows (execute-sql conn q))
  (assert (= (len rows) 2))
  (assert (= (get (get rows 0) "title") "On Lisp"))
  (.close conn)

  ;; Mismatched '?' placeholder count fails at compile/read time
  (with [(pytest.raises Exception)]
    (hy.eval (hy.read "(do (require reader_macros :readers [sql]) #sql [\"SELECT ? AND ?\" 1])"))))
```

And here are the core tests from `test_html_dsl.hy`, which verify that static HTML trees fold into a single literal string at compile time, untrusted input is escaped, and void elements reject children:

```hy
;; From test_html_dsl.hy

(defn test-static-html-folds-at-compile-time []
  (setv exp (hy.repr (hy.macroexpand-1 '(html [:div {:class "card"} [:h1 "Title"] [:hr]]))))
  ;; Entire static tree folds into a single string literal with no .join call
  (assert (in "\"<div class=\\\"card\\\"><h1>Title</h1><hr></div>\"" exp))
  (assert (not-in ".join" exp))

  (setv out (html [:div {:class "card"} [:h1 "Title"] [:hr]]))
  (assert (isinstance out RawHtml))
  (assert (= (str out) "<div class=\"card\"><h1>Title</h1><hr></div>")))


(defn test-dynamic-escaping-and-raw-bypass []
  (setv untrusted "<img src=x onerror=\"alert(1)\">"
        safe-badge (raw "<strong>verified</strong>"))
  (setv rendered
    (str (html [:p {:title untrusted}
                "User: " untrusted " " safe-badge])))
  (assert (= rendered
             (+ "<p title=\"&lt;img src=x onerror=&quot;alert(1)&quot;&gt;\">"
                "User: &lt;img src=x onerror=&quot;alert(1)&quot;&gt; "
                "<strong>verified</strong></p>"))))


(defn test-void-tag-rejects-children-at-compile-time []
  (with [(pytest.raises Exception)]
    (hy.eval (hy.read "(do (require html_dsl [html]) (html [:br \"oops\"]))"))))
```

## Wrap Up

Macros are the dividing line between using Lisp syntax and programming in Lisp. With `defmacro`, quasiquotation (`~` and `~@`), `hy.gensym` (or `hyrule`'s `def-gensyms` and `defmacro!`), and `defreader`, you can move validation, boilerplate, and constant folding from run time to compile time. At the same time, keeping your macros thin and delegating runtime work to ordinary Hy functions ensures that your code remains easy to test with pytest, inspect with `hy.macroexpand-1` and `hy2py`, and call from Python.

## Exercises

1. **Small exercise (`repeat-until` and `with-timer-collector`)**:
   Add a `(repeat-until body-form condition)` macro to `core_macros.hy` that loops until `condition` becomes truthy (the opposite of `do-while`). Then write a `(with-timer-into dict-expr key-expr #* body)` macro that records the elapsed seconds into `(get dict-expr key-expr)` instead of printing to standard output. Be sure to evaluate `dict-expr` and `key-expr` only once using `hy.gensym`.
2. **Open-ended exercise (CSS selector shorthand and `#regex` reader macro)**:
   Extend `compile-node` in `html_dsl.hy` so tag keywords support CSS-style `#id` and `.class` suffixes at compile time: writing `[:div#main.card.featured "Hello"]` should compile to `"<div id=\"main\" class=\"card featured\">Hello</div>"`, merging with any `:class` key in the attribute dictionary. Next, add a `#re` reader macro in `reader_macros.hy` that takes a string literal, validates the regular expression syntax at compile time with `re.compile`, and expands to `(hy.I.re.compile pattern)`.

## Further Reading

- [Hy 1.3.1 Macros Manual](https://hylang.org/hy/doc/v1.3.1/macros): official documentation on `defmacro`, `defreader`, `hy.gensym`, `require`, and `export`.
- [Hyrule Documentation](https://hyrule.readthedocs.io/): Hy's utility library, including `defmacro!`, `def-gensyms`, and `macroexpand-all`.
- Paul Graham, *On Lisp* (Prentice Hall, 1993): classic treatment of bottom-up design, macro pitfalls, and embedded languages.
- Peter Seibel, *Practical Common Lisp* (Apress, 2005), Chapters 7, 8, and 30: macro fundamentals and a compile-time HTML generator.
- Doug Hoyte, *Let Over Lambda* (2008): reader macros, once-only `o!`/`g!` gensyms, and compile-time computation.
