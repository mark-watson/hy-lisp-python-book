# Introduction to the Hy Language

The [Hy programming language](http://docs.hylang.org/en/stable/) is a Lisp language that inter-operates smoothly with Python. We start with a few interactive examples that I encourage you to experiment with as you read. Then we will look at Hy data types and commonly used built in functions that are used in the remainder of this book.

I assume that you know at least a little Python and more importantly the Python ecosystem and general tools like **pip**.

Please start by installing Hy in your current Python environment:

        pip install git+https://github.com/hylang/hy.git

## We Will Use the Contributed **let** Macro in Book Example Code

In Scheme, Clojure, and Common Lisp languages the **let** special form is used to define blocks of code with local variables and functions. I will require (or import) the contributed **let** macro, that substitutes for a built-in special form, in most examples in this book but I might not include the **require** in short code listings. Always assume that the following lines start each example:

{lang="lisp",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(require [hy.contrib.walk [let]])
~~~~~~~~

Line 1 is similar to how we make Python scripts into runnable programs. Here we run **hy** instead of **python**. Line 3 imports the **let** macro. We can use **let** for code blocks with local variable and function definitions and also for using closures (I will cover closures at the end of this chapter):

{lang="lisp",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(require [hy.contrib.walk [let]])

(let [x 1]
  (print x)
  (let [x 33]
    (print x))
  (print x))
~~~~~~~~

The output is:

{linenos=off}
~~~~~~~~
1
33
1
~~~~~~~~


## Writing Functions in the Hy Language

TBD

## How Simple Lisp Data Structures Can Represent Our Data

TBD: better section title

TBD: examples

## Using Python Libraries in Hy Programs

TBD

## Writing Your Own Libraries in the Hy Language

TBD


## Using Closures

{lang="clojure",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(require [hy.contrib.walk [let]])

(let [x 1]
  (defn increment []
    (setv x (+ x 1))
    x))

(print (increment))
(print (increment))
(print (increment))
~~~~~~~~
