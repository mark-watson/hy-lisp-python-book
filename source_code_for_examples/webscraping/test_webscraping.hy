;; Tests for the web scraping examples  --  run with:  uv run pytest
;;
;; Small HTML pages are written to a temporary directory, and urlopen is
;; replaced with a fake, so neither `make data` nor network access is needed.

(import bs4 [BeautifulSoup])
(import get-web-page)
(import get-page-data)
(import democracynow-front-page)
(import npr-front-page-summary)


;; ---------- helpers ----------

(defclass FakeResponse []
  (defn __init__ [self body] (setv self.body body))
  (defn read [self] self.body))

(setv long-headline "Scientists announce a remarkable discovery about deep ocean life")

(setv sample-html
  (+ "<html><head><title>Sample</title></head><body>"
     "<h1>Main</h1><h2>Sub</h2>"
     "<a href=\"/short\" class=\"nav\">Home</a>"
     "<a href=\"/empty\"></a>"
     f"<a href=\"/story\">  {long-headline}  </a>"
     "</body></html>"))


;; ---------- get_web_page ----------

(defn test-get-web-page-from-disk [tmp-path]
  (setv p (/ tmp-path "page.html"))
  (.write-text p "<p>hello</p>")
  (assert (= (get-web-page.get-web-page-from-disk (str p)) "<p>hello</p>")))

(defn test-get-raw-data-from-web [monkeypatch]
  (setv captured [])
  (monkeypatch.setattr get-web-page "urlopen"
    (fn [req] (.append captured req) (FakeResponse b"<html></html>")))
  (assert (= (get-web-page.get-raw-data-from-web "http://example.com") b"<html></html>"))
  (assert (= (.get-header (get captured 0) "User-agent") "HyLangBook/1.0")))


;; ---------- get_page_data ----------

(defn test-get-element-data []
  (setv a (.find (BeautifulSoup sample-html "lxml") "a"))
  (assert (= (get-page-data.get-element-data a)
             {"text" "Home" "name" "a" "class" ["nav"] "href" "/short"})))

(defn test-get-page-html-elements [monkeypatch]
  (monkeypatch.setattr get-page-data "get_raw_data_from_web"
    (fn [uri] (.encode sample-html)))
  (setv elements (get-page-data.get-page-html-elements "http://example.com"))
  (assert (= (. (get elements "title" 0) text) "Sample"))
  (assert (= (len (get elements "a")) 3))
  (assert (= (. (get elements "h1" 0) text) "Main"))
  (assert (= (. (get elements "h2" 0) text) "Sub")))


;; ---------- cached front pages ----------

(defn test-democracy-now-links [tmp-path monkeypatch]
  (.write-text (/ tmp-path "democracynow_home_page.html") sample-html)
  (monkeypatch.chdir tmp-path)
  (setv links (democracynow-front-page.get-democracy-now-links))
  ;; anchors with no text are dropped
  (assert (= (lfor [href _] links href) ["/short" "/story"]))
  (assert (= (get links 0) ["/short" "Home"])))

(defn test-npr-links-and-summary [tmp-path monkeypatch]
  (.write-text (/ tmp-path "npr_home_page.html") sample-html)
  (monkeypatch.chdir tmp-path)
  (assert (= (lfor [href _] (npr-front-page-summary.get-npr-links) href)
             ["/short" "/story"]))
  ;; only link texts longer than 40 characters are kept, stripped
  (assert (= (npr-front-page-summary.create-npr-summary) long-headline)))
