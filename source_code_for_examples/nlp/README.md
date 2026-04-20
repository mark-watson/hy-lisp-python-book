# Notes for running the natural language processing (NLP) examples

**Book Chapter:** [Natural Language Processing](https://leanpub.com/read/hy-lisp-python/leanpub-auto-natural-language-processing) — *A Lisp Programmer Living in Python-Land* (free to read online).

Install **uv** if it is not already on your system.

One time setup:

```
$ uv run python -m spacy download en_core_web_sm
```

Run example:

```
$ uv run hy nlp_example.hy
```