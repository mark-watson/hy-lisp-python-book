;; Tests for search_llm.hy  --  run with:  uv run pytest
;;
;; openai.OpenAI is replaced with a fake, so no API key or network access is
;; needed.

(import types [SimpleNamespace])
(import search-llm)


(defn install-fake-openai [monkeypatch]
  "Replace openai.OpenAI; returns a dict recording constructor and call args."
  (setv captured {})
  (defn create [#** kwargs]
    (setv (get captured "create") kwargs)
    (SimpleNamespace
      :choices [(SimpleNamespace
                  :message (SimpleNamespace :content "He plays guitar and didgeridoo."))]))
  (defn fake-openai [#** kwargs]
    (setv (get captured "client") kwargs)
    (SimpleNamespace
      :chat (SimpleNamespace :completions (SimpleNamespace :create create))))
  (monkeypatch.setattr search-llm.openai "OpenAI" fake-openai)
  captured)


(defn test-search-llm-returns-content [monkeypatch]
  (install-fake-openai monkeypatch)
  (assert (= (search-llm.search_llm "What does he play?")
             "He plays guitar and didgeridoo.")))

(defn test-search-llm-uses-perplexity-endpoint [monkeypatch]
  (setv captured (install-fake-openai monkeypatch))
  (monkeypatch.setattr search-llm "YOUR_API_KEY" "pplx-test")
  (search-llm.search_llm "q")
  (assert (= (get captured "client")
             {"api_key" "pplx-test" "base_url" "https://api.perplexity.ai"})))

(defn test-search-llm-messages [monkeypatch]
  (setv captured (install-fake-openai monkeypatch))
  (search-llm.search_llm "What is Hy?")
  (setv create (get captured "create"))
  (assert (= (get create "model") "sonar"))
  (setv [system user] (get create "messages"))
  (assert (= system search-llm.system-message))
  (assert (= user {"role" "user" "content" "What is Hy?"})))
