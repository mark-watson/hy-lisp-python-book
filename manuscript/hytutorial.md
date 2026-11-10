# Introduction to the Hy Language

The [Hy programming language](http://docs.hylang.org/en/stable/) is a Lisp language that inter-operates smoothly with Python. We start with a few interactive examples that I encourage you to experiment with as you read. Then we will look at Hy data types and commonly used built-in functions that are used in the remainder of this book.

I assume that you know at least a little Python and more importantly the Python ecosystem and general tools like **uv** and **pip**.

Please start by installing **uv** on your laptop or server. Use either of the following commands on macOS or Linux:

{lang="bash",linenos=off}
~~~~~~~~
pip install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
~~~~~~~~

On Windows use one of these commands:

{lang="bash",linenos=off}
~~~~~~~~
irm https://astral.sh/uv/install.ps1 | iex
~~~~~~~~



## Using Python Libraries

Using Python libraries like TensorFlow, Keras, BeautifulSoup, etc. are the reason I use the Hy language. Importing Python code and libraries and calling out to Python is simple and here we look at sufficient examples so that you will understand example code that we will look at later.

*Note: starting in August 2025 the example programs in the GitHub repository XX are in individual directores, each pre-configured for use with **uv***

For example, in the chapter **Responsible Web Scraping** we will use the BeautifulSoup library. We will look at some Python code snippets and the corresponding Hy language versions of these snippets. Let's first look at a Python example that we will then convert to Hy:

{lang="python",linenos=on}
~~~~~~~~
from bs4 import BeautifulSoup

raw_data = '<html><body><a href="http://markwatson.com">Mark</a></body></html>'
soup = BeautifulSoup(raw_data)
a_tags = soup.find_all("a")
print("a tags:", a_tags)
~~~~~~~~

In the following listing notice how we import other code and libraries in Hy. The special form **setv** is used to define variables in a local context. Since the **setv** statements in lines 4, 6, and 7 are used at the top level, they are global in the Python/Hy module named after the root name of the source file.

{lang="hylang",linenos=on}
~~~~~~~~
$ cd hy-lisp-python-book/source_code_for_examples/webscraping
$ uv run hy
Hy 1.3.1 (Eyes in the Sky) using CPython(main) 3.14.7 on Darwin
=> (import bs4 [BeautifulSoup])
=> (setv raw-data "<html><body><a href=\"http://markwatson.com\">Mark</a></body></html>")
=> (setv soup (BeautifulSoup raw-data "lxml"))
=> (setv a (.find-all soup "a"))
=> (print "atags:" a)
atags: [<a href="http://markwatson.com">Mark</a>]
=> (type a)
<class 'bs4.element.ResultSet'>
=> (dir a)
['__add__', '__class__', '__contains__', '__delattr__', '__delitem__', '__dict__', '__dir__', '__doc__', '__eq__', '__format__', '__ge__', '__getattr__', '__getattribute__', '__getitem__', '__gt__', '__hash__', '__iadd__', '__imul__', '__init__', '__init_subclass__', '__iter__', '__le__', '__len__', '__lt__', '__module__', '__mul__', '__ne__', '__new__', '__reduce__', '__reduce_ex__', '__repr__', '__reversed__', '__rmul__', '__setattr__', '__setitem__', '__sizeof__', '__str__', '__subclasshook__', '__weakref__', 'append', 'clear', 'copy', 'count', 'extend', 'index', 'insert', 'pop', 'remove', 'reverse', 'sort', 'source']
~~~~~~~~

Notice in lines 3 and 6 that we can have "-" characters inside of variable and function names (**raw-data** and **find-all** in this case) in the Hy language where we might use "_" underscore characters in Python. Like Python, we can use **type** get get the type of a value and **dir** to see what symbols are available for a object.

## Global vs. Local Variables

Although I don't generally recommend it, sometimes it is convenient to export local variables defined with **setv** to be global variables in the context of the current module (that is defined by the current source file). As an example:

{lang="hylang",linenos=on}
~~~~~~~~
$ uv run hy
Hy 1.3.1 (Eyes in the Sky) using CPython(main) 3.14.7 on Darwin
=> (defn foo []
... (global x)
... (setv x 1)
... (print x))
=> (foo)
1
=> x
1
=> 
~~~~~~~~

Before executing function **foo** the global variable **x** is undefined (unless you coincidentally already defined somewhere else). When function **foo** is called, a global variable **x** is defined and then it equal to the value 1.


## Using Python Code in Hy Programs

If there is a Python source file, named for example, *test.py* in the same directory as a Hy language file:

{lang="python",linenos=on}
~~~~~~~~
def factorial (n):
  if n < 2:
    return 1
  return n * factorial(n - 1)
~~~~~~~~

This code will be in a module named **test** because that is the root source code file name. We might import the Python code using the following in Python:

{lang="python",linenos=on}
~~~~~~~~
import test

print(test.factorial(5))
~~~~~~~~

and we can use the following in Hy to import the Python module **test** (defined in *test.py*):

{lang="hylang",linenos=on}
~~~~~~~~
(import test)

(print (test.factorial 5))
~~~~~~~~

Running this interactively in Hy:

{lang="hylang",linenos=on}
~~~~~~~~
$ uv run hy
Hy 1.3.1 (Eyes in the Sky) using CPython(main) 3.14.7 on Darwin
=> (import test)
=> test
<module 'test' from '/Users/markw/GITHUB/hy-lisp-python/test.py'>
=> (print (test.factorial 5))
120
~~~~~~~~

If we only wanted to import **BeautifulSoup** from the Python BeautifulSoup library **bs4** we can specify this in the **import** form:

{lang="hylang",linenos=on}
~~~~~~~~
(import bs4 [BeautifulSoup])
~~~~~~~~

{width: "80%"}
![Hy-Python interoperability architecture: importing and using Hy code in Python programs](FIG_use_hy_in_python.jpg)

## Using Hy Libraries in Python Programs

There is nothing special about importing and using Hy library code or your own Hy scripts in Python programs. The directory **hy-lisp-python-book/source_code_for_examples/use_hy_in_python** in the [git repository for this book https://github.com/mark-watson/hy-lisp-python-book](https://github.com/mark-watson/hy-lisp-python-book) contains an example Hy script **get_web_page.hy** that is a slightly modified version of code we will explain and use in the later chapter on web scraping and a short Python script **use_hy_stuff.py** that uses a function defined in Hy:

**get_web_page.hy:**

{lang="hylang",linenos=on}
~~~~~~~~
(import argparse os)
(import urllib.request [Request urlopen])

(defn get-raw-data-from-web [aUri [anAgent
                                   {"User-Agent" "HyLangBook/1.0"}]]
  (setv req (Request aUri :headers anAgent))
  (setv httpResponse (urlopen req))
  (setv data (.read httpResponse))
  data)

(defn main_hy []
  (print (get-raw-data-from-web "http://markwatson.com")))
~~~~~~~~

We define two functions here. Notice the optional argument **anAgent** defined in lines 4-5 where we provide a default value in case the calling code does not provide a value. In the next Python listing we import the file in the last listing and call the Hy function **main** on line 4 using the Python calling syntax.

Hy is the same as Python once it is compiled to an abstract syntax tree (AST).

**hy-lisp-python/use_in_python:**

{lang="hylang",linenos=on}
~~~~~~~~
import hy
from get_web_page import main_hy

main_hy()
~~~~~~~~

What I want you to understand and develop a feeling for is that Hy and Python are really the same but with a different syntax and that both languages can easily be used side by side.


## Replacing the Python slice (cut) Notation with the Hy Functional Form

In Python we use a special notation for extracting sub-sequences from lists or strings:

{lang="python",linenos=off}
~~~~~~~~
$ uv run python
Python 3.12.0 (main, Oct  2 2023, 20:56:14) [Clang 16.0.3 ] on darwin
Type "help", "copyright", "credits" or "license" for more information.
>>> s = '0123456789'
>>> s[2:4]
'23'
>>> s[-4:]
'6789'
>>> s[-4:-1]
'678'
>>> 
~~~~~~~~

In Hy this would be:

{lang="hylang",linenos=off}
~~~~~~~~
$ uv run hy    
Hy 1.3.1 (Eyes in the Sky) using CPython(main) 3.14.7 on Darwin
=> (setv s "0123456789")
=> (cut s 2 4)
'23'
=> (cut s -4)
'6789'
=> (cut s -4 -1)
'678'
=> 
~~~~~~~~

It also works to use **cut** with **setv** to destructively change a list; for example:

{lang="hylang",linenos=off}
~~~~~~~~
=> (setv x [0 1 2 3 4 5 6 7 8])
=> x
[0, 1, 2, 3, 4, 5, 6, 7, 8]
=> (cut x 2 4)
[2, 3]
=> (setv (cut x 2 4) [22 33])
=> x
[0, 1, 22, 33, 4, 5, 6, 7, 8]
~~~~~~~~

## Iterating Through a List With Index of Each Element

We will use **lfor** as a form of Python list comprehension; for example:

{lang="hylang",linenos=on}
~~~~~~~~
=> (setv sentence "The ball rolled")
=> (lfor i (enumerate sentence) i)
[(0, 'T'), (1, 'h'), (2, 'e'), (3, ' '), (4, 'b'), (5, 'a'), (6, 'l'), (7, 'l'), (8, ' '), (9, 'r'), (10, 'o'), (11, 'l'), (12, 'l'), (13, 'e'), (14, 'd')]
=> (setv vv (lfor i (enumerate sentence) i))
=> vv
[(0, 'T'), (1, 'h'), (2, 'e'), (3, ' '), (4, 'b'), (5, 'a'), (6, 'l'), (7, 'l'), (8, ' '), (9, 'r'), (10, 'o'), (11, 'l'), (12, 'l'), (13, 'e'), (14, 'd')]
=> (for [[a b] vv]
... (print a b))
0 T
1 h
2 e
3  
4 b
5 a
6 l
7 l
8  
9 r
10 o
11 l
12 l
13 e
14 d
=> 
~~~~~~~~

On line 2, the expression **(enumerate sentence)** generates one character at a time from a string. **enumerate** operating on a list will generate one list element at a time.

Line 9 shows an example of *destructuring*: the values in the list **vv** are tuples (tuples are like lists but are immutable, that is, once a tuple is constructed the values it holds can not be changed) with two values. The values in each tuple are copied into binding variables in the list **[a b]**. We could have used the following code instead but it is more verbose:

{lang="hylang",linenos=off}
~~~~~~~~
=> (for [x vv]
    (setv a (first x))
    (setv b (second x))
... (print a b))
0 T
1 h
2 e
3  
4 b
 . . .
13 e
14 d
=> 
~~~~~~~~

## Formatted Output

I suggest using the Python **format** method when you need to format output. In the following repl listing, you can see a few formatting options: insert any Hy data into a string (line 3), print values with a specific width and right justified (in line 5 the width for both values is 15 characters), print values with a specific width and left justified (in line 7), and limiting the number of characters values can be expressed as (in line 9 the object "cat" is expressed as just the first two characters and the value 3.14159 is expressed as just three numbers, the period not counting).

{lang="hylang",linenos=off}
~~~~~~~~
$ uv run hy    
Hy 1.3.1 (Eyes in the Sky) using CPython(main) 3.14.7 on Darwin
=> (.format "first: {} second: {}" "cat" 3.14159)
'first: cat second: 3.14159'
=> (.format "first: {:>15} second: {:>15}" "cat" 3.14159)
'first:             cat second:         3.14159'
=> (.format "first: {:15} second: {:15}" "cat" 3.14159)
'first: cat             second:         3.14159'
=> (.format "first: {:.2} second: {:.3}" "cat" 3.14159)
'first: ca second: 3.14'
=> 
~~~~~~~~

Notice the calling **.format** here returns a string value rather than writing to an output stream.

## Importing Libraries from Different Directories on Your Laptop

I usually write applications by first implementing simpler low-level utility libraries that are often not in the same directory path as the application that I am working on. Let's look at a simple example of accessing the library **nlp_lib.hy** in the directory **hy-lisp-python/nlp** from the directory **hy-lisp-python/webscraping**:

{lang="hylang",linenos=on}
~~~~~~~~
$ pwd
/Users/markw/GITHUB/hhy-lisp-python-book
$ cd webscraping 
$ uv run hy    
Hy 1.3.1 (Eyes in the Sky) using CPython(main) 3.14.7 on Darwin
=> (import sys)
=> (sys.path.insert 1 "../nlp")
=> (import nlp-lib [nlp])
=> (nlp "President George Bush went to Mexico and he had a very good meal")
{'text': 'President George Bush went to Mexico and he had a very good meal', 
  ...
 'entities': [['George Bush', 'PERSON'], ['Mexico', 'GPE']]}
=> (import [coref-nlp-lib [coref-nlp]])
=> (coref-nlp "President George Bush went to Mexico and he had a very good meal")
{'corefs': 'President George Bush went to Mexico and President George Bush had a very good meal',  ...  }}}
=> 
~~~~~~~~

Here I did not install the library **nlp_lib.hy** using Python setuptools (which I don't cover in this book, you can [read the documentation](https://setuptools.readthedocs.io)) as a library on the system. I rely on relative paths between the library directory and the application code that uses the library.

On line 6 I am inserting the library directory into the Python system load path so the import statement on line 8 can find the **nlp-lib** library and on line 13 can find the **coref-nlp-lib** library.


## Hy Looks Like Clojure: How Similar Are They?

[Clojure](https://clojure.org/) is a dynamic general purpose Lisp language for the JVM. One of the great Clojure features is support of immutable data (read only after creation) that makes multi-threaded code easier to write and maintain.

Unfortunately, Clojure's immutable  data structures cannot be easily implemented efficiently in Python so the Hy language does  not support immutable data, except for tuples. Otherwise the syntax for defining functions, using maps/hash tables/dictionaries, etc. is similar between the two languages.

The original Hy language developer Paul Tagliamonte was clearly inspired by Clojure.

The book **Serious Python** by Julien Danjou has an entire chapter (Chapter 9) on the Python AST (abstract syntax tree), an introduction to Hy, and an interview with Paul Tagliamonte. Recommended!

[This podcast](https://www.pythonpodcast.com/episode-23-hylang-core-developers/) in 2015 interviews Hy developers Paul Tagliamonte, Tuukka Turto, and Morten Linderud. You can see the [current Hy contributor list on github](https://github.com/hylang/hy/graphs/contributors).

{width: "80%"}
![Matplotlib plotting architecture: Numpy data processing and visualization pipeline](FIG_matplotlib_examples.jpg)

## Plotting Data Using the Numpy and the Matplotlib Libraries

Data visualization is a common task when working with numeric data. In a later chapter on Deep Learning we will use two functions, the **relu** and **sigmoid** functions. Here we will use a few simple Hy language scripts to plot these functions.

The Numpy library supports what is called "broadcasting" in Python. In the function **sigmoid** that we define in the following REPL, we can pass either a single floating point number or a Numpy array as an argument. When we pass a Numpy array, then the function **sigmoid** is applied to each element of the Numpy array:

{lang="hylang",linenos=on}
~~~~~~~~
$ uv run hy    
Hy 1.3.1 (Eyes in the Sky) using CPython(main) 3.14.7 on Darwin
=> (import numpy :as np)
=> (import matplotlib.pyplot :as plt)
=> 
=> (defn sigmoid [x]
...   (/ 1.0 (+ 1.0 (np.exp (- x)))))
=> (sigmoid 0.2)
0.549833997312478
=> (sigmoid 2)
0.8807970779778823
=> (np.array [-5 -2 0 2 5])
array([-5, -2,  0,  2,  5])
=> (sigmoid (np.array [-5 -2 0 2 5]))
array([0.00669285, 0.11920292, 0.5, 0.88079708, 0.99330715])
=> 
~~~~~~~~

The git repository directory **source_code_for_examples/matplotlib_examples** contains two similar scripts (`plot_sigmoid.hy` and `plot_relu.hy`) for plotting the **sigmoid** and **relu** functions. Here is the script to plot the **sigmoid** function:

{lang="hylang",linenos=on}
~~~~~~~~
(import numpy :as np)
(import matplotlib.pyplot :as plt)

(defn sigmoid [x]
  (/ 1.0 (+ 1.0 (np.exp (- x)))))

(setv X (np.linspace -8 8 50))
(plt.plot X (sigmoid X))
(plt.title "Sigmoid Function")
(plt.ylabel "Sigmoid")
(plt.xlabel "X")
(plt.grid)
(plt.show)
~~~~~~~~

The generated plot looks like this on macOS (Matplotlib is portable and also works on Windows and Linux):

{width: "70%"}
![Sigmoid Function](sigmoid.png)

## Bonus Points: Configuration for macOS and ITerm2 for Generating Plots Inline in a Hy REPL and Shell

On the macOS ITerm2 terminal app and on most Linux terminal apps, it is possible to get inline matplotlib plots in a shell (bash, zsh, etc.), in Emacs, etc. This will take some setup work but it is well worth it especially if you work on remote servers via SSH or tmux. Here is the setup for macOS:

      pip3 install itermplot

The add the following to your .profile, .bash_profile, or .zshrc (depending on your shell setup):

      export MPLBACKEND="module://itermplot"

Here we run an example from the last section in a zsh shell (bash, etc. also should work):

{width: "80%"}
![Inline matplotlib use in zsh shell in an ITerm on macOS](mac-inline-matplotlib.png)

The best part of generating inline plots is during interactive REPL-based coding sessions:

{width: "80%"}
![Inline matplotlib use in a Hy REPL on macOS](mac-inline-matplotlib2.png)

If you use a Mac laptop to SSH into a remote Linux server you need to install **itermplot** and set the environment variable **MPLBACKEND** on the remote server.

## Modern Hy and Python 3.12–3.15: What Changed Since Hy 1.1

When I started earlier editions of this book, Hy 0.x and 1.1 were the targets. Every project in this repository now pins `hy>=1.3.1` and uses `uv` for reproducible environments. This section walks through the language features added across Hy 1.2 and Hy 1.3 and shows how Hy tracks modern Python (3.12 through 3.15) without giving up portability.

The companion code for this section is in the directory **source_code_for_examples/modern_hy**, in addition to the interop example in **source_code_for_examples/use_hy_in_python**.

### Version Policy and Upgrade Workflow

Hy 1.3.1 supports CPython 3.9 through 3.15. In this book our project `pyproject.toml` files require Python 3.12 or newer (`requires-python = ">=3.12"`), and I test the examples on Python 3.12 and 3.14. When a feature requires Python 3.14 or 3.15 (such as PEP 750 template strings or PEP 810 lazy imports), I call it out explicitly so you can keep your main codebase portable across Python 3.12+.

When upgrading an older Hy 1.1 project to 1.3.1, my workflow has four steps:

1. Pin `hy>=1.3.1` in `pyproject.toml` and run `uv sync`.
2. Run `uv run hy2py your_module.hy` on each file to inspect the Python code that Hy generates.
3. Run your interactive sessions with `uv run hy --spy` when you want to see the translated Python statement before each form executes.
4. Run `uv run pytest` to verify behavior across your test suite.

### Assignment: `setv :chain`, `setx`, `let`, and `nonlocal`

Hy 1.2 added `:chain` to `setv` so you can initialize multiple targets to the same value—just like Python's `hits = misses = errors = 0`:

```hy
(defn reset-counters []
  "Return a dictionary of zeroed counters using (setv :chain ...)."
  (setv :chain [hits misses errors] 0)
  {"hits" hits "misses" misses "errors" errors})
```

Whereas `setv` is a statement form (or compiles to assignments), `setx` is Python's assignment expression (`:=`, the walrus operator). It binds a name *and* returns the value inside a condition or comprehension, avoiding a redundant function call:

```hy
(defn first-non-empty [#^ (get list str) lines]
  "Demonstrate (setx ...) inside a condition and a comprehension."
  (setv cleaned
    (lfor raw lines
          :if (setx stripped (.strip raw))
          stripped))
  (if cleaned (get cleaned 0) ""))
```

For lexical scoping inside a function, `let` creates bindings that exist only within the `let` body, while `nonlocal` lets an inner closure mutate a variable from an enclosing function scope:

```hy
(defn make-accumulator [#^ int start]
  "Return a closure that increments an internal total using nonlocal."
  (let [initial (max 0 start)]
    (setv total initial)
    (defn step [#^ int delta]
      (nonlocal total)
      (+= total delta)
      total)
    step))
```

### Structural Pattern Matching with `match`

Python's structural pattern matching (`match`/`case`) is expressed in Hy as `(match subject pattern-1 result-1 pattern-2 result-2 ...)`. Each arm pairs a pattern (plus an optional `:if` guard) with a result expression, and because `match` is an expression in Hy, it returns the value of the matching arm.

Hy 1.3 improved `match` so patterns work cleanly with dataclasses, sequences, OR patterns (`|`), `:as` bindings, and even Hy's own syntax models (`hy.models.Expression`, `hy.models.Symbol`):

```hy
(defclass [dataclass] QueryEvent []
  #^ str kind
  #^ object payload)

(defn #^ str describe-event [#^ object event]
  "Describe a domain event or a raw Hy model using structural pattern matching."
  (match event
    (QueryEvent :kind "lookup" :payload (| "isa" "part_of") :as pred)
      f"hierarchy lookup on {pred}"
    (QueryEvent :kind "lookup" :payload pred)
      f"lookup on {pred}"
    (QueryEvent :kind "limit" :payload (int n)) :if (> n 0)
      f"limit to {n} triples"
    (hy.models.Expression [(hy.models.Symbol "edge") subj obj pred])
      f"model edge: {(str subj)} -{(str pred)}-> {(str obj)}"
    [subj obj pred]
      f"tuple edge: {subj} -{pred}-> {obj}"
    _
      "unknown event"))
```

Matching directly on `hy.models.Expression` is especially useful when you write macros or small domain-specific languages, which we will do in the next chapter.

### Type Annotations (`#^`), `deftype`, and Type-Checking via `hy2py`

Hy attaches type annotations with the `#^` reader macro before a variable, parameter, or function name. For Python 3.12+ `type` aliases (PEP 695), Hy provides `deftype`, including generic type parameters via `:tp`:

```hy
(deftype NodeId str)
(deftype Triple (get tuple #(NodeId str NodeId)))
(deftype :tp [T] Pair (get tuple #(T T)))

(defn #^ (get Pair NodeId) endpoints [#^ Triple triple]
  "Return the (subject, object) pair of a (subject, object, predicate) triple."
  (setv [subj obj _] triple)
  #(subj obj))
```

Static type checkers such as `mypy` and `pyright` read Python syntax rather than `.hy` files, so the standard workflow is to translate your `.hy` module with `hy2py` and pass the generated Python to the checker. We will automate that pipeline in the tooling chapter.

### Strings: Bracket Strings and Python 3.14 Template Strings (`t"..."`)

When you embed multi-line SPARQL, Cypher, SQL, or prompts in Hy code, bracket strings `#[delim[...]delim]` avoid backslash-escaping altogether:

```hy
(setv CYPHER-SAMPLE #[cypher[
MATCH (s:Concept)-[r]->(o:Concept)
WHERE r.predicate = "isa"
RETURN s.id, o.id
]cypher])
```

> **Requires Python 3.14+ and Hy 1.3+:** Python 3.14 introduced PEP 750 template strings (`t"..."`), and Hy 1.3 supports them directly. Unlike an f-string `f"..."`, which immediately evaluates to a `str`, a t-string `t"SELECT ... WHERE pred = {predicate}"` evaluates to a `string.templatelib.Template` object whose `.strings` and `.interpolations` can be inspected and sanitized before rendering—ideal for SQL, SPARQL, or HTML escaping.

### Modern Comprehensions, Async Forms, and Python 3.14/3.15 Runtime Notes

Hy 1.3 also supports PEP 798 unpacking inside comprehensions: using `#*` in the result position of `lfor`, `sfor`, or `gfor` splices each inner iterable into the output:

```hy
(defn #^ (get list str) flatten-batches [#^ (get list (get list str)) batches]
  "Flatten a list of batches with #* inside lfor (PEP 798 in Hy 1.3)."
  (lfor batch batches #* batch))
```

Modern Hy provides full syntax for asynchronous Python—`(defn :async ...)`, `(fn :async ...)`, `(with [:async ...] ...)`, and `(for [:async ...] ...)`—which we cover in depth in the **Async and Concurrent Hy** chapter. And when running on Python 3.14's free-threaded build or Python 3.15's lazy imports (`pragma`), pure Hy functions compile to standard Python bytecode and follow the exact same concurrency and import semantics as regular Python modules.

### Mini-Project: Refactoring the UMLS Triple Processor to Modern Hy

To see these features working together, `source_code_for_examples/modern_hy/umls_modern.hy` refactors the triple-parsing and summarization core of `plots_with_graphviz/UMLS_graph.hy` using `deftype`, `#^` annotations, `setv :chain`, `setx`, `match`, and `#*` comprehension unpacking:

```hy
(import dataclasses [dataclass])

(deftype NodeId str)
(deftype Predicate str)
(deftype Triple (get tuple #(NodeId NodeId Predicate)))

(setv PREDICATE-COLORS
  {"isa" "#FF6B6B"
   "interacts_with" "#4ECDC4"
   "affects" "#45B7D1"
   "causes" "#96CEB4"
   "part_of" "#FFEAA7"
   "location_of" "#DDA0DD"
   "treats" "#98D8C8"})

(defclass [dataclass] GraphSummary []
  #^ int triple-count
  #^ int node-count
  #^ (get dict #(Predicate int)) predicate-counts)

(defn #^ str predicate-color [#^ Predicate pred]
  "Return the color hex string for a predicate using structural match."
  (match pred
    (| "isa" "part_of") (.get PREDICATE-COLORS pred "#CCCCCC")
    (str p) :if (in p PREDICATE-COLORS) (get PREDICATE-COLORS p)
    _ "#CCCCCC"))

(defn #^ (get list Triple) parse-triple-lines [
    #^ (get list str) lines
    #^ (| int None) [limit None]
    #^ (| Predicate None) [filter-pred None]]
  "Parse whitespace-separated (subject object predicate) lines."
  (setv triples
    (lfor line lines
          :if (setx stripped (.strip line))
          :if (not (.startswith stripped "#"))
          :setv tokens (.split stripped)
          :if (= (len tokens) 3)
          :setv [subj obj pred] tokens
          :if (or (is filter-pred None) (= pred filter-pred))
          #(subj obj pred)))
  (if (is limit None)
    triples
    (cut triples 0 limit)))

(defn #^ GraphSummary summarize-triples [#^ (get list Triple) triples]
  "Compute node and predicate counts for a list of triples."
  (setv :chain [triple-count node-count] 0)
  (setv endpoints (lfor [s o _] triples #* [s o]))
  (setv unique-nodes (set endpoints))
  (setv #^ (get dict #(Predicate int)) counts {})
  (for [[_ _ pred] triples]
    (setv (get counts pred) (+ (.get counts pred 0) 1)))
  (setv triple-count (len triples)
        node-count (len unique-nodes))
  (GraphSummary
    :triple-count triple-count
    :node-count node-count
    :predicate-counts counts))
```

You can run the demo, the test suite, and the `hy2py` + `mypy` check from `source_code_for_examples/modern_hy`:

```bash
$ cd source_code_for_examples/modern_hy
$ uv sync
$ uv run hy demo.hy
=== Modern Hy 1.3.1 Tour ===
Python: 3.14.7
Counters: {'hits': 0, 'misses': 0, 'errors': 0}
First non-empty: hello hy 1.3
Accumulator steps: 15 22
Endpoints: ('aspirin', 'headache')
Match: hierarchy lookup on isa
Match: limit to 25 triples
Match: model edge: aspirin -treats-> headache
Match: tuple edge: cell -has_part-> nucleus
Safe query: ('SELECT subj, obj FROM triples WHERE pred = ? LIMIT ?', ('isa', 10))
Flattened batches: ['a', 'b', 'c', 'd', 'e']
UMLS summary: GraphSummary(triple_count=4, node_count=6, predicate_counts={'treats': 2, 'isa': 1, 'affects': 1})
Color for 'isa': #FF6B6B
$ uv run pytest -q
.......                                                                  [100%]
7 passed in 0.08s
$ uv run hy2py umls_modern.hy > /tmp/umls_modern.py
$ uv run mypy --ignore-missing-imports /tmp/umls_modern.py
Success: no issues found in 1 source file
```

## Optional Practice Problems

To solidify your understanding of data visualization and Python-Hy interoperability, try completing the following exercises:

### Data Visualization and Plotting

1. **Plotting Multiple Curves**: Modify `plot_sigmoid.hy` (or create a new Hy script) to plot both the Sigmoid and ReLU functions on the same graph. Use `(plt.plot ... :label "Sigmoid")` and `(plt.plot ... :label "ReLU")`, and call `(plt.legend)` to render a legend.
2. **Visual Reference Lines**: Add a horizontal dotted line at `y = 0.5`$ on your Sigmoid plot to indicate the inflection point, and a vertical line at `x = 0`$. In Matplotlib, this can be done using:
   ```hylang
   (plt.axhline :y 0.5 :color "red" :linestyle "--")
   (plt.axvline :x 0.0 :color "gray" :linestyle "-.")
   ```
3. **Plotting Tanh**: Implement and plot the hyperbolic tangent activation function (`\tanh`$). The equation is `f(x) = \tanh(x)`$. *Hint: you can use numpy's built-in `(np.tanh x)`.* Compare its output range with the Sigmoid function.

### Python Interoperability

1. **Passing Parameters Across Languages**: Modify `get_web_page.hy` and `use_hy_stuff.py` so that instead of scraping a hardcoded URL, the Python script takes a URL as input from the user (or via command line using `sys.argv`) and passes it as an argument to the Hy function.
2. **Overriding Default Parameters**: The function `get-raw-data-from-web` in `get_web_page.hy` defines an optional argument `anAgent` with a default dictionary value. Write Python code in `use_hy_stuff.py` to call `get_raw_data_from_web` directly, overriding the user agent to `{"User-Agent": "Custom-Agent-Python"}`. (Recall that kebab-case Hy names map to snake_case Python names, so `get-raw-data-from-web` becomes `get_raw_data_from_web`.)
3. **Handling Interoperable Exceptions**: Wrap the network request in `use_hy_stuff.py` with Python's standard `try...except` exception handling block. Catch `urllib.error.URLError` to handle connection failures gracefully when an invalid URL is passed, demonstrating how exceptions flow seamlessly between Hy and Python.
