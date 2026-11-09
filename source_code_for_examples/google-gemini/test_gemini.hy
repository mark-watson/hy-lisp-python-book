;; Tests for the Gemini examples  --  run with:  uv run pytest
;;
;; The Gemini SDK client and requests.post are replaced with fakes, so no API
;; key or network access is needed. conftest.py sets a placeholder
;; GOOGLE_API_KEY because genai.Client() is created at import time.

(import json)
(import types [SimpleNamespace])
(import chat)
(import ui-chat)
(import web-search)
(import context-url)


;; ---------- helpers ----------

(defclass FakeResponse []
  "Stand-in for a requests.Response."
  (defn __init__ [self payload] (setv self.payload payload))
  (defn raise-for-status [self] None)
  (defn json [self] self.payload))

(defn fake-post [captured payload]
  (fn [url #** kwargs]
    (.update captured kwargs)
    (setv (get captured "url") url)
    (FakeResponse payload)))

(defn fake-genai-client [captured text]
  "Object shaped like genai.Client with a models.generate_content method."
  (defn generate-content [#** kwargs]
    (.update captured kwargs)
    (SimpleNamespace :text text))
  (SimpleNamespace :models (SimpleNamespace :generate-content generate-content)))

(setv reply {"candidates" [{"content" {"role" "model" "parts" [{"text" "Hi!"}]}}]})
(setv history [{"role" "user" "parts" [{"text" "earlier question"}]}
               {"role" "model" "parts" [{"text" "earlier answer"}]}])


;; ---------- chat.hy ----------

(defn test-chat-call-gemini-builds-request [monkeypatch]
  (setv captured {})
  (monkeypatch.setattr chat.requests "post" (fake-post captured reply))
  (assert (= (chat.call-gemini history "new question") reply))
  (assert (in "gemini-2.5-flash:generateContent" (get captured "url")))
  (setv body (json.loads (get captured "data")))
  (assert (= (get body "contents")
             (+ history [{"role" "user" "parts" [{"text" "new question"}]}])))
  (assert (= (get body "generationConfig" "maxOutputTokens") 2000)))

(defn test-chat-call-gemini-does-not-mutate-history [monkeypatch]
  (monkeypatch.setattr chat.requests "post" (fake-post {} reply))
  (setv h (list history))
  (chat.call-gemini h "q")
  (assert (= h history)))


;; ---------- ui_chat.hy ----------

(defn test-ui-call-gemini-without-search [monkeypatch]
  (setv captured {})
  (monkeypatch.setattr ui-chat.requests "post" (fake-post captured reply))
  (assert (= (ui-chat.call-gemini [] "hello" False "gemini-2.5-pro" 0.3) reply))
  (assert (in "/models/gemini-2.5-pro:generateContent" (get captured "url")))
  (assert (= (get captured "timeout") 60))
  (setv body (json.loads (get captured "data")))
  (assert (not-in "tools" body))
  (assert (= (get body "generationConfig" "temperature") 0.3)))

(defn test-ui-call-gemini-with-search [monkeypatch]
  (setv captured {})
  (monkeypatch.setattr ui-chat.requests "post" (fake-post captured reply))
  (ui-chat.call-gemini history "news?" True "gemini-2.5-flash" 1.0)
  (setv body (json.loads (get captured "data")))
  (assert (= (get body "tools") [{"google_search" {}}]))
  (assert (= (len (get body "contents")) 3)))


;; ---------- web_search.hy and context_url.hy ----------

(defn test-web-search [monkeypatch]
  (setv captured {})
  (monkeypatch.setattr web-search "client" (fake-genai-client captured "search answer"))
  (assert (= (web-search.web-search "latest news") "search answer"))
  (assert (= (get captured "contents") "latest news"))
  (assert (= (get captured "model") "gemini-2.5-flash"))
  (assert (= (get captured "config") {"tools" [{"google_search" {}}]})))

(defn test-context-qa [monkeypatch]
  (setv captured {})
  (monkeypatch.setattr context-url "client" (fake-genai-client captured "page answer"))
  (setv prompt "https://example.com What is this page about?")
  (assert (= (context-url.context_qa prompt) "page answer"))
  (assert (= (get captured "contents") prompt))
  (assert (= (get captured "config") {"tools" [{"url_context" {}}]})))


;; ---------- HTTP errors ----------

(import pytest)
(import requests)

(defclass ErrorResponse []
  (defn raise-for-status [self] (raise (requests.HTTPError "400 Bad Request")))
  (defn json [self] {}))

(defn test-chat-call-gemini-raises-http-errors [monkeypatch]
  (monkeypatch.setattr chat.requests "post" (fn [url #** kw] (ErrorResponse)))
  (with [(pytest.raises requests.HTTPError)]
    (chat.call-gemini [] "q")))

(defn test-ui-call-gemini-raises-http-errors [monkeypatch]
  (monkeypatch.setattr ui-chat.requests "post" (fn [url #** kw] (ErrorResponse)))
  (with [(pytest.raises requests.HTTPError)]
    (ui-chat.call-gemini [] "q" False "gemini-2.5-flash" 1.0)))
