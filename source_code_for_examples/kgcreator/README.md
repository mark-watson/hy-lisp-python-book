# Knowledge Graph Creator

Start with the code in kgcreator.hy, reading the minor limitations in the book, then experiment with the more complicated kgcreator_uri.hy.

## Initial setup

```
$uv run python -m spacy download en_core_web_sm
```

## Running two examples

```
$ uv sync
$ uv run hy kgcreator.hy
$ uv run hy kgcreator_uri.hy
```

