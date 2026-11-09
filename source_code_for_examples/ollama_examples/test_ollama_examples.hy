;; Tests for tools.hy, completion_local.hy and completion_cloud.hy
;; --  run with:  uv run pytest
;;
;; Ollama and the HTTP calls made by the tools are replaced with fakes, so
;; neither an Ollama server nor network access is needed.

(import os)
(import re)
(import types [SimpleNamespace])
(import tools)
(import completion-local)
(import completion-cloud)


;; ---------- helpers ----------

(defclass FakeHttpResponse []
  "Stand-in for an httpx.Response."
  (defn __init__ [self text [status-code 200] [payload None]]
    (setv self.text text  self.status-code status-code  self.payload payload))
  (defn raise-for-status [self] None)
  (defn json [self] self.payload))

(defn fake-httpx-get [captured response]
  (fn [url #** kwargs]
    (.append captured #(url kwargs))
    response))


;; ---------- local file and clock tools ----------

(defn test-list-directory [tmp-path monkeypatch]
  (.write-text (/ tmp-path "a.txt") "x")
  (monkeypatch.chdir tmp-path)
  (setv result (tools.list-directory))
  (assert (in (os.path.realpath tmp-path) result))
  (assert (in "a.txt" result)))

(defn test-write-then-read-file [tmp-path]
  (setv path (str (/ tmp-path "out.txt")))
  (assert (= (tools.write-file-contents path "Hello from Ollama tools!")
             f"Successfully wrote to {path}"))
  (assert (= (tools.read-file-contents path) "Hello from Ollama tools!")))

(defn test-get-current-datetime-format []
  (assert (re.fullmatch r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"
                        (tools.get-current-datetime))))


;; ---------- web tools (fake httpx) ----------

(defn test-uri-to-markdown [monkeypatch]
  (setv captured [])
  (monkeypatch.setattr tools.httpx "get"
    (fake-httpx-get captured (FakeHttpResponse "<h1>Title</h1><p>Body text</p>")))
  (setv md (tools.uri-to-markdown "https://example.com"))
  (assert (.startswith md "# Content from https://example.com"))
  (assert (in "Title\n=====" md))
  (assert (in "Body text" md)))

(defn test-get-weather [monkeypatch]
  (setv captured [])
  (monkeypatch.setattr tools.httpx "get"
    (fake-httpx-get captured (FakeHttpResponse "London: ⛅️ +12°C\n")))
  (assert (= (tools.get-weather "London") "London: ⛅️ +12°C"))
  (assert (= (get captured 0 0) "https://wttr.in/London?format=3")))

(defn test-search-wikipedia-success [monkeypatch]
  (setv captured [])
  (monkeypatch.setattr tools.httpx "get"
    (fake-httpx-get captured
      (FakeHttpResponse "" :payload {"extract" "Lisp is a family of languages."})))
  (assert (= (tools.search-wikipedia "Lisp (programming language)")
             "Lisp is a family of languages."))
  (setv [url kwargs] (get captured 0))
  (assert (= url "https://en.wikipedia.org/api/rest_v1/page/summary/Lisp_(programming_language)"))
  (assert (in "User-Agent" (get kwargs "headers"))))

(defn test-search-wikipedia-failure [monkeypatch]
  (monkeypatch.setattr tools.httpx "get"
    (fake-httpx-get [] (FakeHttpResponse "" :status-code 404)))
  (assert (= (tools.search-wikipedia "Nope") "Failed to fetch Wikipedia page for Nope")))

(defn test-get-npr-news-takes-first-five-items [monkeypatch]
  (setv items (.join ""
                (gfor i (range 7)
                  f"<item><title>T{i}</title><description>D{i}</description><link>L{i}</link></item>")))
  (monkeypatch.setattr tools.httpx "get"
    (fake-httpx-get [] (FakeHttpResponse f"<rss><channel>{items}</channel></rss>")))
  (setv md (tools.get-npr-news))
  (assert (.startswith md "# NPR Top News"))
  (assert (in "## [T0](L0)\nD0" md))
  (assert (in "## [T4](L4)" md))
  (assert (not-in "T5" md)))


;; ---------- completions (fake Ollama) ----------

(defn test-completion-local [monkeypatch]
  (setv captured {})
  (defn fake-chat [#** kwargs]
    (.update captured kwargs)
    (SimpleNamespace :message (SimpleNamespace :content "45, 33 and 12")))
  (monkeypatch.setattr completion-local.ollama "chat" fake-chat)
  (assert (= (completion-local.completion "ages?") "45, 33 and 12"))
  ;; the prompt argument (not a global) is sent to the model
  (assert (= (get captured "messages") [{"role" "user" "content" "ages?"}])))

(defn test-completion-cloud [monkeypatch]
  (setv captured {})
  (defn fake-chat [model #** kwargs]
    (setv (get captured "model") model)
    (.update captured kwargs)
    {"message" {"role" "assistant" "content" "cloud answer"}})
  (monkeypatch.setattr completion-cloud "client" (SimpleNamespace :chat fake-chat))
  (assert (= (completion-cloud.completion "hi") "cloud answer"))
  (assert (= (get captured "model") "gpt-oss:20b"))
  (assert (= (get captured "stream") False))
  (assert (= (get captured "messages") [{"role" "user" "content" "hi"}])))
