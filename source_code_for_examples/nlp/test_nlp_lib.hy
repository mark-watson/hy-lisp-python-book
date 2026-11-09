;; Tests for nlp_lib.hy  --  run with:  uv run pytest
;;
;; These tests need the spaCy model:  uv run python -m spacy download en_core_web_sm
;; If the model is not installed the tests are skipped.

(import pytest)

(pytest.importorskip "en_core_web_sm"
  :reason "spaCy model en_core_web_sm is not installed")

(import nlp-lib [nlp])


(defn entity-types [result]
  (dfor [text label] (get result "entities") text label))


(defn test-nlp-returns-text-and-tokens []
  (setv text "Lucy threw a ball to Bill and he caught it")
  (setv result (nlp text))
  (assert (= (get result "text") text))
  (assert (= (lfor t (get result "tokens") (cut text (get t "start") (get t "end")))
             (.split text))))

(defn test-nlp-finds-person-and-place []
  (setv ents (entity-types
               (nlp "President George Bush went to Mexico and he had a very good meal")))
  (assert (= (.get ents "George Bush") "PERSON"))
  (assert (= (.get ents "Mexico") "GPE")))

(defn test-nlp-entities-are-pairs []
  (setv result (nlp "Microsoft hired Bill Gates in Seattle"))
  (assert (all (gfor e (get result "entities")
                 (and (isinstance e list) (= (len e) 2))))))

(defn test-nlp-no-entities []
  (assert (= (get (nlp "the cat sat on the mat") "entities") [])))
