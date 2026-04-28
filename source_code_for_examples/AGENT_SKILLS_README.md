---
name: hylang-hy-dev
description: Hy language tutorial, idioms, and API reference for all examples in Mark Watson's Hy book "A Lisp Programmer Living in Python-Land". Use this skill for writing Hy code that accesses LLMs (Gemini, OpenAI, Ollama), SPARQL queries, NLP, web scraping, RAG, and more.
---

# Notes for Using AGENT Skills with Hy Book Examples

This document helps readers set up coding agent skills so that AI assistants can reference the Hy APIs and patterns from this book when generating code.

## Source code for Gemini, OpenAI, Ollama), SPARQL queries, NLP, web scraping, RAG example code

```bash
git clone https://github.com/markwatson/hy-lisp-python-book.git
```

All the Hy examples are in `source_code_for_examples` directory.  Look in ~/GITHUB/hy-lisp-python-book/source_code_for_examples/ for code to reuse.

---

## Hy Language Tutorial and Idioms

Hy is a Lisp dialect that compiles to Python's AST. It gives you Lisp's expressive, parenthesized syntax with full access to Python's ecosystem.

### Core Syntax

```hylang
;; Printing
(print "Hello from Hy!")

;; Variable assignment
(setv x 42)
(setv name "Mark")

;; Arithmetic (prefix notation)
(+ 1 2 3)       ; => 6
(* 2 (+ 3 4))   ; => 14
```

### Imports

```hylang
;; Import a module
(import os)
(import json)

;; Import specific names from a module
(import os [getenv])
(import google [genai])

;; Import with alias
(import xml.etree.ElementTree :as ET)
```

### Functions

```hylang
;; Define a function
(defn greet [name]
  "Returns a greeting string."
  (+ "Hello, " name "!"))

;; Optional / default arguments
(defn fetch [url [timeout 10] [retries 3]]
  (print f"Fetching {url} with timeout={timeout}"))

;; Keyword-only arguments (#** for **kwargs)
(defn api-call [prompt #** kwargs]
  (print prompt kwargs))

;; Anonymous functions
(list (filter (fn [x] (> x 3)) [1 2 3 4 5]))  ; => [4, 5]
```

### Control Flow

```hylang
;; if (exactly two branches)
(if (= x 1)
  (print "one")
  (print "not one"))

;; when (single branch, no else)
(when (> x 0)
  (print "positive"))

;; cond (multiple branches)
(cond
  (< x 0) (print "negative")
  (= x 0) (print "zero")
  True     (print "positive"))

;; do (group multiple expressions)
(if condition
  (do
    (print "a")
    (print "b"))
  (print "else"))
```

### Loops and Comprehensions

```hylang
;; for loop (returns None)
(for [item ["a" "b" "c"]]
  (print item))

;; while loop
(while (> x 0)
  (print x)
  (setv x (- x 1)))

;; lfor — list comprehension (returns a list)
(lfor x (range 5) (* x x))           ; => [0, 1, 4, 9, 16]
(lfor x items :if (> x 3) (* x 2))   ; => filtered

;; break / continue work inside loops
(while True
  (setv line (input "> "))
  (when (= line "quit") (break))
  (print line))
```

### Let (Local Bindings)

```hylang
(let [x 10
      y (+ x 5)]
  (print x y))   ; => 10 15
```

### Data Structures

```hylang
;; Lists
(setv fruits ["apple" "banana" "cherry"])
(get fruits 0)              ; => "apple"
(cut fruits 1 3)            ; => ["banana", "cherry"]
(.append fruits "date")

;; Dictionaries
(setv config {"host" "localhost" "port" 8080})
(get config "host")         ; => "localhost"
(.get config "missing" "default")

;; Dictionary merge (Python 3.9+)
(setv merged (| {"a" 1} {"b" 2}))

;; Tuples
(setv point #(1 2 3))

;; Sets
(setv unique #{1 2 3})
```

### String Formatting

```hylang
;; f-strings
(setv name "world")
(print f"Hello, {name}!")
(print f"Result: {(+ 1 2)}")

;; String concatenation
(+ "Hello" ", " "world")

;; .format method
(.format "Hello, {}!" name)
```

### Exception Handling

```hylang
(try
  (setv result (/ 10 0))
  (except [ZeroDivisionError]
    (print "Cannot divide by zero"))
  (except [e Exception]
    (print f"Error: {e}")))
```

### Classes

```hylang
(defclass Animal []
  (defn __init__ [self name]
    (setv self.name name))
  (defn speak [self]
    (print f"{self.name} makes a sound")))

(setv dog (Animal "Rex"))
(.speak dog)   ; => "Rex makes a sound"
```

### Python Interop Patterns

```hylang
;; Method calls use dot notation
(.upper "hello")            ; => "HELLO"
(.split "a,b,c" ",")       ; => ["a", "b", "c"]
(.join ", " ["a" "b" "c"]) ; => "a, b, c"

;; Attribute access
response.text
response.status_code

;; Keyword arguments use :keyword syntax
(requests.get url :headers headers :timeout 10)
(client.models.generate_content
  :model "gemini-2.5-flash"
  :contents prompt
  :config {"tools" [{"google_search" {}}]})

;; Context managers
(with [f (open "file.txt" "r")]
  (print (.read f)))

;; Unpacking with #* and #**
(defn func [a b #* args #** kwargs] ...)
(func 1 2 #* extra-args #** extra-kwargs)
```

### Naming Conventions

- Hy uses **kebab-case**: `get-web-page`, `parse-selections`
- These automatically map to Python's **snake_case**: `get_web_page`, `parse_selections`
- When importing Hy modules from Python (or vice versa), use the snake_case form

---

# Hy Book APIs — Quick Reference

Knowledge of public APIs and usage patterns for the Hy examples in Mark Watson's book *A Lisp Programmer Living in Python-Land*.

## Project Setup

All examples use **uv** for dependency management. Each example directory has its own `pyproject.toml`:

```bash
cd source_code_for_examples/<example_name>
uv sync
uv run hy <script>.hy
```

---

## google-gemini

**Directory:** `google-gemini/`
**Deps:** `google-genai>=1.31.0`, `hy>=1.1.0`, `requests>=2.32.4`
**Env var:** `GOOGLE_API_KEY`
**Model:** `gemini-2.5-flash`

### Scripts and APIs

- **`web_search.hy`** — Web search via Gemini's `google_search` tool using the SDK.
  - `(web-search query)` — Returns text response grounded by live web search.

- **`context_url.hy`** — Answer questions about a web page using Gemini's `url_context` tool.
  - `(context_qa prompt)` — Prompt should contain a URL and a question. Returns text response.

- **`chat.hy`** — Multi-turn chat using direct HTTP requests to the Gemini REST API.
  - `(call-gemini chat-history user-input)` — Sends chat history + new input, returns JSON response.
  - Maintains `chat-history` list between turns.

- **`gemini_interactions_api.hy`** — Demonstrates Gemini Interactions API with custom function tools + Google Search.

### Examples

```hylang
;; Web search
(import google [genai])
(setv client (genai.Client))
(setv response
  (client.models.generate_content
    :model "gemini-2.5-flash"
    :contents "What is the latest news about Mars?"
    :config {"tools" [{"google_search" {}}]}))
(print response.text)

;; URL context
(setv response
  (client.models.generate_content
    :model "gemini-2.5-flash"
    :contents "https://markwatson.com What does Mark Watson write about?"
    :config {"tools" [{"url_context" {}}]}))
(print response.text)
```

---

## knowledge_base_navigator

**Directory:** `knowledge_base_navigator/`
**Deps:** `google-genai>=1.31.0`, `hy>=1.1.0`
**Env var:** `GOOGLE_API_KEY`
**Model:** `gemini-2.5-flash`

### API

- `(get-gemini-response prompt #** kwargs)` — Send prompt to Gemini with `google_search` grounding. Returns text.
- `(extract-entities user-text)` — Ask Gemini to identify encyclopedic entities. Returns numbered list text.
- `(parse-selections selection-line)` — Parse space/comma-separated numbers into list of ints.
- `(get-entity-details entity-list-text indices)` — Get detailed facts and relationships for selected entities.
- `(kbn-ui)` — Interactive REPL loop for entity exploration.

### Example

```hylang
(import knowledge_base_navigator [get-gemini-response extract-entities])
(print (extract-entities "Steve Jobs and Apple"))
```

---

## openai_apis

**Directory:** `openai_apis/`
**Deps:** `openai`, `hy>=1.1.0`
**Env var:** `OPENAI_KEY`
**Model:** `gpt-5`

### API

- `(completion query)` — Send a chat completion request. Returns a Choice object with `.message.content`.

### Example

```hylang
(import openai)
(setv client (openai.OpenAI))
(setv result
  (client.chat.completions.create
    :model "gpt-5"
    :messages [{"role" "user" "content" "Explain recursion briefly"}]))
(print (. (get result.choices 0) message content))
```

---

## ollama_examples

**Directory:** `ollama_examples/`
**Deps:** `ollama`, `hy>=1.1.0`, `httpx`, `markdownify`
**Env var:** `OLLAMA_API_KEY` (cloud only)
**Models:** `nemotron-3-nano:4b` (local), `gpt-oss:20b` (cloud)

### Scripts and APIs

- **`completion_local.hy`** — Local Ollama completion.
  - `(completion prompt)` — Returns text response from local Ollama.

- **`completion_cloud.hy`** — Ollama Cloud completion.
  - `(completion prompt)` — Returns text response from Ollama Cloud API.

- **`tools.hy`** — Tool functions for Ollama tool-calling:
  - `(list-directory)` — List files in current directory.
  - `(read-file-contents file-path)` — Read a file's contents.
  - `(uri-to-markdown uri)` — Fetch a URI and convert HTML to markdown.
  - `(write-file-contents file-path content)` — Write content to a file.
  - `(get-current-datetime)` — Get current date/time string.
  - `(get-weather location)` — Fetch weather for a location.
  - `(search-wikipedia query)` — Get Wikipedia summary for a topic.
  - `(get-npr-news)` — Fetch top NPR news headlines.

- **`ollama_tools_examples.hy`** — Interactive menu to test tool-calling with any available model.

### Examples

```hylang
;; Local completion
(import ollama)
(setv response
  (ollama.chat :model "nemotron-3-nano:4b"
    :messages [{"role" "user" "content" "What is Hy?"}]))
(print response.message.content)

;; Cloud completion
(import ollama [Client])
(setv client
  (Client :host "https://ollama.com"
    :headers {"Authorization" (.get os.environ "OLLAMA_API_KEY")}))
(setv response
  (client.chat "gpt-oss:20b"
    :messages [{"role" "user" "content" "What is Hy?"}]
    :stream False))
(print (get (get response "message") "content"))
```

---

## brave_search

**Directory:** `brave_search/`
**Deps:** `requests`, `hy>=1.1.0`
**Env var:** `BRAVE_SEARCH_API_KEY`

### API

- `(brave_search query)` — Search the web via Brave Search API. Returns list of `[title url description]` triples.

### Example

```hylang
(import brave [brave_search])
(setv results (brave_search "Hy programming language"))
(for [r results] (print (get r 0) (get r 1)))
```

---

## perplexity_search_llm

**Directory:** `perplexity_search_llm/`
**Deps:** `openai`, `hy>=1.1.0`
**Env var:** `PERPLEXITY_API_KEY`
**Model:** `sonar`

### API

- `(search_llm query)` — Search + LLM answer via Perplexity API (uses OpenAI-compatible endpoint). Returns text.

### Example

```hylang
(import search_llm [search_llm])
(print (search_llm "What is the Hy programming language?"))
```

---

## nlp

**Directory:** `nlp/`
**Deps:** `spacy`, `hy>=1.1.0`
**Requires:** `uv run python -m spacy download en_core_web_sm`

### API

- `(nlp some-text)` — Extract named entities from text using spaCy. Returns a JSON dict with `"entities"` key containing `[text label]` pairs.

### Example

```hylang
(import nlp_lib [nlp])
(setv result (nlp "President Bush went to San Diego to meet Ms Jones at Google"))
(print (get result "entities"))
;; => [["Bush", "PERSON"], ["San Diego", "GPE"], ["Jones", "PERSON"], ["Google", "ORG"]]
```

---

## kgn (Knowledge Graph Navigator)

**Directory:** `kgn/`
**Deps:** `spacy`, `requests`, `hy>=1.1.0`
**Requires:** `uv run python -m spacy download en_core_web_sm`

### Key Modules

- **`sparql.hy`** — SPARQL query helpers:
  - `(dbpedia-sparql query)` — Execute SPARQL query on DBpedia. Returns list of bindings.
  - `(wikidata-sparql query)` — Execute SPARQL query on Wikidata. Returns list of bindings.

- **`kgnutils.hy`** — Entity lookup:
  - `(dbpedia-get-entities-by-name name dbpedia-type)` — Search DBpedia for entities by name and type URI.

- **`kgn.hy`** — Main interactive application:
  - `(entities-in-text s)` — Extract named entities from text using spaCy. Returns dict of `{type [names]}`.
  - `(kgn)` — Interactive loop: enter entities → search DBpedia → select → discover relationships.

### Example

```hylang
(import sparql [dbpedia-sparql])
(print (dbpedia-sparql "select ?s ?p ?o { ?s ?p ?o } limit 1"))
```

---

## kgcreator

**Directory:** `kgcreator/`
**Deps:** `spacy`, `hy>=1.1.0`
**Requires:** `uv run python -m spacy download en_core_web_sm`

### API

- `(find-entities-in-text some-text)` — Extract named entities using spaCy. Returns list of `[text label]` pairs.
- `(data2Rdf meta-data entities fout)` — Write RDF triples to an output file stream.
- `(process-directory directory-name output-rdf)` — Process all `.txt` files in a directory, creating RDF output.

### Example

```hylang
(import kgcreator [find-entities-in-text])
(print (list (find-entities-in-text "Bill Gates founded Microsoft in Redmond")))
```

---

## datastores

**Directory:** `datastores/`
**Deps:** `sqlite3` (stdlib), `psycopg2` (for PostgreSQL), `hy>=1.1.0`

### SQLite API (`sqlite_lib.hy`)

- `(create-db db-file-path)` — Create a SQLite database file.
- `(connection db-file-path)` — Open and return a database connection.
- `(query conn sql #* args)` — Execute SQL query with optional bindings. Returns all rows.

### PostgreSQL API (`postgres_lib.hy`)

- `(connection-and-cursor dbname username)` — Connect and return `[connection cursor]`.
- `(query cursor sql [variable-bindings None])` — Execute a SQL query with optional bindings.

### Example

```hylang
(import sqlite_lib [connection query])
(setv conn (connection ":memory:"))
(query conn "CREATE TABLE test (id INTEGER, name TEXT)")
(query conn "INSERT INTO test VALUES (?, ?)" [1 "hello"])
(print (query conn "SELECT * FROM test"))
```

---

## webscraping

**Directory:** `webscraping/`
**Deps:** `beautifulsoup4`, `hy>=1.1.0`

### API (`get_web_page.hy`)

- `(get-raw-data-from-web aUri [anAgent ...])` — Fetch raw HTML data from a URL.
- `(get-web-page-from-disk filePath)` — Read an HTML file from disk.

### Example

```hylang
(import get_web_page [get-raw-data-from-web])
(print (get-raw-data-from-web "https://markwatson.com"))
```

---

## agents_agno

**Directory:** `agents_agno/`
**Deps:** `agno`, `requests`, `beautifulsoup4`, `ollama`, `hy>=1.1.0`
**Server:** Requires Ollama running locally with `qwen3:30b`

### API

- `scrape-website-content` — Agno `@tool`-decorated function: scrapes a URL and returns clean text.
- `scraper-agent` — Pre-configured Agno `Agent` that scrapes a URL and answers questions about its content.

### Example

```hylang
(import web_site_qa [scraper-agent])
(.print-response scraper-agent
  "Using https://markwatson.com what does Mark Watson do?"
  :stream True)
```

---

## RAG_zvec

**Directory:** `RAG_zvec/`
**Deps:** `zvec`, `hy>=1.1.0`
**Server:** Requires Ollama running locally
**Models:** `embeddinggemma` (embeddings), `qwen3:1.7b` (chat)

### API (`app.hy`)

- `(get-embedding text)` — Get embedding vector from Ollama.
- `(chunk-text text [chunk-size 500] [overlap 50])` — Split text into overlapping chunks.
- `(build-index)` — Index all `.txt` files from `../data/` into a zvec collection.
- `(search collection query [topk 5])` — Search the zvec collection for relevant chunks.
- `(ask-ollama question context-chunks)` — RAG: send retrieved chunks + question to Ollama.
- `(main)` — Interactive RAG chat loop.

### Example

```bash
uv sync
uv run hy app.hy
# Then interactively ask questions about the indexed documents
```

---

## langchain_examples

**Directory:** `langchain_examples/`
**Deps:** `langchain`, `langchain-openai`, `langchain-community`, `chromadb`, `hy>=1.1.0`
**Env var:** `OPENAI_API_KEY`

### Scripts

- **`doc_search.hy`** — Load `.txt` documents, create Chroma vector store, query with LangChain.
- **`country_information.hy`** — LangChain prompt templates for country information.
- **`directions_template.hy`** — LangChain prompt templates for directions.

### Example

```hylang
;; Vector search over documents
(import langchain_community.vectorstores [Chroma])
(import langchain_openai.embeddings [OpenAIEmbeddings])
(setv docsearch (Chroma.from_documents texts (OpenAIEmbeddings)))
```

---

## General Notes

- All examples use **uv** for dependency management; each has its own `pyproject.toml`.
- Hy seamlessly imports any Python library — use `(import module [function])` syntax.
- Environment variables must be set before use: `GOOGLE_API_KEY`, `OPENAI_KEY`, `BRAVE_SEARCH_API_KEY`, `PERPLEXITY_API_KEY`, `OLLAMA_API_KEY` (cloud only).
- The `HY_LLM_SYSTEM_PROMPT.txt` file in this directory provides a Hy syntax reference prompt for LLMs.
- Hy uses kebab-case for function names (e.g., `get-web-page`) which maps to Python's snake_case (`get_web_page`).
- Use `:keyword value` syntax for Python keyword arguments.
- Use `#** kwargs` for collecting arbitrary keyword arguments.
- Use `(lfor x collection (expr x))` for list comprehensions.
