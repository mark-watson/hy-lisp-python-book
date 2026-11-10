# Cover Material, Copyright, and License

Copyright 2020-2026 Mark Watson. All rights reserved. This book may be shared using the Creative Commons “share and share alike, no modifications, no commercial reuse” license.

This eBook will be updated occasionally so please periodically check the [leanpub.com web page for this book](https://leanpub.com/hy-lisp-python) for updates.

If you read my eBooks free online then please consider hiring me for consulting work [https://markwatson.com](https://markwatson.com).

This is the edition released November 2026.

Please visit the [author's website](http://markwatson.com).

# Preface

While this is a book on the Hy Lisp language, we have a wider theme here. In an age where artificial intelligence (AI) is a driver of the largest corporations and government agencies, the question is how do individuals and small organizations take advantage of AI technologies given the disadvantages of small scale. The material I chose to write about here is selected to help you, dear reader, survive as a healthy small fish in a big bond.

I have been using Lisp languages professionally since 1982 and have written books covering the Common Lisp and Scheme languages. Most of my career has involved working on AI projects so tools for developing AI applications will be a major theme. In addition to covering the Hy language, you will get experience with AI tools and techniques that will help you craft your own AI platforms regardless of whether you are a consultant, work at a startup, or a corporation.

The code examples can be found in my GitHub repository [https://github.com/mark-watson/hy-lisp-python-book](https://github.com/mark-watson/hy-lisp-python-book) that contains code examples in the directory **source_code_for_examples** and the Markdown manuscript files for this book in the directory **manuscript**.

This book covers many programming topics using the Lisp language **Hy** that compiles to Python AST and is compatible with code, libraries, and frameworks written in Python. The main topics we will cover and write example applications for are:

- Deep Learning
- Large Language Models (LLMs), Evaluation, and Model Context Protocol (MCP)
- Lisp Macros, Metaprogramming, Modern Hy Tooling, and Asynchronous Programming
- Relational and graph databases, Knowledge Graph validation (SHACL), and GraphRAG
- Web app development
- Web scraping
- Accessing semantic web and linked data sources like Wikipedia, DBpedia, and Wikidata
- Automatically constructing Knowledge Graphs from text documents, semantic web and linked data
- Natural Language Processing (NLP) using Deep Learning

The topics were chosen because of my work experience and the theme of this book is  how to increase programmer productivity and happiness using a Lisp language in a bottom-up development style. This style relies heavily on the use of an interactive REPL for exploring APIs and writing new code. I chose the above topics based on my experience working as a developer and researcher. Please note: you will see the term REPL frequently in this book. REPL stands for *Read Eval Print Loop*.

Some of the examples are very simple (e.g., the web app examples) while some are more complex (e.g., Deep Learning and knowledge graph examples). Regardless of the simplicity or complexity of the examples I hope that you find the code interesting, useful in your projects, and fun to experiment with.

## Requests from the Author

This book will always be available to read free online at [https://leanpub.com/hy-lisp-python/read](https://leanpub.com/hy-lisp-python/read).

That said, I appreciate it when readers purchase my books because the income enables me to spend more time writing.

### Hire the Author as a Consultant

I am available for short consulting projects. Please see [https://markwatson.com](https://markwatson.com).

## Setting Up Your Development Environment

In August 2025 I changed the way that I build and run both Hy language and Python scripts and programs. I now use **uv** and install dependencies in each Hy or Python project directory. 

To free disk space for the **venv** directories, I define a top level **Makefile** in the GitGub repository for the example programs [https://github.com/mark-watson/hy-lisp-python-book](https://github.com/mark-watson/hy-lisp-python-book) in the subdirectory `source_code_for_examples`:

```
clean:
	rm -rf */__pycache__ */venv
```

### Optional: Emacs setup in .emacs file

I use the `straight` package manager. If you use something else the first line will need to be modified:

```lisp
(straight-use-package 'hy-mode)

;; Hy hylang:
;;  install:   uv tool install --force --python 3.12 hyuga

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '(hy-mode . ("hyuga"))))
(add-hook 'hy-mode-hook #'eglot-ensure)

(defun my/hy-setup-environment ()
  "Ensure the nearest .venv/bin is in exec-path, PATH, and sets hy-shell-interpreter."
  (let* ((root (locate-dominating-file default-directory ".venv"))
         (venv-bin (when root (expand-file-name ".venv/bin" root)))
         (venv-hy (when venv-bin (expand-file-name "hy" venv-bin))))
    (when (and venv-bin (file-directory-p venv-bin))
      ;; Prepend to exec-path if not already there
      (unless (member venv-bin exec-path)
        (setq exec-path (cons venv-bin exec-path)))
      ;; Prepend to process PATH environment variable
      (let ((current-path (getenv "PATH")))
        (unless (string-prefix-p (concat venv-bin ":") current-path)
          (setenv "PATH" (concat venv-bin ":" current-path))))
      ;; Set interpreter to the verified executable
      (when (file-executable-p venv-hy)
        (setq hy-shell-interpreter venv-hy)))))

(with-eval-after-load 'hy-mode
  (add-hook 'hy-mode-hook #'my/hy-setup-environment))

(with-eval-after-load 'hy-mode
  ;; Override the hardcoded (executable-find "hy") check across all hy-shell functions
  (defun my/hy-shell-bypass-executable-check (orig-fun &rest args)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (cmd)
                 (if (member cmd '("hy" "hyuga"))
                     (or (and (boundp 'hy-shell-interpreter)
                              (file-executable-p hy-shell-interpreter)
                              hy-shell-interpreter)
                         (funcall orig-fun cmd))
                   (funcall orig-fun cmd)))))
      (apply orig-fun args)))

  (advice-add 'hy-shell-eval-buffer :around #'my/hy-shell-bypass-executable-check)
  (advice-add 'hy-shell-eval-region :around #'my/hy-shell-bypass-executable-check)
  (advice-add 'hy-shell-eval-last-sexp :around #'my/hy-shell-bypass-executable-check)
  (advice-add 'hy-shell-start-or-switch-to-shell :around #'my/hy-shell-bypass-executable-check))
```


## What is Lisp Programming Style?

I will give some examples here and also show exploratory Hy language REPL examples later in the book. How often do you search the web for documentation on how to use a library, write some code only to discover later that you didn't use the API correctly? I reduce the amount of time that I spend writing code by having a Lisp REPL open so that I can experiment with API calls and returned results while reading the documentation.

When I am working on new code or a new algorithm I like to have a Lisp REPL open and try short snippets of code to get working code for solving low level problems, building up to more complex code. As I figure out how to do things I enter code that works and which I want to keep in a text editor and then convert this code into my own library. I then iterate on loading my new library into a REPL and stress test it, look for API improvements, etc.

I find, in general, that a "bottom-up" approach gets me to working high quality systems faster than spending too much time doing up front planning and design. The problem with spending too much up front time on design is that we change our minds as to what makes the most sense to solve a problem as we experiment with code. I try to avoid up front time spent on work that I will have to re-work or even toss out.

## Hy is Python, But With a Lisp Syntax

When I need a library for a Hy project I search for Python libraries and either write a thin Hy language "wrapper" around the Python library or just call the Python APIs directly from Hy code. You will see many examples of both approaches in this book.

## Acknowledgements

I thank my wife Carol for editing this manuscript, finding typos, and suggesting improvements.

I would like to thank Pascal (Reddit user chuchana) for corrections and suggestions. I would like to thank Carlos Ungil for catching a typo and reporting it. I would like to thank Jud Taylor for finding several typo errors. I would like to thank Dave Smythe for finding some typos.
