;; Tests for web_site_qa.hy  --  run with:  uv run pytest
;;
;; requests.get is replaced with a fake, so the scraping tool is tested
;; without network access. The agent itself is only inspected, never run,
;; so Ollama does not need to be running.

(import requests)
(import agno.tools.function [Function])
(import web-site-qa :as qa)


;; ---------- helpers ----------

(defclass FakeResponse []
  (defn __init__ [self text [error None]]
    (setv self.text text  self.error error))
  (defn raise-for-status [self]
    (when self.error (raise self.error))))

(defn install-fake-get [monkeypatch response]
  (setv captured {})
  (defn fake-get [url #** kwargs]
    (setv (get captured "url") url)
    (.update captured kwargs)
    response)
  (monkeypatch.setattr qa.requests "get" fake-get)
  captured)

;; The @tool decorator wraps the Hy function in an agno Function object;
;; its .entrypoint is the original function.
(defn scrape [url] (qa.scrape-website-content.entrypoint url))

(setv sample-html
  (+ "<html><head><style>body {color: red}</style>"
     "<script>var hidden = 1;</script></head><body>"
     "<nav>Menu</nav><p>Mark plays guitar.</p><p>He also plays didgeridoo.</p>"
     "<aside>Ad</aside><footer>Copyright</footer></body></html>"))


;; ---------- scrape-website-content ----------

(defn test-scrape-extracts-visible-text [monkeypatch]
  (install-fake-get monkeypatch (FakeResponse sample-html))
  (setv result (scrape "https://example.com"))
  (assert (.startswith result "Successfully scraped content from https://example.com:"))
  (assert (in "Mark plays guitar.\nHe also plays didgeridoo." result)))

(defn test-scrape-removes-unwanted-tags [monkeypatch]
  (install-fake-get monkeypatch (FakeResponse sample-html))
  (setv result (scrape "https://example.com"))
  (for [unwanted ["var hidden" "color: red" "Menu" "Ad" "Copyright"]]
    (assert (not-in unwanted result))))

(defn test-scrape-sends-browser-headers-and-timeout [monkeypatch]
  (setv captured (install-fake-get monkeypatch (FakeResponse sample-html)))
  (scrape "https://example.com")
  (assert (= (get captured "url") "https://example.com"))
  (assert (= (get captured "timeout") 10))
  (assert (in "Mozilla/5.0" (get captured "headers" "User-Agent"))))

(defn test-scrape-page-without-text [monkeypatch]
  (install-fake-get monkeypatch (FakeResponse "<html><script>x=1</script></html>"))
  (assert (= (scrape "https://example.com")
             "Connected to https://example.com, but no text content could be extracted.")))

(defn test-scrape-http-error-propagates [monkeypatch]
  (import pytest)
  (install-fake-get monkeypatch
    (FakeResponse "" :error (requests.HTTPError "404 Not Found")))
  (with [(pytest.raises requests.HTTPError)]
    (scrape "https://example.com/missing")))


;; ---------- agent configuration ----------

(defn test-scraper-is-registered-as-agno-tool []
  (assert (isinstance qa.scrape-website-content Function))
  (assert (= qa.scrape-website-content.name "scrape_website_content")))

(defn test-agent-configuration []
  (setv agent qa.scraper-agent)
  (assert (= agent.model.id "qwen3:30b"))
  (assert (in qa.scrape-website-content agent.tools))
  (assert agent.markdown)
  (assert (in "Scrape Phase" agent.instructions)))
