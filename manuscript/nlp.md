# Natural Language Processing

I have been working in the field of Natural Language Processing (NLP) since 1985 so I 'lived through' the revolutionary change in NLP that has occurred since 2014: Deep Learning results out-classed results from previous symbolic methods.

I will not cover older symbolic methods of NLP here, rather I refer you to my previous books [Practical Artificial Intelligence Programming With Java](https://leanpub.com/javaai), [Loving Common Lisp, or the Savvy Programmer's Secret Weapon](https://leanpub.com/lovinglisp), and [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) for examples. We get better results using Deep Learning (DL) for NLP and the library **spaCy** that we use in this chapter provides near state of the art performance and the authors of **spaCy** frequently update it to use the latest breakthroughs in the field.

You will learn how to apply both DL and NLP by using the state-of-the-art full-feature library [spaCy](https://spacy.io/). This chapter concentrates on how to use spaCy in the Hy language for solutions to a few selected problems in NLP that I use in my own work. I urge you to also review the "Guides" section of the [spaCy documentation](https://spacy.io/usage) where examples are in Python but after experimenting with the examples in this chapter you should have no difficulty in translating any spaCy Python examples to the Hy language.

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

In lines 3-6 we import the spaCy library, load the English language model, and create a document from input text. What is a spaCy document? In line 9 we use the standard Python function **dir** to look at all names and functions defined for the object **doc** returned from applying a spaCy model to a string containing text. The value printed shows many built in "dunder" (double underscore attributes), and we can remove these:

In lines 23-26 we use the **dir** function again to see the attributes and methods for this class, but filter out any attributes containing the characters "__":

{lang="hy",linenos=on, number-from=23}
~~~~~~~~
=> (lfor
... x (dir doc)
... :if (not (.startswith x "__"))
... x)
['_', '_bulk_merge', '_py_tokens', '_realloc', '_vector', '_vector_norm', 'cats', 'char_span', 'count_by', 'doc', 'ents', 'extend_tensor', 'from_array', 'from_bytes', 'from_disk', 'get_extension', 'get_lca_matrix', 'has_extension', 'has_vector', 'is_nered', 'is_parsed', 'is_sentenced', 'is_tagged', 'lang', 'lang_', 'mem', 'merge', 'noun_chunks', 'noun_chunks_iterator', 'print_tree', 'remove_extension', 'retokenize', 'sentiment', 'sents', 'set_extension', 'similarity', 'tensor', 'text', 'text_with_ws', 'to_array', 'to_bytes', 'to_disk', 'to_json', 'user_data', 'user_hooks', 'user_span_hooks', 'user_token_hooks', 'vector', 'vector_norm', 'vocab']
=>
~~~~~~~~

The **to_json** method looks promising so we will import the Python pretty print library and look at the pretty printed result of calling the **to_json** method on our document stored in **doc**:

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

The JSON data is nested dictionaries. In a later chapter on Knowledge Graphs, we will want to get the named entities like people, organizations, etc., from text and use this information to automatically generate data for Knowledge Graphs. The values for the key **ents** (stands for "entities") will be useful. Notice that the words in the original text are specified by beginning and ending text token indices (values of **head** and **end** in lines 52 to 142).

The values for the key **tokens** listed on lines 42-132 contains the head (or starting index, ending index, the token number (**id**), and the part of speech (**pos**). We will list what the parts of speech mean later.

We would like the words for each entity to be concatenated into a single string for each entity and we do this here in lines 136-137 and see the results in lines 138-139.

I like to add the entity name strings back into the dictionary representing a document and line 140 shows the use of **lfor** to create a list of lists where the sublists contain the entity name as a single string and the type of entity. We list the entity types supported by spaCy in the next section.

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

We can also access each sentence as a separate string. In this example the original text used to create our sample document had only a single sentence so the **sents** property returns a list containing a single string:

{lang="hy",linenos=on, number-from=147}
~~~~~~~~
=> (list doc.sents)
[President George Bush went to Mexico and he had a very good meal]
=> 
~~~~~~~~


The last example showing how to use a spaCy document object is listing each word with its part of speech:


{lang="hy",linenos=on, number-from=150}
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

The following list shows the definitions for the part of speech (POS) tags:

-  ADJ: adjective
-  ADP: adposition
-  ADV: adverb
-  AUX: auxiliary verb
-  CONJ: coordinating conjunction
-  DET: determiner
-  INTJ: interjection
-  NOUN: noun
-  NUM: numeral
-  PART: particle
-  PRON: pronoun
-  PROPN: proper noun
-  PUNCT: punctuation
-  SCONJ: subordinating conjunction
-  SYM: symbol
-  VERB: verb
-  X: other



## Implementing a HyNLP Wrapper for the Python spaCy Library

We will generate two libraries (in files **nlp_lib.hy** and **coref_nlp_lib.hy**). The first is a general NLP library and the second specifically solves the anaphora resolution, or coreference, problem. There are test programs for each library in the files **nlp_example.hy** and **coref_example.hy**.

For an example in a later chapter, we will use the library developed here to automatically generate Knowledge Graphs from text data. We will need the ability to find person, company, location, etc. names in text. We use spaCy here to do this. The types of named entities on which spaCy is pre-trained includes:

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

Listing for hy-lisp-python/nlp/nlp_lib.hy:

{lang="hylang",linenos=on}
~~~~~~~~
(import spacy)

(setv nlp-model (spacy.load "en"))

(defn nlp [some-text]
  (setv doc (nlp-model some-text))
  (setv entities (lfor entity doc.ents [entity.text entity.label_]))
  (setv j (doc.to_json))
  (setv (get j "entities") entities)
  j)
 ~~~~~~~~


Listing for hy-lisp-python/nlp/nlp_example.hy:

{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import [nlp-lib [nlp]])

(print
  (nlp "President George Bush went to Mexico and he had a very good meal"))

(print
  (nlp "Lucy threw a ball to Bill and he caught it"))
~~~~~~~~



{lang="hylang",linenos=on}
~~~~~~~~
Marks-MacBook:nlp $ ./nlp_example.hy
{'text': 'President George Bush went to Mexico and he had a very good meal', 'ents': [{'start': 10, 'end': 21, 'label': 'PERSON'}, {'start': 30, 'end': 36, 'label': 'GPE'}], 'sents': [{'start': 0, 'end': 64}], 'tokens': 

  ..LOTS OF OUTPUT NOT SHOWN..
~~~~~~~~

Another common NLP task is coreference (or anaphora resolution) which is the process of resolving pronouns in text (e.g., he, she, it, etc.) with preceding proper nouns that pronouns refer to. A simple example would be translating "John ran fast and he fell" to "John ran fast and John fell." This is an easy example, but often proper nouns that pronouns refer to are in previous sentences and resolving coreference can be ambiguous and require knowledge of common word use and grammar. This problem is now handled by deep learning transfer models like [BERT](https://github.com/google-research/bert).

Listing of coref_nlp_lib.hy contains a wrapper for spaCy's coreference model:

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


Listing of coref_example.hy shows code to test the Hy spaCy coref wrapper:


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

Anaphora resolution, also called coreference, refers to two or more words or phrases in an input text refer to the same noun. This analysis usually entails identifying which noun phrases that pronouns refer to.

## Wrap-up

I spent several years of development time during the period from  1984 through 2015 working on natural language processing technology and as a personal side project I sold commercial NLP libraries that I wrote on my own time in Ruby and Common Lisp. The state-of-the-art of Deep Learning enhanced NLP is very good and the open source spaCy library makes excellent use of both conventional NLP technology and pre-trained Deep Learning models. I no longer spend very much time writing my own NLP libraries and instead use spaCy.

I urge you to read through the [spaCy documentation](https://spacy.io/api/doc) because we covered just basic functionality here that we will also need in the later chapter on automatically generating data for Knowledge Graphs. After working through the interactive REPL sessions and the examples in this chapter, you should be able to translate any Python API example code to Hy.