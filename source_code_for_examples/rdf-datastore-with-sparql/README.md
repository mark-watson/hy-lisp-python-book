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
