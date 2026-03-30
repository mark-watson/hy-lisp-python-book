#!/usr/bin/env hy

;; NLP (Named Entity Recognition) library for Hylang
;; Uses spaCy for modern NLP entity extraction

;; Note: argparser and os commented out - not currently needed
;; (import argparse os)

(import spacy)

;; Pre-load the pretrained spaCy English model (English, small version)
;; This model is loaded once and reused for all NLP operations
;; spaCy provides high-accuracy entity labeling and dependency parsing
(setv nlp-model (spacy.load "en_core_web_sm"))

;; Hylang wrapper function for spaCy's Named Entity Recognition
;;
;; Args:
;;   some-text (string): Input text to analyze for named entities
;;
;; Returns:
;;   A JSON string containing:
;;   - "text": original input text
;;   - "entities": list of [entity_text, entity_type] pairs
;;     - entity_type labels: e.g., "PERSON", "GPE", "DATE",
;;       "ORG", "LOC", etc.
;;
;; Example usage:
;;   (nlp "George Bush went to Mexico")
(defn nlp [some-text]
  ;; Process the input text with spaCy model
  (setv doc (nlp-model some-text))
  ;; Convert spaCy's entity tuples to simple [text, type] pairs
  ;; lfor is a Python-style list comprehension in Hy
  (setv entities (lfor entity doc.ents [entity.text entity.label_]))
  ;; Convert the document to JSON
  (setv j (doc.to_json))
  ;; Insert transformed entities into the JSON under "entities" key
  (setv (get j "entities") entities)
  ;; Return the populated JSON string
  j)

;; Tests (uncomment to run):
;; (print (nlp "President George Bush went to Mexico and he had a very good meal"))
;; (print (nlp "Lucy threw a ball to Bill and he caught it"))
