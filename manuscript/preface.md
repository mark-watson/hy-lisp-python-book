# Cover Material, Copyright, and License

Copyright 2020-2024 Mark Watson. All rights reserved. This book may be shared using the Creative Commons “share and share alike, no modifications, no commercial reuse” license.

This eBook will be updated occasionally so please periodically check the [leanpub.com web page for this book](https://leanpub.com/hy-lisp-python) for updates.

If you read my eBooks free online then please consider hiring me for consulting work [https://markwatson.com](https://markwatson.com).

This is this edition released September 2024.

Please visit the [author's website](http://markwatson.com).

# Preface

While this is a book on the Hy Lisp language, we have a wider theme here. In an age where artificial intelligence (AI) is a driver of the largest corporations and government agencies, the question is how do individuals and small organizations take advantage of AI technologies given the disadvantages of small scale. The material I chose to write about here is selected to help you, dear reader, survive as a healthy small fish in a big bond.

I have been using Lisp languages professionally since 1982 and have written books covering the Common Lisp and Scheme languages. Most of my career has involved working on AI projects so tools for developing AI applications will be a major theme. In addition to covering the Hy language, you will get experience with AI tools and techniques that will help you craft your own AI platforms regardless of whether you are a consultant, work at a startup, or a corporation.

The latest version of this book (updated in May 2023) has major code changes that were required to support changes in the Hy language version 0.26.0.

The code examples can be found in my GitHub repository [https://github.com/mark-watson/hy-lisp-python](https://github.com/mark-watson/hy-lisp-python).

This book covers many programming topics using the Lisp language **Hy** that compiles to Python AST and is compatible with code, libraries, and frameworks written in Python. The main topics we will cover and write example applications for are:

- Relational and graph databases
- Web app development
- Web scraping
- Accessing semantic web and linked data sources like Wikipedia, DBpedia, and Wikidata
- Automatically constructing Knowledge Graphs from text documents, semantic web and linked data
- Deep Learning
- Natural Language Processing (NLP) using Deep Learning

The topics were chosen because of my work experience and the theme of this book is  how to increase programmer productivity and happiness using a Lisp language in a bottom-up development style. This style relies heavily on the use of an interactive REPL for exploring APIs and writing new code. I chose the above topics based on my experience working as a developer and researcher. Please note: you will see the term REPL frequently in this book. REPL stands for *Read Eval Print Loop*.

Some of the examples are very simple (e.g., the web app examples) while some are more complex (e.g., Deep Learning and knowledge graph examples). Regardless of the simplicity or complexity of the examples I hope that you find the code interesting, useful in your projects, and fun to experiment with.

## Requests from the Author

This book will always be available to read free online at [https://leanpub.com/hy-lisp-python/read](https://leanpub.com/hy-lisp-python/read).

That said, I appreciate it when readers purchase my books because the income enables me to spend more time writing.

### Hire the Author as a Consultant

I am available for short consulting projects. Please see [https://markwatson.com](https://markwatson.com).

## Setting Up Your Development Environment

In September 2024 I changed the way that I build and run both Hy language and Python scripts and programs. I now use **venv** and install dependencies in each Hy or Python project directory. I use a shell script **venv_setup.sh** that I keep on my **PATH** to create a directory **venv**. Please note that this method uses more disk space but keeps the dependencies of each small of large project separate.

```shell
#!/bin/zsh

# Check if the directory has a requirements.txt file
if [ ! -f "requirements.txt" ]; then
    echo "No requirements.txt file found in the current directory."
    exit 1
fi

# Create a virtual environment in the .venv directory
python3 -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Upgrade pip to the latest version
pip3 install --upgrade pip

# Install dependencies from requirements.txt
pip3 install -r requirements.txt

# Display installed packages
pip3 list

echo "Virtual environment setup complete. Activate it with:"
echo "source venv/bin/activate"
echo ""
```

You will find **requirements.txt** files in most example subdirectories for this book.

To free disk space for the **venv** directories, I define a top level **Makefile** in the GitGub repository for the example programs [https://github.com/mark-watson/hy-lisp-python](https://github.com/mark-watson/hy-lisp-python):

```
clean:
	rm -rf */__pycache__ */venv
```


## What is Lisp Programming Style?

I will give some examples here and also show exploratory Hy language REPL examples later in the book. How often do you search the web for documentation on how to use a library, write some code only to discover later that you didn't use the API correctly? I reduce the amount of time that I spend writing code by having a Lisp REPL open so that I can experiment with API calls and returned results while reading the documentation.

When I am working on new code or a new algorithm I like to have a Lisp REPL open and try short snippets of code to get working code for solving low level problems, building up to more complex code. As I figure out how to do things I enter code that works and which I want to keep in a text editor and then convert this code into my own library. I then iterate on loading my new library into a REPL and stress test it, look for API improvements, etc.

I find, in general, that a "bottom-up" approach gets me to working high quality systems faster than spending too much time doing up front planning and design. The problem with spending too much up front time on design is that we change our minds as to what makes the most sense to solve a problem as we experiment with code. I try to avoid up front time spent on work that I will have to re-work or even toss out.

## Hy is Python, But With a Lisp Syntax

When I need a library for a Hy project I search for Python libraries and either write a thin Hy language "wrapper" around the Python library or just call the Python APIs directly from Hy code. You will see many examples of both approaches in this book.

## How This Book Reflects My Views on Artificial Intelligence and the Future of Society and Technology

Since starting work on AI in 1982 I have seen the field progress from a niche technology where even international conferences had small attendances to a field that is generally viewed as transformative. In the USA there is legitimate concern that economic adversaries like China will exceed our abilities to develop core AI technologies and integrate these technologies into commercial and military systems. As I write this in February 2020, some people in our field including myself believe that the Chinese company Baidu may have already passed Google and Microsoft in applied AI.

Even though most of my professional work in the last five years has been in Deep Learning (and before that I worked with the Knowledge Graph at Google on a knowledge representation problem and application), I believe that human level Artificial General Intelligence (AGI) will use hybrid Deep Learning, "old fashioned" symbolic AI, and techniques that we have yet to discover.

This belief that Deep Learning will not get us to AGI capabilities is a motivation for me to use the Hy language because it offers transparent access to Python Deep Learning frameworks with a bottom-up Lisp development style that I have used for decades using symbolic AI and knowledge representation.

I hope you find that Hy meets your needs as it does my own.

## About the Book Cover

The official Hy Language logo is an octopus:

{width=22%}
![The Hy Language logo Cuddles by Karen Rustad](images/hylisplogo.jpg)

Usually I use photographs that I take myself for covers of my LeanPub books. Although I have SCUBA dived since I was 13 years old, sadly I have no pictures of an octopus that I have taken myself. I did find a public domain picture I liked (that is the cover of this book) on Wikimedia. **Cover Credit**: Thanks to Wikimedia user Pseudopanax for placing the cover image in the public domain.

## A Request from the Author

I spent time writing this book to help you, dear reader. I release this book under the Creative Commons "share and share alike, no modifications, no commercial reuse" license and set the minimum purchase price to $8.00 in order to reach the most readers. You can read this book for free online or purchase it by visiting [https://leanpub.com/hy-lisp-python](https://leanpub.com/hy-lisp-python).

If you would like to support my work please consider purchasing my books on [Leanpub](https://leanpub.com/u/markwatson) and star my git repositories that you find useful on [GitHub](https://github.com/mark-watson?tab=repositories&q=&type=public). You can also interact with me on social media on [Mastodon](https://mastodon.social/@mark_watson) and [Twitter](https://twitter.com/mark_l_watson).

I enjoy writing and your support helps me write new editions and updates for my books and to develop new book projects. Thank you!

## Acknowledgements

I thank my wife Carol for editing this manuscript, finding typos, and suggesting improvements.

I would like to thank Pascal (Reddit user chuchana) for corrections and suggestions. I would like to thank Carlos Ungil for catching a typo and reporting it. I would like to thank Jud Taylor for finding several typo errors. I would like to thank Dave Smythe for finding some typos.
