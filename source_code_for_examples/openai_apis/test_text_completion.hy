;; Tests for text_completion.hy  --  run with:  uv run pytest
;;
;; The OpenAI client is replaced with a fake, so no API key or network access
;; is needed. conftest.py sets a placeholder OPENAI_API_KEY because the client
;; is created at import time.

(import types [SimpleNamespace])
(import text-completion)


(defn fake-client [captured]
  (defn create [#** kwargs]
    (.update captured kwargs)
    (SimpleNamespace
      :choices [(SimpleNamespace
                  :message (SimpleNamespace :role "assistant"
                                            :content "Turn off the water first."))]))
  (SimpleNamespace
    :chat (SimpleNamespace :completions (SimpleNamespace :create create))))


(defn test-completion-returns-first-choice [monkeypatch]
  (setv captured {})
  (monkeypatch.setattr text-completion "client" (fake-client captured))
  (setv choice (text-completion.completion "how to fix leaky faucet?"))
  (assert (= choice.message.content "Turn off the water first.")))

(defn test-completion-request [monkeypatch]
  (setv captured {})
  (monkeypatch.setattr text-completion "client" (fake-client captured))
  (text-completion.completion "hello")
  (assert (= (get captured "model") "gpt-5"))
  (assert (= (get captured "messages") [{"role" "user" "content" "hello"}])))
