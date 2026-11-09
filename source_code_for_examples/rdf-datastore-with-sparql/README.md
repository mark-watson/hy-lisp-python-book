# RDF Datastore with SPARQL Query Support

**Book Chapter:** [Linked Data](https://leanpub.com/read/hy-lisp-python/linkeddata) — *A Lisp Programmer Living in Python-Land* (free to read online).

This directory contains a simple, self-contained implementation of an RDF (Resource Description Framework) triple store with a subset of SPARQL query functionality, ported from the Common Lisp version in `loving-common-lisp`. It includes support for adding and removing triples, pattern matching, variable binding, and multi-pattern join resolution (conjunctions).

The project consists of:
- **`rdf_datastore.hy`** — The core library defining the `RdfStore` class and query execution logic.
- **`main.hy`** — A demonstration script that adds triples, prints the store, and runs sample SPARQL SELECT queries.
- **`test_basic.hy`** — A self-contained test script combining library and test code for easy standalone testing.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager

## Initial Setup

```bash
uv sync
```

## Running the Example

To run the demonstration script:

```bash
uv run hy main.hy
```

This will run several example queries against the datastore, showcasing single-pattern queries, multi-pattern joins, and variable projection.

## Running the Tests

The tests are written in Hy in `test_rdf_datastore.hy`. Run them with:

```bash
uv run pytest
```

The tests cover the triple store, the SPARQL parser, and single-pattern, join and projection queries. (`test_basic.hy` is an older self-contained demo script; pytest collects it but it contains no tests.)

By default pytest does not collect `.hy` files, so `conftest.py` adds a small hook that tells it to collect any file named `test_*.hy`. To add more tests, create another `test_*.hy` file or add `test-` functions to `test_rdf_datastore.hy`.
