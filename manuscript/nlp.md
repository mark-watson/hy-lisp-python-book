# Natural Language Processing

I have been working in the field of NLP since 1985 so I 'lived through' the revolutionary change in NLP that occurred in sincd 2014: deep learning results out-classed results from previous symbolic methods.

I will not cover older symbolic methods of NLP here, rather I refer you to my previous books [Practical Artificial Intelligence Programming With Java](https://leanpub.com/javaai), [Loving Common Lisp, or the Savvy Programmer's Secret Weapon](https://leanpub.com/lovinglisp), and [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook).

You will learn how to apply both DL and NLP in two stages: develop low level "small feature" implementations to understand the underlying technology, and use state of the art full-feature libraries. You will need some math background for the first stage so if you are not interested or don't have the required background, you can still learn to effectively use these technologies by just studying through the second stages where we use industry standard libraries.

TBD - update previous intro!!

## Exploring the spaCy Library

We will use the Hy REPL to experiment with spaCy, Lisp style. The following REPL listings are all from the same session:

{lang="hy",linenos=on}
~~~~~~~~
Marks-MacBook:nlp $ hy
hy 0.17.0+108.g919a77e using CPython(default) 3.7.3 on Darwin
=> (import spacy)
=> (setv nlp-model (spacy.load "en"))
=> (setv doc (nlp-model "President George Bush went to Mexico and he had a very good meal"))
=> doc
President George Bush went to Mexico and he had a very good meal
=> (dir doc)
['_', '__bytes__', '__class__', '__delattr__', '__dir__', '__doc__', '__eq__', '__format__', '__ge__', '__getattribute__', '__getitem__', '__gt__', '__hash__', '__init__', '__init_subclass__', '__iter__', '__le__', '__len__', '__lt__', '__ne__', '__new__', '__pyx_vtable__', '__reduce__', '__reduce_ex__', '__repr__', '__setattr__', '__setstate__', '__sizeof__', '__str__', '__subclasshook__', '__unicode__', '_bulk_merge', '_py_tokens', '_realloc', '_vector', '_vector_norm', 'cats', 'char_span', 'count_by', 'doc', 'ents', 'extend_tensor', 'from_array', 'from_bytes', 'from_disk', 'get_extension', 'get_lca_matrix', 'has_extension', 'has_vector', 'is_nered', 'is_parsed', 'is_sentenced', 'is_tagged', 'lang', 'lang_', 'mem', 'merge', 'noun_chunks', 'noun_chunks_iterator', 'print_tree', 'remove_extension', 'retokenize', 'sentiment', 'sents', 'set_extension', 'similarity', 'tensor', 'text', 'text_with_ws', 'to_array', 'to_bytes', 'to_disk', 'to_json', 'user_data', 'user_hooks', 'user_span_hooks', 'user_token_hooks', 'vector', 'vector_norm', 'vocab']
~~~~~~~~


{lang="hy",linenos=on, number-from=23}
~~~~~~~~
=> (lfor
... x (dir doc)
... :if (not (.startswith x "__"))
... x)
['_', '_bulk_merge', '_py_tokens', '_realloc', '_vector', '_vector_norm', 'cats', 'char_span', 'count_by', 'doc', 'ents', 'extend_tensor', 'from_array', 'from_bytes', 'from_disk', 'get_extension', 'get_lca_matrix', 'has_extension', 'has_vector', 'is_nered', 'is_parsed', 'is_sentenced', 'is_tagged', 'lang', 'lang_', 'mem', 'merge', 'noun_chunks', 'noun_chunks_iterator', 'print_tree', 'remove_extension', 'retokenize', 'sentiment', 'sents', 'set_extension', 'similarity', 'tensor', 'text', 'text_with_ws', 'to_array', 'to_bytes', 'to_disk', 'to_json', 'user_data', 'user_hooks', 'user_span_hooks', 'user_token_hooks', 'vector', 'vector_norm', 'vocab']
=>
~~~~~~~~



{lang="hy",linenos=on, number-from=36}
~~~~~~~~
=> (import [pprint [pprint]])
=> (pprint (doc.to_json))
{'ents': [{'end': 21, 'label': 'PERSON', 'start': 10},
          {'end': 36, 'label': 'GPE', 'start': 30}],
 'sents': [{'end': 64, 'start': 0}],
 'text': 'President George Bush went to Mexico and he had a very good meal',
 'tokens': [{'dep': 'compound',
             'end': 9,
             'head': 2,
             'id': 0,
             'pos': 'PROPN',
             'start': 0,
             'tag': 'NNP'},
            {'dep': 'compound',
             'end': 16,
             'head': 2,
             'id': 1,
             'pos': 'PROPN',
             'start': 10,
             'tag': 'NNP'},
            {'dep': 'nsubj',
             'end': 21,
             'head': 3,
             'id': 2,
             'pos': 'PROPN',
             'start': 17,
             'tag': 'NNP'},
            {'dep': 'ROOT',
             'end': 26,
             'head': 3,
             'id': 3,
             'pos': 'VERB',
             'start': 22,
             'tag': 'VBD'},
            {'dep': 'prep',
             'end': 29,
             'head': 3,
             'id': 4,
             'pos': 'ADP',
             'start': 27,
             'tag': 'IN'},
            {'dep': 'pobj',
             'end': 36,
             'head': 4,
             'id': 5,
             'pos': 'PROPN',
             'start': 30,
             'tag': 'NNP'},
            {'dep': 'cc',
             'end': 40,
             'head': 3,
             'id': 6,
             'pos': 'CCONJ',
             'start': 37,
             'tag': 'CC'},
            {'dep': 'nsubj',
             'end': 43,
             'head': 8,
             'id': 7,
             'pos': 'PRON',
             'start': 41,
             'tag': 'PRP'},
            {'dep': 'conj',
             'end': 47,
             'head': 3,
             'id': 8,
             'pos': 'VERB',
             'start': 44,
             'tag': 'VBD'},
            {'dep': 'det',
             'end': 49,
             'head': 12,
             'id': 9,
             'pos': 'DET',
             'start': 48,
             'tag': 'DT'},
            {'dep': 'advmod',
             'end': 54,
             'head': 11,
             'id': 10,
             'pos': 'ADV',
             'start': 50,
             'tag': 'RB'},
            {'dep': 'amod',
             'end': 59,
             'head': 12,
             'id': 11,
             'pos': 'ADJ',
             'start': 55,
             'tag': 'JJ'},
            {'dep': 'dobj',
             'end': 64,
             'head': 8,
             'id': 12,
             'pos': 'NOUN',
             'start': 60,
             'tag': 'NN'}]}
=> 
~~~~~~~~


{lang="hy",linenos=on, number-from=134}
~~~~~~~~
=> doc.ents
(George Bush, Mexico)
=> (for [entity doc.ents]
... (print "entity text:" entity.text "entity label:" entity.label_))
entity text: George Bush entity label: PERSON
entity text: Mexico entity label: GPE
=> (lfor entity doc.ents [entity.text entity.label_])
[['George Bush', 'PERSON'], ['Mexico', 'GPE']]
=> 
~~~~~~~~


{lang="hy",linenos=on, number-from=147}
~~~~~~~~
=> (list doc.sents)
[President George Bush went to Mexico and he had a very good meal]
=> 
~~~~~~~~



{lang="hy",linenos=on, numberfrom=150}
~~~~~~~~
=> (for [word doc]
... (print word.text word.pos_))
President PROPN
George PROPN
Bush PROPN
went VERB
to ADP
Mexico PROPN
and CCONJ
he PRON
had VERB
a DET
very ADV
good ADJ
meal NOUN
=> 
~~~~~~~~





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
