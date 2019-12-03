# Introduction to the Hy Language

The [Hy programming language](http://docs.hylang.org/en/stable/) is a Lisp language that inter-operates smoothly with Python. We start with a few interactive examples that I encourage you to experiment with as you read. Then we will look at Hy data types and commonly used built in functions that are used in the remainder of this book.

I assume that you know at least a little Python and more importantly the Python ecosystem and general tools like **pip**.

Please start by installing Hy in your current Python environment:

{lang="bash",linenos=off}
~~~~~~~~
pip install git+https://github.com/hylang/hy.git
~~~~~~~~

## We Will Use the Contributed **let** Macro in Book Example Code

In Scheme, Clojure, and Common Lisp languages the **let** special form is used to define blocks of code with local variables and functions. I will require (or import) the contributed **let** macro, that substitutes for a built-in special form, in most examples in this book but I might not include the **require** in short code listings. Always assume that the following lines start each example:

{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(require [hy.contrib.walk [let]])
~~~~~~~~

Line 1 is similar to how we make Python scripts into runnable programs. Here we run **hy** instead of **python**. Line 3 imports the **let** macro. We can use **let** for code blocks with local variable and function definitions and also for using closures (I will cover closures at the end of this chapter):

{lang="hylang",linenos=on}
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

## Using Python Libraires

Using Python libraires like TensorFlow, Keras, BeutifulSoup, etc. are the reason I use the Hy language. Importing Python code and libraires and calling out to Python is simple and here we look at sufficient examples so that you will understand example code that we will look at later.

For example, in the chapter **Responsible Web Scraping** we will use the BeautifulSoup library. We will look at some Python code snippets and the corresponding Hylanguage versions of these snippets.

{lang="python",linenos=on}
~~~~~~~~
from bs4 import BeautifulSoup

raw_data = '<html><body><a href="http://markwatson.com">Mark</a></body></html>'
soup = BeautifulSoup(raw_data)
a_tags = soup.find_all("a")
print("a tags:", a_tags)
~~~~~~~~

In the following listing notice how we import other code and libraries in Hy. The special form **setv** is used to define variables in a local context. Since the **setv** statements in lines 3 and 5 are used at the top level, they are global in the Python/Hy module named after the root name of the source file.

{lang="hylang",linenos=on}
~~~~~~~~
(import [bs4 [BeautifulSoup]])

(setv raw-data
      "<html><body><a href=\"http://markwatson.com\">Mark</a></body></html>")
(setv soup (BeautifulSoup raw-data "lxml"))
(setv a (.find-all soup "a"))
(print "a tags:" a)
~~~~~~~~

Notice in line 5 that we can have "-" characters inside of variable and function names (**find-all** in this case) in the Hy language where we might use "_" underscore characters in Python.

## Global vs. Local Variables

Although I don't generally recommend it, sometimes it is convenient to export local variables defines with **setv** or in a **let** macro expansion to be global variables in the context of the current module (that is defined by the current source file). As an exmaple:

{lang="hylang",linenos=on}
~~~~~~~~
Marks-MacBook:deeplearning $ hy
hy 0.17.0+108.g919a77e using CPython(default) 3.7.3 on Darwin
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

TBD describe above code


## Using Python Libraries in Hy Programs

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

{lang="bash",linenos=on}
~~~~~~~~
(base) Marks-MacBook:hy-lisp-python $ hy
hy 0.17.0+108.g919a77e using CPython(default) 3.7.3 on Darwin
=> (import test)
=> test
<module 'test' from '/Users/markw/GITHUB/hy-lisp-python/test.py'>
=> (print (test.factorial 5))
120
~~~~~~~~

If we only wanted to import **BeautifulSoup** from the Python BeautifulSoup library **bs4** we can specify this in the **import** form:

{lang="hylang",linenos=on}
~~~~~~~~
(import [bs4 [BeautifulSoup]])
~~~~~~~~

## Replacing the Python slice (cut) notation with the Hy Functional Form

In Python we use a special notation for extracting sub-sequences from lists or strings:

{lang="bash",linenos=off}
~~~~~~~~
Marks-MacBook:deeplearning $ python
Python 3.7.3 (default, Mar 27 2019, 16:54:48) 
[Clang 4.0.1 (tags/RELEASE_401/final)] :: Anaconda, Inc. on darwin
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

{lang="bash",linenos=off}
~~~~~~~~
Marks-MacBook:deeplearning $ hy
hy 0.17.0+108.g919a77e using CPython(default) 3.7.3 on Darwin
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

{lang="bash",linenos=off}
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

{lang="bash",linenos=on}
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


## Common Pitfalls When Starting to Use Hy

When I started using Hy I found myself initially making simple mistakes that I list here to help you avoid them:

- When converting Python code, I would copy "," comma characters separating arguments to functions which leads to errors, of a "naed undefined error".
- TBD
- TBD


## Writing Your Own Libraries in the Hy Language

TBD


## Using Closures

{lang="hylang",linenos=on}
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
