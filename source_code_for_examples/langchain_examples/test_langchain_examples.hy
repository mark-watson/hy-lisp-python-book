;; Tests for country_information.hy and directions_template.hy
;; --  run with:  uv run pytest
;;
;; The OpenAI LLM is replaced with a fake, so no API key or network access is
;; needed. conftest.py sets a placeholder OPENAI_API_KEY because the LLM
;; object is created at import time. doc_search.hy is not tested: it builds
;; a Chroma index with OpenAI embeddings as soon as it is loaded.

(import country-information)
(import directions-template)


(defclass FakeLLM []
  (defn __init__ [self reply] (setv self.reply reply  self.prompts []))
  (defn invoke [self prompt]
    (.append self.prompts prompt)
    self.reply))


(defn test-country-information-prompt [monkeypatch]
  (setv llm (FakeLLM "Berlin, 83 million"))
  (monkeypatch.setattr country-information "llm" llm)
  (assert (= (country-information.get_country_information "Germany")
             "Berlin, 83 million"))
  (assert (= llm.prompts
             ["Predict the capital and population of a country.\n\nCountry: Germany\nCapital:\nPopulation:\n"])))

(defn test-directions-prompt [monkeypatch]
  (setv llm (FakeLLM "Walk two blocks north."))
  (monkeypatch.setattr directions-template "llm" llm)
  (assert (= (directions-template.get_directions "get to the store")
             "Walk two blocks north."))
  (assert (= llm.prompts ["How do I get to the store?"])))

(defn test-llm-settings []
  (assert (= country-information.llm.temperature 0.9))
  (assert (= directions-template.llm.temperature 0.9)))
