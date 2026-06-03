# Implementing a Simple RDF Datastore and SPARQL Engine in Hy

This chapter explores a Hy implementation of a basic RDF (Resource Description Framework) triple store with partial SPARQL query support. This project is a direct pedagogical port of the Common Lisp triple store from *Loving Common Lisp*, redesigned to leverage the unique features of Hy: Lisp's symbolic power and macro system layered over Python's built-in dictionary, list, and string data structures.

You can find the complete project source code in the `source_code_for_examples/rdf-datastore-with-sparql` directory.

---

## The Core Concept

In Semantic Web technologies, data is represented as a directed graph made of **triples**:

- **Subject**: The node we are describing (e.g., `"John"`).
- **Predicate**: The directed relationship/edge (e.g., `"likes"`).
- **Object**: The target node or value (e.g., `"pizza"`).

A collection of these triples forms a graph. To query this graph, we use **SPARQL**, which works by matching triple patterns containing variables (e.g., `?name likes ?food`) against the store. When a query contains multiple patterns (e.g., `?name age ?age . ?name likes ?food`), the engine must resolve a **conjunction (join)** across patterns, binding variables consistently.

---

## Example Usage

Let's look at how the datastore is used in practice before we look at its implementation. Below is the demonstration code from `main.hy`:

```hylang
;; main.hy
(import rdf_datastore [RdfStore])

(defn print-query-results [store query-string]
  "Execute a SPARQL query and pretty-print the results."
  (print f"Query: {query-string}")
  (setv results (store.execute-sparql query-string))
  (print "Results:")
  (if results
      (do
        (for [result results]
          (setv parts (lfor #(var val) (.items result)
                            f"{var}: {val}"))
          (print (+ "  " (.join ", " parts)))))
      (print "  No results"))
  (print))

(defn test []
  (setv store (RdfStore))

  ;; Add triples
  (store.add-triple "John" "age" "30")
  (store.add-triple "John" "likes" "pizza")
  (store.add-triple "Mary" "age" "25")
  (store.add-triple "Mary" "likes" "sushi")
  (store.add-triple "Bob" "age" "35")
  (store.add-triple "Bob" "likes" "burger")

  (store.print-all-triples)

  ;; Query 1: join across two patterns — find name, age, and food
  (print-query-results store
    "select * where { ?name age ?age . ?name likes ?food }")

  ;; Query 2: simple single-pattern query
  (print-query-results store
    "select ?s ?o where { ?s likes ?o }")

  ;; Query 3: join with a concrete value in second pattern
  (print-query-results store
    "select * where { ?name age ?age . ?name likes pizza }"))

(test)
```

Running the code yields the following output:

```
$ uv run hy main.hy
All triples in the datastore:
  John  age  30
  John  likes  pizza
  Mary  age  25
  Mary  likes  sushi
  Bob  age  35
  Bob  likes  burger

Query: select * where { ?name age ?age . ?name likes ?food }
Results:
  ?name: John, ?age: 30, ?food: pizza
  ?name: Mary, ?age: 25, ?food: sushi
  ?name: Bob, ?age: 35, ?food: burger

Query: select ?s ?o where { ?s likes ?o }
Results:
  ?s: John, ?o: pizza
  ?s: Mary, ?o: sushi
  ?s: Bob, ?o: burger

Query: select * where { ?name age ?age . ?name likes pizza }
Results:
  ?name: John, ?age: 30
```

---

## Walkthrough of the Hy Implementation

The implementation in `rdf_datastore.hy` is split into data representation, the datastore class, the query parser, and the recursive join execution engine.

### 1. RDF Triple Representation

Instead of defining custom structure classes like Common Lisp's `defstruct`, the Hy version maps triples directly to Python dictionaries. Accessor functions shield the query engine from this representation detail:

```hylang
(defn make-triple [subject predicate object]
  "Create an RDF triple (as a dict)."
  {"subject" subject "predicate" predicate "object" object})

(defn triple-subject [triple] (get triple "subject"))
(defn triple-predicate [triple] (get triple "predicate"))
(defn triple-object [triple] (get triple "object"))
```

Using Python dictionaries is highly idiomatic in Hy. It means we get fast lookups, serialization, and debugging outputs out of the box, while the Lisp-style syntax keeps the code readable.

---

### 2. The `RdfStore` Class

The triple store itself is implemented as a class. Defining classes in Hy uses the `defclass` macro:

```hylang
(defclass RdfStore []
  "An in-memory RDF triple store with SPARQL query support."

  (defn __init__ [self]
    (setv self.triples []))

  (defn add-triple [self subject predicate object]
    "Add a triple to the datastore."
    (.append self.triples (make-triple subject predicate object)))

  (defn remove-triple [self subject predicate object]
    "Remove all triples matching the given subject, predicate, object."
    (setv self.triples
          (lfor t self.triples
                :if (not (and (= (triple-subject t) subject)
                              (= (triple-predicate t) predicate)
                              (= (triple-object t) object)))
                t)))
```

Note how Hy's list comprehension macro `lfor` is used to filter elements in `remove-triple`.

For querying triples with wildcard patterns, we check if the pattern element is a variable (starts with `?`) or `None`, or matches the triple value:

```hylang
  (defn query-triples [self subject predicate object]
    "Return all triples matching the pattern (None or ?-vars are wildcards)."
    (lfor t self.triples
          :if (and (or (is subject None) (variable-p subject)
                       (= (triple-subject t) subject))
                   (or (is predicate None) (variable-p predicate)
                       (= (triple-predicate t) predicate))
                   (or (is object None) (variable-p object)
                       (= (triple-object t) object)))
          t))
```

---

### 3. SPARQL Variable Identification & Binding

To bind query variables, we first identify them. Variables start with the `?` character:

```hylang
(defn variable-p [s]
  "Check if a string is a SPARQL variable (starts with '?')."
  (and (isinstance s str) (> (len s) 0) (= (get s 0) "?")))
```

During query pattern matching, if a pattern component is a variable, we generate a binding mapping that variable to the corresponding element of the matching triple:

```hylang
(defn triple-to-binding [triple pattern]
  "Build a binding dict mapping variables in `pattern` to values in `triple`."
  (setv binding {})
  (when (variable-p (get pattern 0))
    (setv (get binding (get pattern 0)) (triple-subject triple)))
  (when (variable-p (get pattern 1))
    (setv (get binding (get pattern 1)) (triple-predicate triple)))
  (when (variable-p (get pattern 2))
    (setv (get binding (get pattern 2)) (triple-object triple)))
  binding)
```

We also need to apply existing bindings to a query pattern before executing subsequent parts of a join. This is implemented via a list comprehension:

```hylang
(defn apply-bindings [pattern bindings]
  "Substitute known variable bindings into a pattern."
  (lfor item pattern
        (if (and (variable-p item) (in item bindings))
            (get bindings item)
            item)))
```

Merging bindings uses Python 3.9's dictionary merge operator (`|`):

```hylang
(defn merge-bindings [b1 b2]
  "Merge two binding dicts. b2 values override b1 on conflict."
  (| (dict b1) (dict b2)))
```

---

### 4. SPARQL Parsing

Here we implement a subset of SPARQL. Our SPARQL parser extracts the variables in the `SELECT` clause and splits the `WHERE` clause patterns by dots (`.`):

```hylang
(defn parse-sparql-query [query-string]
  "Parse a simple SPARQL query: SELECT vars WHERE { patterns }
   Returns dict with 'select-vars' and 'where-patterns'."
  (setv tokens (lfor tok (.split query-string)
                     :if (not (in tok ["{" "}"]))
                     tok))
  ;; Find SELECT and WHERE positions (case-insensitive)
  (setv lower-tokens (lfor t tokens (.lower t)))
  (setv select-idx (.index lower-tokens "select"))
  (setv where-idx (.index lower-tokens "where"))
  ;; Extract SELECT vars
  (setv select-vars (cut tokens (+ select-idx 1) where-idx))
  ;; Extract WHERE clause tokens
  (setv where-tokens (cut tokens (+ where-idx 1) None))
  ;; Parse WHERE patterns (split on '.')
  (setv where-patterns (parse-where-patterns where-tokens))
  {"select-vars" select-vars "where-patterns" where-patterns})
```

> **IMPORTANT: Hy Slicing Gotcha:**
> Lisp programmers are used to `subseq` or `slice` where providing one index parameter slices from that index to the end.
> However, Hy's `(cut sequence start)` macro compiles to Python's `sequence[:start]`—slicing from the *beginning* up to the index. 
> To slice from an index to the end of the collection (i.e. `sequence[start:]`), you must pass `None` as the stop parameter:
> `(cut tokens (+ where-idx 1) None)`

To group the tokens into `[subject predicate object]` patterns, we split on the dot `.` delimiter:

```hylang
(defn parse-where-patterns [tokens]
  "Split WHERE clause tokens into patterns, delimited by '.'."
  (setv patterns [])
  (setv current [])
  (for [tok tokens]
    (if (= tok ".")
        (do
          (when current
            (.append patterns (list current))
            (setv current [])))
        (.append current tok)))
  (when current
    (.append patterns (list current)))
  patterns)
```

---

### 5. SPARQL Execution Engine (Joins)

When a query has multiple patterns (like `?name age ?age . ?name likes ?food`), the patterns must be processed sequentially. We recursively evaluate them:

1. Retrieve matching triples for the first pattern and create initial bindings.
2. For each binding, substitute the bound variables into the remaining patterns.
3. Recursively resolve the remaining patterns using the substituted values, accumulating and merging the bindings.

```hylang
(defn execute-where-patterns [store patterns]
  "Execute WHERE patterns against the store. Returns a list of binding dicts."
  (if (not patterns)
      [{}]
      (let [pattern (get patterns 0)
            remaining (cut patterns 1 None)
            matching (store.query-triples (get pattern 0)
                                          (get pattern 1)
                                          (get pattern 2))
            bindings (lfor t matching (triple-to-binding t pattern))]
        (if (not remaining)
            bindings
            (do
              (setv results [])
              (for [binding bindings]
                (setv sub-results
                      (execute-where-with-bindings store remaining binding))
                (for [sr sub-results]
                  (.append results (merge-bindings binding sr))))
              results)))))
```

When evaluating remaining patterns, we substitute the bindings found so far:

```hylang
(defn execute-where-with-bindings [store patterns bindings]
  "Execute WHERE patterns with existing variable bindings substituted."
  (if (not patterns)
      [bindings]
      (let [pattern (get patterns 0)
            remaining (cut patterns 1 None)
            bound-pattern (apply-bindings pattern bindings)
            matching (store.query-triples (get bound-pattern 0)
                                          (get bound-pattern 1)
                                          (get bound-pattern 2))
            new-bindings (lfor t matching
                               (merge-bindings bindings
                                                (triple-to-binding t pattern)))]
        (if (not remaining)
            new-bindings
            (do
              (setv results [])
              (for [nb new-bindings]
                (setv sub-results
                      (execute-where-with-bindings store remaining nb))
                (for [sr sub-results]
                  (.append results sr)))
              results)))))
```

Finally, we project only the requested variables using Hy's dictionary comprehension macro `dfor`:

```hylang
(defn project-results [results select-vars]
  "Project results to only the selected variables. '*' means all."
  (if (= select-vars ["*"])
      (lfor r results (remove-duplicate-keys r))
      (lfor r results
            (dfor var select-vars var (.get r var None)))))
```

Just like `lfor` maps to list comprehensions, `dfor` maps to dictionary comprehensions, where `(dfor key-var collection key-expression value-expression)` compiles to `{key_expression: value_expression for key_var in collection}`.

---

## Conclusion

This pedagogical implementation demonstrates the synergy between Lisp's functional/recursive patterns and Python's data structures. Implementing the resolution of conjunctive query joins is a classic Lisp programming task, made clean and concise in Hy. Rather than building custom record structures or dictionary utilities from scratch, the engine leverages Python's dictionary merge `|`, list/dictionary comprehensions, and classes.
