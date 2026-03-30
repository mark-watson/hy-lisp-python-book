#!/usr/bin/env hy

;; Example file demonstrating Hylang NLP entity recognition
;; This file shows how to use the nlp function from nlp-lib to
;; extract named entities from text.

(import nlp-lib [nlp])

;; Example 1: Extract entities from a statement about a person going abroad
(print "Example 1 - Entity extraction from George Bush sentence:")
(print (nlp "President George Bush went to Mexico and he had a very good meal"))

;; Example 2: Extract entities from a sentence with ambiguous pronouns
;; Note: This will extract "Bill" and "he" - showing how NLP handles
;; pronoun references in dependency parsing
(print "Example 2 - Entity extraction from Lucy threw a ball sentence:")
(print (nlp "Lucy threw a ball to Bill and he caught it"))
