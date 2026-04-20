# Implementing Knowledge Graph Navigator in Hy

**Book Chapter:** [Knowledge Graph Navigator](https://leanpub.com/read/hy-lisp-python/kgn) — *A Lisp Programmer Living in Python-Land* (free to read online).

Run the program:

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

Don't use **uv run hy**, instead use:

```
$ uv run hy kgn.hy
$ uv run hy kgcreator_uri.hy
```


Enter a list of people, place, organization names when prompted. You then see a list of entities found on DBPedia. Select the entities you want more information on. For example, try entering the following input:

    Steve Jobs went to Microsoft in Seattle to visit Bill Gates


