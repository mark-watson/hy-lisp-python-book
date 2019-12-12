# Natural Language Processing

I have been working in the field of NLP since 1985 so I 'lived through' the revolutionary change in NLP that occurred in sincd 2014: deep learning results out-classed results from previous symbolic methods.

I will not cover older symbolic methods of NLP here, rather I refer you to my previous books [Practical Artificial Intelligence Programming With Java](https://leanpub.com/javaai), [Loving Common Lisp, or the Savvy Programmer's Secret Weapon](https://leanpub.com/lovinglisp), and [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook).

You will learn how to apply both DL and NLP in two stages: develop low level "small feature" implementations to understand the underlying technology, and use state of the art full-feature libraries. You will need some math background for the first stage so if you are not interested or don't have the required background, you can still learn to effectively use these technologies by just studying through the second stages where we use industry standard libraries.

TBD - update previous intro!!

## Implementing the HyNLP Wrapper for the Python spaCy Library

TBD

We will generate two libraries, one a general NLP library and one that specifically solves the anaphora resolution, or coreference, problem.

For a later example automatically generating Knowledge Graphs from text data, we will need the ability to find person, company, location, etc. names in text. We use spaCy here to do this. The types of named entities that spaCy is pre-trained that includes:

- CARDINAL: any number that is not identified as a more specific type, like money, time, etc.
- DATE
- FAC: facilities like highways, bridges, airports, etc.
- GPE: Countries, states (or provinces), and cities
- LOC: any non-GPE location
- PRODUCT
- EVENT
- LANGUAGE: any named language
- MONEY: any monetary value or unit of money
- NORP: nationalities or religious groups
- ORG: any organization like a company, non-profit, school, etc.
- PERCENT: any number in \[0, 100\] followed by the percent % character
- PERSON
- ORDINAL: any number spelled out, like "one", "two", etc.
- TIME


{lang="hylang",linenos=on}
~~~~~~~~


~~~~~~~~




{lang="hylang",linenos=on}
~~~~~~~~


~~~~~~~~




{lang="hylang",linenos=on}
~~~~~~~~


~~~~~~~~


Listing of coref_nlp_lib.hy:

{lang="hylang",linenos=on}
~~~~~~~~
(import argparse os)
(import spacy neuralcoref)

(setv nlp2 (spacy.load "en"))
(neuralcoref.add_to_pipe nlp2)

(defn coref-nlp [some-text]
  (setv doc (nlp2 some-text))
  { "corefs" doc._.coref_resolved
    "clusters" doc._.coref_clusters
    "scores" doc._.coref_scores})
~~~~~~~~


Listing of coref_example.hy:


{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import [coref-nlp-lib [coref-nlp]])

;; tests:
(print (coref-nlp "President George Bush went to Mexico and he had a very good meal"))
(print (coref-nlp "Lucy threw a ball to Bill and he caught it"))
~~~~~~~~

The output will look like:

{lang="hylang",linenos=on}
~~~~~~~~
Marks-MacBook:nlp $ ./coref_example.hy 
{'corefs': 'President George Bush went to Mexico and President George Bush had a very good meal', 'clusters': [President George Bush: [President George Bush, he]], 'scores': {President George Bush: {President George Bush: 1.5810412168502808}, George Bush: {George Bush: 4.11817741394043, President George Bush: -1.546141266822815}, Mexico: {Mexico: 1.4138349294662476, President George Bush: -4.650205612182617, George Bush: -3.666614532470703}, he: {he: -0.5704692006111145, President George Bush: 9.38597583770752, George Bush: -1.4178757667541504, Mexico: -3.6565260887145996}, a very good meal: {a very good meal: 1.652894377708435, President George Bush: -2.5543758869171143, George Bush: -2.13267183303833, Mexico: -1.6889561414718628, he: -2.7667927742004395}}}

{'corefs': 'Lucy threw a ball to Bill and Bill caught a ball', 'clusters': [a ball: [a ball, it], Bill: [Bill, he]], 'scores': {Lucy: {Lucy: 0.41820740699768066}, a ball: {a ball: 1.8033190965652466, Lucy: -2.721518039703369}, Bill: {Bill: 1.5611814260482788, Lucy: -2.8222298622131348, a ball: -1.806389570236206}, he: {he: -0.5760076642036438, Lucy: 3.054243326187134, a ball: -1.818403720855713, Bill: 3.077427625656128}, it: {it: -1.0269954204559326, Lucy: -3.4972281455993652, a ball: -0.31290221214294434, Bill: -2.5343685150146484, he: -3.6687228679656982}}}
~~~~~~~~





Anaphora resolution, also called coreference, refers to two or more words or phrases in an input text refer to the same noun.
