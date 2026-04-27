# Knowledge Graph Creator

**Book Chapter:** [Knowledge Graph Creator](https://leanpub.com/read/hy-lisp-python/leanpub-auto-knowledge-graph-creator) — *A Lisp Programmer Living in Python-Land* (free to read online).

This example automatically constructs **RDF-style knowledge graph triples** (subject → predicate → object) from plain-text documents using spaCy NLP. Two scripts are provided:

- **`kgcreator.hy`** — generates triples with simple string labels. Start here.
- **`kgcreator_uri.hy`** — generates triples using DBpedia URIs for entities, producing linked-data-friendly output. Read the minor limitations noted in the book before using this version.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager

## Initial Setup

Download the spaCy English language model (one-time step):

```bash
uv sync
uv run python -m spacy download en_core_web_sm
```

## Running the Examples

```bash
uv run hy kgcreator.hy
uv run hy kgcreator_uri.hy
```
