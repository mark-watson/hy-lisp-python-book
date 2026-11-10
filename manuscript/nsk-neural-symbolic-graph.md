# NSK: A Neural-Symbolic Knowledge Graph Engine

This chapter builds NSK, a small knowledge graph database that joins two kinds of reasoning. The symbolic side stores facts as triples, answers queries by unification, and derives new facts with rules. The neural side asks a local language model, served by Ollama, when a query has no symbolic answer. Every answer says which of the two sides produced it.

This example is a Hy version of the Common Lisp NSK example in my book *Loving Common Lisp, The Savvy Programmer's Secret Weapon*. The Hy version keeps the same design and adds rules, provenance tracking, a third index, log repair, and a larger REST API.

The code for this chapter is in the directory **source_code_for_examples/nsk-neural-symbolic-graph**.

## Project Overview

```
nsk-neural-symbolic-graph/
├── nsk/
│   ├── __init__.hy    ← Public names and the ask / rule macros
│   ├── terms.hy       ← Logic variables, neural predicates, unification
│   ├── store.hy       ← Triplestore, indices, append-only log
│   ├── neural.hy      ← Ollama client, inference, text-to-triples
│   ├── query.hy       ← Pattern matching, rules, neural fallback, macros
│   ├── repl.hy        ← Interactive prompt
│   ├── server.hy      ← REST server (standard library only)
│   └── __main__.hy    ← Command-line entry point
├── demo.hy            ← Guided tour that prints its results
├── test_nsk.hy        ← Tests (pytest)
└── pyproject.toml     ← Dependencies: hy, ollama, pytest
```

Run the guided tour, the REPL, and the tests like this:

```bash
uv sync
uv run hy demo.hy        # guided tour
uv run hy -m nsk         # interactive REPL
uv run pytest            # 52 tests, no Ollama needed
```

The neural features need Ollama running locally with the **qwen3.5:4b** model. Everything else works with no Ollama daemon. A neural query then prints a short note and returns no solutions.

## A First Session

Here is a short REPL session. We add two facts, run a query, join two patterns, add a rule, and then ask a question that only the model can answer:

```
$ uv run hy -m nsk --memory
NSK: Neural-Symbolic Knowledge Graph Engine
Type :help for commands, :quit to exit.
nsk> (:add :mark :wrote :nsk)
added [:mark :wrote :nsk]
nsk> (:add :mark :codes-in :lisp)
added [:mark :codes-in :lisp]
nsk> [?who :wrote :nsk]
who=:mark
nsk> [?a :wrote :nsk] [?a :codes-in ?lang]
a=:mark, lang=:lisp
nsk> (:rule [?x :author ?y] [?y :wrote ?x])
rule added: [?x :author ?y] <- [?y :wrote ?x]
nsk> [:nsk :author ?who]
who=:mark    ; rule: [:nsk :author :mark]
nsk> [?city ~:capital-of :italy]
city=:rome    ; neural: [:rome :capital-of :italy]
nsk> :facts
  [:mark :wrote :nsk]
  [:mark :codes-in :lisp]
  [:rome :capital-of :italy]    ; neural
  [:nsk :author :mark]    ; rule
(4 triples)
nsk> :quit
Bye.
```

The query language has four parts:

| You write | Meaning |
| --- | --- |
| `:mark`, `"text"`, `42` | a term: a keyword, a string, or a number |
| `?person` | a logic variable |
| `[?p :wrote :nsk]` | a triple pattern |
| `~:codes-in` | a neural predicate: ask the model if no stored triple matches |

A note such as **; neural: ...** or **; rule: ...** after an answer names the triples behind it that are not plain facts. An answer with no note rests on asserted facts alone.

## Terms and Unification: terms.hy

The Common Lisp version installs three reader macros to get the `?var`, `[s p o]`, and `~pred` syntax. Hy needs none. The Hy reader already reads `?person` as a symbol, `[s p o]` as a list, and `~x` as the form `(unquote x)`. We only need to give those forms a meaning.

Two small classes carry that meaning at run time:

```hy
(defclass [(dataclass :frozen True)] Var []
  "A logic variable. Two variables with the same name are equal."
  #^ str name
  (defn __repr__ [self] (+ "?" self.name)))

(defclass [(dataclass :frozen True)] Neural []
  "A predicate that falls back to the language model when no fact matches."
  #^ object name
  (defn __repr__ [self] (+ "~" (show self.name))))
```

A frozen dataclass gives us equality and hashing by name, so we can use a `Var` as a dict key.

### Unification

Unification finds the variable bindings that make two terms equal. An environment is a dict that maps each bound `Var` to its value. The algorithm follows Peter Norvig's version in *Paradigms of Artificial Intelligence Programming*:

```hy
(defn walk [x env]
  "Follow variable bindings in env until x is a value or an unbound variable."
  (while (and (isinstance x Var) (in x env))
    (setv x (get env x)))
  x)

(defn unify [x y [env {}]]
  "Unify x with y under env. Return the extended environment, or None."
  (when (is env None)
    (return None))
  (setv x (walk x env)
        y (walk y env))
  (cond
    (= x y) env
    (isinstance x Var) {#** env  x y}
    (isinstance y Var) {#** env  y x}
    (and (isinstance x #(list tuple)) (isinstance y #(list tuple))
         (= (len x) (len y)))
      (do
        (for [[a b] (zip x y)]
          (setv env (unify a b env)))
        env)
    True None))
```

Two design choices matter here. First, `None` means failure and the empty dict means success with no bindings, so callers must test with `(is env None)` and not with truthiness. Second, `unify` never changes an environment. The form `{#** env  x y}` builds a new dict. The query engine uses generators, and one generator may still be walking a branch of the search while another extends it, so shared mutable state would cause errors.

For example, unifying the pattern `[?s :wrote ?o]` with the triple `[:mark :wrote :nsk]` returns the environment `{?s :mark, ?o :nsk}`.

### From Hy Forms to Terms

The REPL and the log replay both receive forms from the Hy reader. The function `to-term` converts one form to a term and never evaluates it:

```hy
(defn to-term [form]
  "Convert one form produced by the Hy reader into a term, without evaluating
  it. The REPL and the log replay use this, so neither can run code."
  (cond
    (isinstance form Keyword) (Keyword form.name)
    (var-symbol? form) (Var (cut (str form) 1 None))
    (unquote? form) (Neural (to-term (get form 1)))
    (isinstance form String) (str form)
    (isinstance form Integer) (int form)
    (isinstance form Float) (float form)
    (isinstance form Symbol)
      (raise (ValueError f"{form} is not a term; did you mean :{form} or ?{form}"))
    True (raise (ValueError f"not a term: {(hy.repr form)}"))))
```

The conversion of `String` to `str` is needed because a `hy.models.String` does not compare equal to a plain Python string with the same text.

## The Triplestore: store.hy

A triple is a tuple of subject, predicate, and object. The `Graph` class keeps every triple in a dict that maps the triple to its source, plus three indices:

```hy
(defn __init__ [self [path None]]
    (setv self.triples {}        ; triple -> source, in insertion order
          self.spo {}            ; subject   -> {triple: None}
          self.pos {}            ; predicate -> {triple: None}
          self.osp {}            ; object    -> {triple: None}
          self.rules []          ; [(head, body) ...]
          self.stale False       ; True when rule-derived triples are out of date
          self.lock (threading.RLock)
          self.path (if path (str path) None)
          self.log None)
    (when self.path
      (setv torn (and (os.path.exists self.path) (self._replay)))
      (setv self.log (open self.path "a" :encoding "utf-8"))
      (when torn
        (self.compact)))     ; rewrite the log without the torn entry
    None)                    ; Hy returns the last form; __init__ must not
```

The last line shows a Hy detail. A Hy function returns the value of its last form. Python raises a `TypeError` when `__init__` returns anything other than `None`, so the method ends with an explicit `None`.

Each index bucket is a dict used as an ordered set. Python dicts keep insertion order, and removing a key costs `O(1)`$ on average. The Common Lisp version stores each bucket as a list, so removal there costs `O(n)`$ in the size of the bucket.

### Choosing an Index

To match a pattern we first fetch the triples that could match. Each concrete term in the pattern selects one bucket, and we scan the smallest one:

```hy
(defn candidates [self pattern]
    "Return the triples that could match pattern, using the smallest bucket
    among the positions that hold a concrete term."
    (setv buckets (lfor [index term] (zip #(self.spo self.pos self.osp) pattern)
                        :if (not (isinstance term #(Var Neural)))
                        (.get index term {})))
    (list (if buckets (min buckets :key len) self.triples)))
```

For the pattern `[?who :wrote :nsk]` the store compares the `:wrote` bucket with the `:nsk` bucket and scans the smaller of the two. A pattern with three variables scans every triple.

### Sources

Every triple records where it came from:

- **fact**: you asserted it.
- **neural**: the language model inferred it.
- **rule**: a rule derived it.

The sources have a rank. Adding a triple that is already present changes the graph only when the new source is stronger:

```hy
(setv RANK {"rule" 0  "neural" 1  "fact" 2})

(defn add [self triple [source "fact"]]
    "Add a triple. Return True when the graph changed. Adding a triple that is
    already present only matters when the new source is stronger, as when you
    assert something the model had guessed."
    (setv triple (check-triple triple))
    (with [self.lock]
      (setv old (.get self.triples triple))
      (when (and old (>= (get RANK old) (get RANK source)))
        (return False))
      (self._put triple source)
      (when (!= source "rule")
        (setv self.stale True)
        (self._log (if (= source "neural") "infer" "add") #* triple))
      True))
```

So if the model guesses `[:mark :codes-in :lisp]` and you later assert the same triple, it becomes a fact.

Notice that `add` takes the triple as one list argument. In a Hy function call, a keyword names a keyword argument, so `(graph.add :mark :wrote :nsk)` does not compile. We pass triples as lists: `(graph.add [:mark :wrote :nsk])`. To pass a single keyword to a function, quote it: `(to-term ':mark)`.

### The Log

Every change appends one s-expression to the log file and flushes it:

```
(:add :mark :wrote :nsk)
(:add :mark :likes "hiking in Sedona")
(:add :mark :wrote :a-typo)
(:del :mark :wrote :a-typo)
(:rule [?book :author ?who] [?who :wrote ?book])
```

On startup the store reads the log with the Hy reader and replays it:

```hy
(defn _replay [self]
    "Rebuild the graph from the log. Return True when the log ends in a torn
    entry, which is what a crash in the middle of a write leaves behind."
    (with [f (open self.path :encoding "utf-8")]
      (setv text (.read f)))
    (setv torn False)
    (try
      (for [form (hy.read-many text)]
        (self._apply form))
      (except [hy.PrematureEndOfInput]
        (print f"; {self.path}: dropped an incomplete final entry" :file sys.stderr)
        (setv torn True)))
    (setv self.stale (bool self.rules))
    torn)
```

Three properties of this design are worth noting:

- The Hy reader parses forms and never evaluates them, and `_apply` converts each argument with `to-term`. A log file cannot run code. A test checks this with a log entry that holds a `print` call.
- If a crash leaves an incomplete final entry, the reader raises `hy.PrematureEndOfInput`. The store keeps what it read, then rewrites the log so that later entries do not land after the broken one.
- The store does not log triples that rules derive. It rebuilds them from the rules.

The log grows with every change. The `compact` method rewrites it to hold only the live state. It writes a temporary file and then calls `os.replace`, which swaps the files in one step, so a crash leaves either the old log or the new one.

## The Query Engine: query.hy

A query is a list of patterns that must all hold. The engine proves them left to right. Each pattern yields one environment for each way it can match, and the next pattern continues from that environment.

```hy
(defn match-pattern [pattern env graph [use-model True]]
  "Yield (env, support) for every way pattern holds under env. A ~ predicate
  is matched symbolically first and sent to the model only when that fails."
  (setv [s p o] (resolve pattern env)
        fuzzy (isinstance p Neural))
  (when fuzzy
    (setv p (walk-name p env)))
  (setv found False)
  (for [triple (graph.candidates #(s p o))]
    (setv extended (unify #(s p o) triple env))
    (when (is-not extended None)
      (setv found True
            source (.get graph.triples triple "fact"))
      (yield #(extended (if (= source "fact") #() #(#(triple source)))))))
  (when (and fuzzy use-model (not found))
    (setv triple (neural.infer s p o graph))
    (when triple
      (setv extended (unify #(s p o) triple env))
      (when (is-not extended None)
        (yield #(extended #(#(triple "neural"))))))))
```

The function yields pairs. The first item is the extended environment. The second is the support: the matched triple and its source, unless the triple is a plain fact. The model is called only for a `~` predicate, and only after the symbolic match finds nothing.

A conjunction is a short recursive generator:

```hy
(defn prove [patterns env graph [use-model True] [support #()]]
  "Yield (env, support) for every proof of the conjunction of patterns."
  (if (not patterns)
      (yield #(env support))
      (for [[extended used] (match-pattern (get patterns 0) env graph use-model)]
        (yield :from (prove (cut patterns 1 None) extended graph use-model
                            (+ support used))))))
```

The Common Lisp version builds the full list of solutions with `mapcan`. Generators compute a solution only when the caller asks for it, so a query with `:limit 1` stops after the first proof.

### Rules

A rule has a head pattern and one or more body patterns. When the body holds, the head holds. In logic notation, the recursive ancestor rule reads:

```$
\mathit{ancestor}(x, z) \leftarrow \mathit{parent}(x, y) \wedge \mathit{ancestor}(y, z)
```

NSK runs rules forward. Let `T_0`$ be the set of stored triples and let `\theta`$ stand for a set of variable bindings. Each pass adds the head of every rule under every binding that proves its body:

```$
T_{i+1} = T_i \cup \{\, \mathit{head}\,\theta \;:\; \mathit{body}\,\theta \subseteq T_i \,\}
```

The passes stop when `T_{i+1} = T_i`$. This always happens, because rules cannot create new terms and so the set of possible triples is finite.

```hy
(defn saturate [graph]
  "Bring the rule-derived triples up to date."
  (when (not graph.stale)
    (return))
  (for [[triple _] (graph.facts "rule")]
    (graph.remove triple))
  (setv changed (bool graph.rules))
  (while changed
    (setv changed False)
    (for [[head body] graph.rules]
      (for [[env _] (list (prove body {} graph :use-model False))]
        (setv triple (resolve head env))
        (when (and (ground? triple) (graph.add triple "rule"))
          (setv changed True)))))
  (setv graph.stale False))
```

The graph sets its `stale` flag whenever a fact or a rule changes. The next query calls `saturate`, which drops the old derived triples and computes them again. This is simple and correct, and it is fast enough for small graphs. A large graph would need an incremental method. The call `(list (prove ...))` collects the proofs before the loop adds triples, so the loop never changes an index while a generator reads it. Rules pass `:use-model False`, so they never call the model.

Because derived triples are stored and indexed like any other triple, a recursive rule needs no special handling at query time.

### The ask Macro

In your own code you query with the `ask` macro:

```hy
(import nsk [Graph use-graph])
(require nsk [ask rule])

(setv graph (use-graph (Graph)))          ; or (Graph "my-graph.log")
(graph.add-all [[:mark :wrote :nsk]
                [:mark :codes-in :lisp]])

(setv result (ask [?author ?lang]
               [?author :wrote :nsk]
               [?author ~:codes-in ?lang]))

(print result)                 ; author=:mark, lang=:lisp
(for [row result]              ; each row is a dict keyed by variable name
  (print (get row "author")))
```

The macro rewrites each pattern into code that builds a tuple. The helper `compile-term` does the work:

```hy
(defn compile-term [form]
  "Macro helper. Like to-term, but it returns code: ?x and ~p are rewritten and
  everything else is left for Hy to evaluate, so a pattern can mention ordinary
  variables and function calls."
  (cond
    (var-symbol? form) `(hy.I.nsk/terms.Var ~(cut (str form) 1 None))
    (unquote? form) `(hy.I.nsk/terms.Neural ~(compile-term (get form 1)))
    ;; A bare keyword in a call would be read as a keyword argument, so quote it.
    (isinstance form Keyword) `(quote ~form)
    True form))
```

Only `?variables` and `~predicates` are special. Hy evaluates everything else in a pattern, so a pattern can use local variables:

```hy
(for [language [:lisp :python :cobol]]
  (setv coders (ask [?who] [?who :codes-in language]))
  (print (show language) "->" (show (.column coders "who"))))
```

```
:lisp -> [:mark]
:python -> [:jane]
:cobol -> []
```

The expansion refers to `Var` through `hy.I.nsk/terms.Var`. The `hy.I` form imports a module where it is used, so the macro works in a file that has not imported `Var` itself.

```hy
(defmacro ask [select #* body]
  (setv [patterns options] (hy.I.nsk/query.split-options body))
  `(hy.I.nsk/query.run-query
     [~@(map hy.I.nsk/terms.compile-pattern patterns)]
     [~@(map hy.I.nsk/terms.compile-term select)]
     ~@options))
```

Options follow the patterns: `:graph g` queries a graph other than the default, `:limit n` stops after `n` solutions, and `:neural False` keeps the model out of this query.

Here is the rules section of **demo.hy** and its output:

```hy
(graph.add-all [[:ann :parent :bob] [:bob :parent :cy] [:cy :parent :di]])

(rule [?x :ancestor ?y]  [?x :parent ?y])
(rule [?x :ancestor ?z]  [?x :parent ?y] [?y :ancestor ?z])

(print (ask [?d] [:ann :ancestor ?d]))

(graph.remove [:bob :parent :cy])
(print (ask [?d] [:ann :ancestor ?d]))
```

```
d=:bob    ; rule: [:ann :ancestor :bob]
d=:cy    ; rule: [:ann :ancestor :cy]
d=:di    ; rule: [:ann :ancestor :di]
d=:bob    ; rule: [:ann :ancestor :bob]
```

After we remove the fact that links Bob to Cy, the derived triples for Cy and Di are gone.

## The Neural Layer: neural.hy

The model does two jobs. It completes a triple when a `~` predicate finds no symbolic match, and it turns free text into triples.

One function talks to Ollama:

```hy
(defn chat-json [system prompt schema]
  "Send one request to the model and return its reply as a dict. This is the
  only function that touches the network; the tests replace it with a fake."
  (import ollama)
  (setv client (ollama.Client :host (get config "host")
                              :timeout (get config "timeout"))
        response (client.chat
                   :model (get config "model")
                   :messages [{"role" "system"  "content" system}
                              {"role" "user"  "content" prompt}]
                   :format schema
                   :think (get config "think")
                   :options {"temperature" 0}))
  (or (extract-json response.message.content) {}))
```

Three arguments shape the reply. The `:format` argument passes a JSON schema, and Ollama constrains the output to that schema. The `:think` argument is `False` by default, which skips the reasoning phase of a thinking model such as qwen3.5. On my laptop a call then takes one to three seconds. A temperature of 0 makes the answers repeatable.

The `import` sits inside the function. The symbolic engine therefore loads and runs even when the `ollama` package is missing.

### Fallback Inference

The schema for inference allows a string or `null`:

```hy
(setv INFER-SCHEMA
  {"type" "object"
   "properties" {"result" {"type" ["string" "null"]}}
   "required" ["result"]})
```

The `infer` function handles a pattern that is missing its subject or its object, but not both. It builds a prompt from the facts the graph already holds about the known term. For the query `[:jane ~:codes-in ?l]` on a graph that knows Jane wrote NSK, the prompt is:

```
Known facts:
jane wrote nsk

Complete this triple: jane codes-in ???
```

The rest of `infer` deals with answers and failures:

- It records each question and its answer in a `memo` dict, so a join never asks the same question twice. This includes the answer "unknown".
- It converts the model's text to a keyword with `to-keyword`, so "Common Lisp" becomes `:common-lisp`.
- When `(get config "cache")` is true, it stores the completed triple in the graph with the source **neural**. Later queries find it by a normal symbolic match and still report it as inferred.
- When the call fails, it prints one note and skips further calls for five seconds. A join over many rows then does not try a dead daemon once per row.

Here is the neural section of the demo. No `:capital-of` facts are stored, so the model supplies them:

```hy
(graph.add-all [[:mark :visited :france] [:mark :visited :japan]])
(print (ask [?country ?capital]
            [:mark :visited ?country]
            [?capital ~:capital-of ?country]))
```

```
country=:france, capital=:paris    ; neural: [:paris :capital-of :france]
country=:japan, capital=:tokyo    ; neural: [:tokyo :capital-of :japan]
```

A small model will sometimes guess wrong. In one test run, the model answered `[:jane ~:codes-in ?l]` with `:nsk`, because the only fact it saw about Jane was that she wrote NSK. This is the reason for the labels. Treat a **neural** answer as a suggestion to check. The REPL command `:forget` removes every inferred triple.

### Text Ingestion

The function `text-to-triples` sends free text to the model with a schema for a list of triples, converts each name to a keyword, and drops rows with missing fields and repeats. The REPL command `(:ingest "text")` and the `POST /ingest` route both use it. Given the text "Jane Doe wrote a book about Python. She lives in Oslo." the model returned:

```
[:jane-doe :wrote :book]
[:book :about :python]
[:jane-doe :lives :oslo]
```

## The REPL: repl.hy

The REPL reads each line with `hy.read-many` and sorts the forms into three kinds:

- A command such as `:facts` or `(:add :mark :wrote :nsk)`.
- One or more bare patterns, which form a query. Patterns on the same line are joined.
- Anything else, which is ordinary Hy.

The REPL converts commands and bare patterns with `to-term` and never evaluates them. That is why `(:add :mark :wrote :nsk)` works at the prompt even though Hy code cannot pass keywords that way.

For ordinary Hy forms the REPL builds a module, loads the macros into it, and evaluates each form there:

```hy
(defn make-namespace [graph]
  "Build the module that ordinary Hy forms are evaluated in."
  (setv module (types.ModuleType "nsk_repl"))
  (hy.eval '(do (require nsk [ask rule])
                (import nsk)
                (import nsk [Graph Var Neural show run-query]))
           :module module)
  (setv module.graph graph)
  module)
```

You can therefore mix queries with normal code at the prompt:

```
nsk> (setv n (len graph))
nsk> (+ n 40)
=> 43
nsk> (ask [?a] [?a :wrote :nsk] :limit 1)
a=:mark
```

When a line ends in the middle of a form, `hy.read-many` raises `hy.PrematureEndOfInput`. The loop catches it, shows the prompt `...>`, and reads another line. Python's `readline` module supplies history and line editing, so the REPL needs no wrapper such as `rlwrap`.

Type `:help` at the prompt for the full command list. It includes `:rules`, `(:unrule n)`, `:forget`, `:compact`, and `(:model "name")`.

## The REST Server: server.hy

The server uses only `http.server` from the Python standard library. Start it with:

```bash
uv run hy -m nsk --serve --port 8800
```

| Request | Body | Effect |
| --- | --- | --- |
| `GET /health` | | counts and model name |
| `GET /triples` | | every triple with its source |
| `POST /triples` | `{"subject": .., "predicate": .., "object": ..}` | add a triple |
| `DELETE /triples` | `{"subject": .., "predicate": .., "object": ..}` | remove a triple |
| `POST /query` | `{"subject": .., "predicate": .., "object": ..}` | run one pattern |
| `POST /ask` | `{"select": ["?a"], "where": [[s, p, o], ...]}` | run a join |
| `POST /ingest` | `{"text": ".."}` | extract and add triples |

In JSON, a term is a string. The string `"?name"` is a variable, a predicate written `"~name"` is neural, and any other string becomes a keyword. In `/query`, a field that is `null` or missing is a variable named after the field.

```bash
curl -s localhost:8800/ask \
  -d '{"select": ["?who", "?city"],
       "where": [["?who", "wrote", "nsk"], ["?city", "~capital-of", "france"]]}'
```

```json
{"count": 1,
 "results": [{"who": "mark", "city": "paris"}],
 "provenance": [{"triple": ["paris", "capital-of", "france"], "source": "neural"}]}
```

All routing lives in one function, `handle`, that takes a graph, a method, a path, and a parsed body, and returns a status and a payload. It does no I/O, so most server tests call it directly. The handler class is then small. One method serves all three HTTP verbs:

```hy
(setv do-GET respond
        do-POST respond
        do-DELETE respond)
```

Hy turns the name `do-GET` into `do_GET`, which is the method name that `BaseHTTPRequestHandler` looks for.

The server listens on 127.0.0.1 unless you pass `--host`. It has no authentication, so do not expose it to a network you do not trust.

## Testing Without a Model

The tests are in **test_nsk.hy** and run with `uv run pytest`. They need no Ollama daemon, because they replace `chat-json` with a fake that returns canned replies:

```hy
(defn fake-model [monkeypatch replies]
  "Replace the model. replies maps a substring of the prompt to a reply dict.
  Returns the list of prompts received."
  (setv prompts [])
  (defn fake-chat-json [system prompt schema]
    (.append prompts prompt)
    (for [[fragment reply] (.items replies)]
      (when (in fragment prompt)
        (return reply)))
    {"result" None})
  (monkeypatch.setattr nsk.neural "chat_json" fake-chat-json)
  prompts)
```

The fake returns the list of prompts it received, so a test can check both the answer and how often the engine asked:

```hy
(defn test-neural-fallback-inside-a-join [monkeypatch]
  (setv prompts (fake-model monkeypatch {"jane codes-in" {"result" "python"}}))
  (use-graph (authors-graph))
  (setv result (ask [?a ?l] [?a :wrote :nsk] [?a ~:codes-in ?l]))
  (assert (= result.rows [{"a" :mark  "l" :lisp} {"a" :jane  "l" :python}]))
  (assert (= (len prompts) 1)))
```

Mark has a stored `:codes-in` fact, so only Jane's row goes to the model, and the engine asks once.

## Differences from the Common Lisp Version

| Area | Common Lisp NSK | Hy NSK |
| --- | --- | --- |
| Query syntax | three reader macros | no reader changes; one `ask` macro |
| Patterns | terms are literals | patterns can hold any Hy expression |
| Rules | none | forward-chaining rules, including recursive ones |
| Provenance | none | each triple and answer records fact, rule, or neural |
| Indices | subject and object | subject, predicate, and object |
| Search | builds all solutions with `mapcan` | generators; `:limit` stops early |
| Neural fallback | asks for a missing object | asks for a missing subject or object and sends known facts |
| Model output | finds the first JSON object in the reply | reply constrained by a JSON schema |
| Log | grows without bound | `:compact` rewrites it; a torn final entry is repaired |
| REPL | needs `rlwrap` for line editing | history and editing from `readline` |
| REST server | Hunchentoot, two routes | standard library, seven routes |
| JSON | hand-written reader and writer | Python's `json` module |

## Wrap Up

NSK shows one way to combine symbolic and neural methods in about 1,100 lines of Hy. The symbolic engine gives exact, repeatable answers from stored facts and rules. The model fills gaps, and the provenance labels keep its guesses apart from what you asserted.

Here are some ways to extend the example:

- Replace the full recomputation in `saturate` with semi-naive evaluation, which uses only the triples added in the last pass.
- Reorder the patterns of a join so that the pattern with the smallest candidate bucket runs first.
- Let the model check a triple with no variables, such as `[:paris ~:capital-of :france]`, and answer yes or no.
- Add a confidence value to each neural triple and let a query set a minimum.
