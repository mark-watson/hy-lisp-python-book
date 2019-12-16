# Preface

I have been using Lisp languages professionally since 1982 and have written books covering the Common Lisp and Scheme languages. This book covers many programming topics using the Lisp language **Hy** that compiles to Python AST and is compatible with code, libraries, and frameworks written in Python. The main topics we will cover and write example applications for are:

- Relational databases
- Web app development
- Web scraping
- Accessing semantic web and linked data sources like Wikipedia, DBpedia, and Wikidata
- Automatically constructing Knowledge Graphs from text documents, semantic web and linked data
- Deep Learning
- Natural Language Processing (NLP) using Deep Learning

In some sense the particular topics of example programs is not relevant to the main idea of this book: how to increase programmer productivity and happiness using a Lisp language in a bottom up development style. This style relies heavily on an interactive REPL for exploring APIs and writing new code. I chose the above topics based on my experience working as a developer and researcher.

## Setting Up Your Development Environment

This is a hands-on book! I expect you, dear reader, to follow along with the examples as you read this book. I assume that you know some Python and know how to use the command line tools **python** and **pip** and use a virtual Python environment like [Anaconda (**conda**)](https://www.anaconda.com/) or [**virtualenv**](https://virtualenv.pypa.io/en/latest/). Personally I prefer **conda** but you can use any Pyhton setup you like as long as you have a few packages installed:

- TBD list out Python library requirements here  TBD

- Python 3.x
- spaCy
- TensorFlow and Keras
- TBD


You can install the current stable version of **Hy** using:

        pip install git+https://github.com/hylang/hy.git



## What is Lisp Programming Style?

I will give some examples here and also show exploratory Hy language REPL examples later in the book. How often to you search the web for documentation on how to use a library? I reduce the amount of time that I spend by having a Lisp REPL open with the library that I am starting to use open so that I can experiment with API calls and returned results as I read.

When I am working on new code or a new algorithm I liske to have a Lisp REPL open and try short snippets of code to get working code for solving low level problems, building up to more complex code. As I figure out how to do things I enter code that works and that I want to keep into a text editor and then convert this code into my own library. I then iterate on loading my new library into a REPL and stress test it, look for API improvements, etc.

I find, in general, that a "bottom up" approach gets me to working high quality systems faster than spending too much time doing up front planning and design. The problem with spending too much up front time on design is that we change our minds as to what makes the most sense to solve a problem as we experiment with code. I try to avoid up front time spent on work that I will have to re-work or even toss out.

## Hy is Python, But With a Lisp Syntax

When I need a library for a Hy project I search for Python libraries and either write a thin Hy language "wrapper" around the Python library or just call the Python APIs directly from Hy code. You will see many examples of both approaches in this book.

## About the Book Cover

The official Hy Language logo is an octopus:

{width=22%}
![The Hy Language logo Cuddles by Karen Rustad](images/hylisplogo.jpg)

Usually I use photographs that I take myself for covers of my LeanPub books. Although I have SCUBA dived since I was 13 years old, sadly I have no pictures of an octopus that I have taken myself. I did find a public domain picture I liked (that is the cover of this book) on Wikimedia. **Cover Credit**: Thanks to Wikimedia user Pseudopanax for placing the cover image in the pubic domain.
