# NSK: A Neural-Symbolic Knowledge Graph Engine in Hy

NSK is a small hybrid knowledge graph database. It stores subject-predicate-object triples, answers Datalog-style queries by unification, derives new triples with rules, and asks a local language model (through [Ollama](https://ollama.com)) when a query has no symbolic answer.

This is a Hy version of the Common Lisp NSK example in *Loving Common Lisp* (`src/nsk-neural-symbolic-graph` in that book's repository). It keeps the same design and adds several features; see [Differences from the Common Lisp version](#differences-from-the-common-lisp-version).

## Project Structure

```
nsk-neural-symbolic-graph/
├── nsk/
│   ├── __init__.hy    ← Public names and the ask / rule macros
│   ├── terms.hy       ← Logic variables, neural predicates, unification
│   ├── store.hy       ← Triplestore, indices, append-only log
│   ├── neural.hy      ← Ollama client, inference, text-to-triples
│   ├── query.hy       ← Pattern matching, rules, neural fallback, macros
│   ├── repl.hy        ← Interactive prompt
│   ├── server.hy      ← REST server (standard library only)
│   └── __main__.hy    ← Command-line entry point
├── demo.hy            ← Guided tour that prints its results
├── test_nsk.hy        ← Tests (pytest)
├── conftest.py        ← Lets pytest collect test_*.hy files
└── pyproject.toml     ← Dependency configuration (uv)
```

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager
- Optional, for the neural layer: Ollama running locally with the `qwen3.5:4b` model (`ollama pull qwen3.5:4b`)

The graph engine, the query language, rules, persistence, the REPL and the server all work with no Ollama daemon. A neural query then prints a short note and returns no solutions.

## Running the Examples

```bash
uv sync

# A guided tour: facts, queries, rules, persistence, neural fallback
uv run hy demo.hy

# The interactive REPL (the graph is saved in nsk-graph.log)
uv run hy -m nsk

# The REST server
uv run hy -m nsk --serve --port 8800
```

Command-line options:

| Option          | Effect                                              |
| --------------- | --------------------------------------------------- |
| `--db PATH`     | transaction log to use (default `nsk-graph.log`)    |
| `--memory`      | keep the graph in memory only; write no log         |
| `--serve`       | start the REST server instead of the REPL           |
| `--host HOST`   | server address (default `127.0.0.1`)                |
| `--port N`      | server port (default `8800`)                        |
| `--model NAME`  | Ollama model (default `qwen3.5:4b`)                 |
| `--no-neural`   | never call the model                                |

## Quick Start

```
$ uv run hy -m nsk --memory
NSK: Neural-Symbolic Knowledge Graph Engine
Type :help for commands, :quit to exit.
nsk> (:add :mark :wrote :nsk)
added [:mark :wrote :nsk]
nsk> (:add :mark :codes-in :lisp)
added [:mark :codes-in :lisp]
nsk> [?who :wrote :nsk]
who=:mark
nsk> [?a :wrote :nsk] [?a :codes-in ?lang]
a=:mark, lang=:lisp
nsk> (:rule [?x :author ?y] [?y :wrote ?x])
rule added: [?x :author ?y] <- [?y :wrote ?x]
nsk> [:nsk :author ?who]
who=:mark    ; rule: [:nsk :author :mark]
nsk> [?city ~:capital-of :italy]
city=:rome    ; neural: [:rome :capital-of :italy]
nsk> :facts
  [:mark :wrote :nsk]
  [:mark :codes-in :lisp]
  [:rome :capital-of :italy]    ; neural
  [:nsk :author :mark]    ; rule
(4 triples)
nsk> :quit
Bye.
```

## Query Syntax

| You write          | Meaning                                                  |
| ------------------ | -------------------------------------------------------- |
| `:mark`, `"text"`, `42` | a term: a keyword, a string, or a number            |
| `?person`          | a logic variable                                         |
| `[?p :wrote :nsk]` | a triple pattern                                         |
| `~:codes-in`       | a neural predicate: ask the model if no stored triple matches |

The Common Lisp version installs three reader macros to get this syntax. Hy needs none. The Hy reader already reads `?person` as a symbol, `[s p o]` as a list, and `~x` as `(unquote x)`, so an ordinary macro can give those forms their query meaning.

### In the REPL

Type one pattern to run it. Type several patterns on one line to join them. The REPL proves the patterns left to right and passes the bindings forward.

A line ending in `; neural: ...` or `; rule: ...` names the triples behind that answer that are not plain facts. An answer with no such note rests on asserted facts alone.

### In your own code

```hy
(import nsk [Graph use-graph])
(require nsk [ask rule])

(setv graph (use-graph (Graph)))          ; or (Graph "my-graph.log")
(graph.add-all [[:mark :wrote :nsk]
                [:mark :codes-in :lisp]])

(setv result (ask [?author ?lang]
               [?author :wrote :nsk]
               [?author ~:codes-in ?lang]))

(print result)                 ; author=:mark, lang=:lisp
(for [row result]              ; each row is a dict keyed by variable name
  (print (get row "author")))
```

The first list after `ask` names the variables to return. Each later list is a pattern. Only `?variables` and `~predicates` are special inside a pattern; everything else is ordinary Hy and is evaluated, so a pattern can use local variables:

```hy
(for [language [:lisp :python]]
  (print (ask [?who] [?who :codes-in language])))
```

Options follow the patterns: `:graph g` queries a graph other than the default, `:limit n` stops after `n` solutions, and `:neural False` keeps the model out of this query.

One Hy detail matters here. In a function call, Hy reads a keyword as the name of a keyword argument, so `(graph.add :mark :wrote :nsk)` does not work. Triples are therefore passed as lists: `(graph.add [:mark :wrote :nsk])`. To pass a single keyword to a function, quote it: `(to-term ':mark)`.

## Rules

A rule derives new triples from existing ones. The head comes first, then the body patterns:

```hy
(rule [?x :ancestor ?y]  [?x :parent ?y])
(rule [?x :ancestor ?z]  [?x :parent ?y] [?y :ancestor ?z])
```

Rules run forward to a fixed point: NSK applies every rule until a full pass adds nothing. Derived triples are indexed like any other triple, marked with the source `rule`, and rebuilt when a fact or a rule changes. Recursive rules such as `:ancestor` therefore need no special handling. Every variable in a rule's head must appear in its body. Rules never call the model.

## REPL Commands

| Command                 | Effect                                            |
| ----------------------- | ------------------------------------------------- |
| `:help`                 | show the command list                             |
| `(:add s p o)`          | add a triple                                      |
| `(:del s p o)`          | remove a triple                                   |
| `(:ingest "text")`      | extract triples from text with the model          |
| `(:rule head body...)`  | add a rule                                        |
| `:rules`                | list the rules with their numbers                 |
| `(:unrule n)`           | remove rule number `n`                            |
| `:facts`                | list every triple and its source                  |
| `:count`                | show the triple count                             |
| `:forget`               | remove every triple the model inferred            |
| `:model`                | show the model; `(:model "name")` changes it      |
| `:save`                 | force the log to disk                             |
| `:compact`              | rewrite the log to hold only the live state       |
| `:quit`                 | leave the REPL                                    |

Any other form is evaluated as Hy, with `ask` and `rule` available and the graph bound to `graph`. A form may span several lines. Line editing and history come from Python's `readline` module.

Commands and bare patterns are converted to terms without being evaluated. That is why `(:add :mark :wrote :nsk)` works at the prompt even though keywords cannot be passed that way in Hy code.

## Storage

Every change appends one s-expression to the log and flushes it:

```
(:add :mark :wrote :nsk)
(:infer :rome :capital-of :italy)
(:rule [?x :author ?y] [?y :wrote ?x])
(:del :mark :wrote :nsk)
```

On startup NSK reads the log with the Hy reader and replays it. The reader parses forms but never evaluates them, so a log file cannot run code. If the log ends in an incomplete entry, as it would after a crash in the middle of a write, NSK drops that entry, prints a note, and rewrites the log. Triples derived by rules are not logged; they are rebuilt from the rules.

## Neural Layer

NSK calls the model in two places.

**Fallback inference.** When a pattern with a `~` predicate matches no stored triple, and exactly one of its subject and object is unknown, NSK asks the model for the missing term. The prompt includes the facts the graph already holds about the known term. The model may answer `null`, which gives no solution.

**Text ingestion.** `(:ingest "text")` asks the model to turn free text into triples and adds them.

Both calls pass Ollama a JSON schema, so the reply is constrained to the expected shape. Names from the model become keywords: `"Common Lisp"` becomes `:common-lisp`.

An inferred triple is stored in the graph with the source `neural`, so the model is asked only once, and every answer that depends on it says so. Asserting the same triple yourself promotes it to a fact. `:forget` removes all inferred triples. A small model will sometimes guess wrong, which is the reason for the labels: treat `neural` answers as suggestions to check.

Settings live in the dict `nsk.config`:

| Key         | Default                     | Meaning                                         |
| ----------- | --------------------------- | ----------------------------------------------- |
| `"model"`   | `qwen3.5:4b` or `$NSK_MODEL` | Ollama model                                   |
| `"host"`    | `http://localhost:11434` or `$OLLAMA_HOST` | Ollama daemon                    |
| `"enabled"` | `True`                      | `False` treats every `~` predicate as a plain one |
| `"cache"`   | `True`                      | store inferred triples in the graph             |
| `"think"`   | `False`                     | let a thinking model reason before it answers (slower) |
| `"timeout"` | `120`                       | seconds to wait for the model                   |

## REST Server

```bash
uv run hy -m nsk --serve --port 8800
```

In JSON, a term is a string. `"?name"` is a variable, a predicate written `"~name"` is neural, and any other string becomes a keyword. In `/query`, a field that is `null` or missing is a variable named after the field.

| Request            | Body                                                        | Effect                |
| ------------------ | ----------------------------------------------------------- | --------------------- |
| `GET /health`      |                                                             | counts and model name |
| `GET /triples`     |                                                             | every triple with its source |
| `POST /triples`    | `{"subject": .., "predicate": .., "object": ..}`            | add a triple          |
| `DELETE /triples`  | `{"subject": .., "predicate": .., "object": ..}`            | remove a triple       |
| `POST /query`      | `{"subject": .., "predicate": .., "object": ..}`            | run one pattern       |
| `POST /ask`        | `{"select": ["?a"], "where": [[s, p, o], ...], "limit": n}` | run a join            |
| `POST /ingest`     | `{"text": ".."}`                                            | extract and add triples |

```bash
curl -s localhost:8800/query \
  -d '{"subject": null, "predicate": "wrote", "object": "nsk"}'
```

```json
{"count": 1, "results": [{"subject": "mark"}], "provenance": []}
```

```bash
curl -s localhost:8800/ask \
  -d '{"select": ["?who", "?city"],
       "where": [["?who", "wrote", "nsk"], ["?city", "~capital-of", "france"]]}'
```

```json
{"count": 1,
 "results": [{"who": "mark", "city": "paris"}],
 "provenance": [{"triple": ["paris", "capital-of", "france"], "source": "neural"}]}
```

The server listens on `127.0.0.1` unless you pass `--host`. It has no authentication, so do not expose it to a network you do not trust.

## Running the Tests

The tests are written in Hy in `test_nsk.hy`. Run them with:

```bash
uv run pytest
```

Ollama does not need to be running: the one function that calls the model, `nsk.neural.chat-json`, is replaced with a fake. The tests cover unification, the store and its indices, log replay and repair, queries, rules, the neural fallback, the REPL, and the REST server.

By default pytest does not collect `.hy` files, so `conftest.py` adds a small hook that tells it to collect any file named `test_*.hy`.

## Differences from the Common Lisp Version

| Area            | Common Lisp NSK                              | This version                                              |
| --------------- | -------------------------------------------- | --------------------------------------------------------- |
| Query syntax    | three reader macros in a custom readtable    | no reader changes; one `ask` macro                        |
| Patterns        | terms are literals                           | patterns can contain any Hy expression                    |
| Rules           | none                                         | forward-chaining rules, including recursive ones          |
| Provenance      | none                                         | every triple and every answer records fact, rule, or neural |
| Indices         | subject and object; removal scans a list     | subject, predicate, and object; removal is O(1)           |
| Search          | builds every solution with `mapcan`          | generators, so `:limit` stops the search early            |
| Neural fallback | asks for a missing object; no context        | asks for a missing subject or object, sends known facts, accepts "unknown" |
| Model output    | finds the first JSON object in the reply     | reply constrained by a JSON schema                        |
| Repeated questions | asked again each time                     | inferred triples are stored and marked; `:forget` removes them |
| Log             | grows without bound; a torn entry stops the load | `:compact` rewrites it; a torn final entry is repaired |
| REPL            | needs `rlwrap` for line editing              | built-in history and editing; joins typed as bare patterns |
| REST server     | Hunchentoot, `/query` and `/health`          | standard library; adds joins, add, remove, list, ingest   |
| JSON            | 190-line hand-written reader and writer      | Python's `json` module                                    |
