# Implementing Knowledge Graph Navigator in Hy

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

```
$ uv run hy kgcreator.hy
$ uv run hy kgcreator_uri.hy
```




One time only, install requirements PyInquirer (for text based menu system: arrow keys up down, spade to select options, enter or return to exit menu with selections):

    pip install -r requirements.txt
    python -m spacy download en_core_web_sm

Note 2022/11/27: PyInquirer is not working for me with newer versions of Python and has not been updated. I had to **pip uninstall pyinquirer** and then git clone https://github.com/CITGuru/PyInquirer and run **python setup.py install**.

After **pip install spacy** run:

    python -m spacy download en_core_web_sm

and then run the program:

    hy kgn.hy

For Hy version 0.25: also need: ** pip install hyrule**

Enter a list of people, place, organization names when prompted. You then see a list of entities found on DBPedia. Select the entities you want more information on. For example, try entering the following input:

    Steve Jobs went to Microsoft in Seattle to visit Bill Gates


