# Natural Language Processing (NLP) Examples

**Book Chapter:** [Natural Language Processing](https://leanpub.com/read/hy-lisp-python/leanpub-auto-natural-language-processing) — *A Lisp Programmer Living in Python-Land* (free to read online).

This example demonstrates **named entity recognition** using [spaCy](https://spacy.io/) from Hy. The `nlp_lib.hy` module provides a reusable `nlp` function that extracts people, places, and organizations from text. The `nlp_example.hy` script shows it in action on sample sentences.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager

## Initial Setup

Download the spaCy English language model (one-time step):

```bash
uv sync
uv run python -m spacy download en_core_web_sm
```

## Running the Example

```bash
uv run hy nlp_example.hy
```

The output shows extracted named entities (people, places, organizations) for each input sentence.