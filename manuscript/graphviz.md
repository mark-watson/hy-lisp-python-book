# Knowledge Graph Visualization with Hy

This chapter demonstrates a practical Hy application that parses UMLS (Unified Medical Language System) RDF triples and generates visual knowledge graphs. You'll learn how to process structured data, build command-line interfaces, and create visualizations—all using Hy's elegant Lisp syntax.

## What This Program Does

The `UMLS_graph.hy` script:

1. **Parses triple files** - Tab-separated files with subject, object, and predicate columns
2. **Builds directed graphs** - Creates visual representations of relationships
3. **Color-codes edges** - Different predicates get different colors for easy identification
4. **Generates PDF output** - Uses Graphviz for professional-quality renderings

## The Input Data Format

The program reads `.triples` files with this format:

```
subject	object	predicate
```

Example from `test.triples`:

```
steroid	eicosanoid	interacts_with
clinical_attribute	conceptual_entity	isa
neoplastic_process	disease_or_syndrome	isa
```

Each line represents a relationship: "steroid interacts_with eicosanoid", "clinical_attribute isa conceptual_entity", etc.

## Complete Annotated Source Code

```hy
#!/usr/bin/env hy
;; UMLS RDF Triple Graph Visualizer
;;
;; Renders a directed graph from tab-separated triple files (subject, object, predicate).
;;
;; Usage:
;;   hy UMLS_graph.hy [OPTIONS] [input_file]
;;
;; Options:
;;   -o, --output NAME    Output file name (default: umls_graph)
;;   -v, --view           Auto-open the generated PDF
;;   -f, --filter PRED    Filter by predicate type (e.g., interacts_with)
;;   -l, --limit N        Limit to first N triples
;;   -e, --engine ENGINE  Layout engine: dot, neato, fdp, circo (default: dot)
;;
;; Examples:
;;   hy UMLS_graph.hy test.triples
;;   hy UMLS_graph.hy -v -l 50 test.triples
;;   hy UMLS_graph.hy --filter isa --engine neato test.triples -o isa_graph

(import sys
        argparse
        graphviz [Digraph])
```

### Imports and Module Structure

The `import` statement in Hy follows Python's import semantics but with Lisp syntax:

```hy
(import sys
        argparse
        graphviz [Digraph])
```

This is equivalent to Python's:

```python
import sys
import argparse
from graphviz import Digraph
```

The square brackets `[Digraph]` extract a specific name from the `graphviz` module.

### Defining Constants with `setv`

```hy
;; Color palette for predicates (maps predicate types to colors)
(setv PREDICATE-COLORS
  {"isa" "#FF6B6B"              ; red for hierarchy
   "interacts_with" "#4ECDC4"   ; teal for interactions
   "affects" "#45B7D1"          ; blue
   "causes" "#96CEB4"           ; green
   "part_of" "#FFEAA7"          ; yellow
   "location_of" "#DDA0DD"      ; purple
   "treats" "#98D8C8"           ; mint
   "result_of" "#F7DC6F"        ; gold
   "process_of" "#BB8FCE"       ; lavender
   "produces" "#85C1E9"         ; light blue
   "disrupts" "#E74C3C"         ; dark red
   "complicates" "#F39C12"      ; orange
   "manifestation_of" "#1ABC9C" ; turquoise
   "degree_of" "#95A5A6"        ; gray
   "adjacent_to" "#E67E22"})    ; dark orange
```

**Key Hy concepts:**

- `setv` - Binds a value to a variable (equivalent to Python's assignment)
- `{}` - Dict literals use curly braces
- `;` - Comments start with semicolons
- Hyphenated names like `PREDICATE-COLORS` become `PREDICATE_COLORS` in Python

### Defining Functions with `defn`

```hy
(defn get-predicate-color [predicate]
  "Return color for predicate, or default gray if not mapped"
  (.get PREDICATE-COLORS predicate "#CCCCCC"))
```

**Anatomy of a function definition:**

1. `defn` - The function definition macro
2. `get-predicate-color` - Function name (becomes `get_predicate_color` in Python)
3. `[predicate]` - Parameter list in square brackets
4. `"Return color..."` - Optional docstring (recommended!)
5. `(.get PREDICATE-COLORS predicate "#CCCCCC")` - The function body

**Method call syntax:** The `.` macro in Hy has two forms:

- `(.obj method args)` - Call `obj.method(args)`
- `(. obj method args)` - Alternative form (less common)

Here `(.get PREDICATE-COLORS predicate "#CCCCCC")` calls the dict's `get` method.

### List Comprehensions with `lfor`

The `parse-triples` function showcases Hy's powerful `lfor` macro:

```hy
(defn parse-triples [filepath limit filter-pred]
  "Parse triple file, return filtered list of (subject object predicate) tuples"
  (with [f (open filepath "r")]
    (setv triples (lfor line (.readlines f)
                        :setv tokens (.split (.strip line))
                        :if (= (len tokens) 3)
                        :setv [subj obj pred] tokens
                        :if (or (not filter-pred) (= pred filter-pred))
                        (tuple [subj obj pred])))
    ;; Apply limit if specified
    (if limit
      (cut triples 0 limit)
      triples)))
```

**Breaking down the `lfor`:**

```hy
(lfor line (.readlines f)           ; iterate over lines
      :setv tokens (.split (.strip line))  ; bind intermediate value
      :if (= (len tokens) 3)         ; filter: only 3-token lines
      :setv [subj obj pred] tokens   ; destructure the tokens
      :if (or (not filter-pred) (= pred filter-pred))  ; filter by predicate
      (tuple [subj obj pred]))       ; result expression
```

**Python equivalent:**

```python
triples = []
for line in f.readlines():
    tokens = line.strip().split()
    if len(tokens) == 3:
        subj, obj, pred = tokens
        if not filter_pred or pred == filter_pred:
            triples.append((subj, obj, pred))
```

**Key `lfor` clauses:**

| Clause | Purpose | Example |
|--------|---------|---------|
| `:setv` | Bind intermediate values | `:setv x (calculate y)` |
| `:if` | Filter elements | `:if (> x 10)` |
| `:for` | Nested iteration | `:for x items` |
| `:when` | Conditional processing | `:when (valid? x)` |

### Context Managers with `with`

```hy
(with [f (open filepath "r")]
  ;; f is available here
  ;; file is automatically closed when exiting scope
  (setv triples (lfor ...)))
```

The `with` statement in Hy uses square brackets for the binding:

```hy
(with [resource (create-resource)]
  ;; use resource
  )
```

### Building the Graph

```hy
(defn build-graph [triples engine]
  "Build graphviz Digraph from list of triples with color-coded edges"
  (setv g (Digraph :comment "UMLS Knowledge Graph"
                   :format "pdf"
                   :engine engine))
  
  ;; Graph-level attributes for better layout (using keyword args)
  (.attr g :rankdir "LR" :splines "true" :overlap "false"
           :fontsize "10" :fontname "Helvetica")
  (.attr g "node" :shape "box" :style "rounded,filled" :fillcolor "#E8F4FD"
           :fontsize "10" :fontname "Helvetica")
  (.attr g "edge" :fontsize "8" :fontcolor "gray40" :fontname "Helvetica"
           :arrowsize "0.7")
  ...)
```

**Keyword arguments in Hy:**

- Use `:keyword value` syntax for keyword arguments
- `:comment "UMLS Knowledge Graph"` passes `comment="UMLS Knowledge Graph"` to Python

### F-String Syntax

```hy
(print f"Reading triples from {args.input_file}...")
(print f"Parsed {(len triples)} triples with {(len unique-nodes)} unique nodes")
```

Hy f-strings require parentheses around expressions:

```hy
f"value: {(len items)}"        ; Note parentheses around (len items)
```

### Exception Handling

```hy
(try
  (setv triples (parse-triples args.input_file args.limit args.filter))
  (except [e FileNotFoundError]
    (print f"Error: File '{args.input_file}' not found")
    (sys.exit 1))
  (except [e Exception]
    (print f"Error parsing file: {e}")
    (sys.exit 1)))
```

**Hy try/except syntax:**

```hy
(try
  body-expressions...
  (except [ExceptionTypeName as variable-name]
    handler-expressions...))
```

### Conditional Execution with `when`

```hy
(when (= (len triples) 0)
  (if args.filter
    (print f"Error: No triples found matching predicate '{args.filter}'")
    (print "Error: No triples found"))
  (sys.exit 1))
```

`when` is a convenient single-branch conditional—execute body only if condition is true.

### The Main Entry Point

```hy
(when (= __name__ "__main__")
  (main))
```

This is equivalent to Python's:

```python
if __name__ == "__main__":
    main()
```

## Running the Program

### Basic Usage

```bash
# Using default settings
hy UMLS_graph.hy test.triples

# Specify output file
hy UMLS_graph.hy -o my_graph test.triples

# Limit to 50 triples
hy UMLS_graph.hy -l 50 test.triples

# Filter by predicate type
hy UMLS_graph.hy --filter isa test.triples

# Use different layout engine
hy UMLS_graph.hy --engine neato test.triples

# Auto-open the PDF
hy UMLS_graph.hy -v test.triples
```

### Layout Engine Options

| Engine | Best For |
|--------|----------|
| `dot` | Hierarchical layouts (default) |
| `neato` | Force-directed, unconstrained graphs |
| `fdp` | Force-directed placement |
| `circo` | Circular layouts |

## Project Setup

The `pyproject.toml` defines dependencies:

```toml
[project]
name = "UMLS-Graph"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "hy",
    "graphviz",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

Install with:

```bash
uv sync
```

## Key Hy Concepts Demonstrated

| Concept | Hy Syntax | Python Equivalent |
|---------|-----------|-------------------|
| Variable binding | `(setv x 10)` | `x = 10` |
| Function definition | `(defn name [args] body)` | `def name(args): body` |
| Method calls | `(.obj method args)` | `obj.method(args)` |
| List comprehension | `(lfor x items expr)` | `[expr for x in items]` |
| F-strings | `f"value: {(len x)}"` | `f"value: {len(x)}"` |
| Dictionary | `{"key" value}` | `{"key": value}` |
| Try/except | `(try body (except [E as e] handle))` | `try: body except E as e: handle` |
| With statement | `(with [r (create)] body)` | `with create() as r: body` |
| Conditionals | `(when condition body)` | `if condition: body` |

## Practice Exercises

1. **Add a new predicate color** - Extend `PREDICATE-COLORS` with a new mapping
2. **Export to SVG** - Modify the format to support SVG output
3. **Count statistics** - Add a summary showing predicate frequencies
4. **Node filtering** - Add an option to filter by subject or object name

## Summary

This chapter demonstrated a real-world Hy application that:

- Parses structured data files with list comprehensions
- Builds command-line interfaces with `argparse`
- Creates visualizations with the `graphviz` library
- Handles errors gracefully with try/except
- Uses idiomatic Hy patterns throughout

The combination of Lisp's elegance and Python's ecosystem makes Hy ideal for data processing and visualization tasks. This example scales from dozens to thousands of triples while maintaining readable, maintainable code.