# Knowledge Graph Creator

Start with the code in kgcreator.hy, reading the minor limitations in the book, then experiment with the more complicated kgcreator_uri.hy.

## Initial setup

```
$ uv init
$ uv venv
$ source .venv/bin/activate
$ rm -f hello.py
$ uv add hy spacy pip
uv run python -m spacy download en_core_web_sm
```

Installing **pip** into local **uv** enviroment is required for **uv run python -m spacy download en_core_web_sm**.

## Running two examples

```
$ uv sync
$ uv run hy kgcreator.hy
$ uv run hy kgcreator_uri.hy
```

