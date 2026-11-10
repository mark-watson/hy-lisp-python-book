#!/usr/bin/env hy
"Case study: Async port of the book's webscraping chapter
(get_web_page.hy, get_page_data.hy, and npr_front_page_summary.hy)
comparing sequential vs bounded-concurrent scraping over a deterministic
mock transport with artificial network latency."

(import asyncio)
(import time)
(import bs4 [BeautifulSoup])
(import httpx)
(import bounded_fetch [fetch-with-retry make-mock-transport])


(defn get-element-data [element]
  "Extract text, tag name, class, and href from a BeautifulSoup tag.
  Direct port of get-element-data from source_code_for_examples/webscraping/get_page_data.hy."
  {"text" (.strip (.get-text element))
   "name" element.name
   "class" (.get element "class")
   "href" (.get element "href")})


(defn parse-page-elements [html]
  "Parse HTML into structured title, a, h1, and h2 element dictionaries,
  plus a headline summary (links with text > 40 chars, matching npr_front_page_summary.hy)."
  (setv soup (BeautifulSoup html "html.parser")
        titles (lfor e (.find-all soup "title") (get-element-data e))
        anchors (lfor e (.find-all soup "a") (get-element-data e))
        h1s (lfor e (.find-all soup "h1") (get-element-data e))
        h2s (lfor e (.find-all soup "h2") (get-element-data e))
        long-headlines (lfor a anchors
                             :if (> (len (get a "text")) 40)
                             (get a "text")))
  {"title" (if titles (get (get titles 0) "text") "")
   "a" anchors
   "h1" h1s
   "h2" h2s
   "summary" (.join "\n\n" long-headlines)})


(defn :async scrape-pages-sequential [client urls]
  "Fetch and parse each URL one at a time (sequential baseline).
  Return #(pages-list elapsed-seconds)."
  (setv start (time.perf-counter)
        results [])
  (for [url urls]
    (setv resp (await (fetch-with-retry client url))
          parsed (parse-page-elements (get resp "text")))
    (.append results {"url" url
                      "status" (get resp "status")
                      "attempts" (get resp "attempts")
                      #** parsed}))
  #(results (- (time.perf-counter) start)))


(defn :async scrape-pages-concurrent [client urls [max-concurrency 4]]
  "Fetch and parse all URLs concurrently using TaskGroup and a Semaphore.
  Return #(pages-list elapsed-seconds)."
  (setv start (time.perf-counter)
        sem (asyncio.Semaphore max-concurrency)
        tasks [])

  (defn :async _scrape-one [url]
    (setv resp (await (fetch-with-retry client url :semaphore sem))
          parsed (parse-page-elements (get resp "text")))
    {"url" url
     "status" (get resp "status")
     "attempts" (get resp "attempts")
     #** parsed})

  (with [:async tg (asyncio.TaskGroup)]
    (for [url urls]
      (.append tasks (.create-task tg (_scrape-one url)))))
  (setv results (lfor t tasks (.result t)))
  #(results (- (time.perf-counter) start)))


(setv SAMPLE-NEWS-PAGES
      {"/news/ai-research"
       "<html><head><title>AI Research Digest</title></head><body>
        <h1>AI Research Digest</h1>
        <h2>Neural-Symbolic Systems Gain Traction in Enterprise Graphs</h2>
        <a href='/story/101'>Researchers combine Datalog rules with small local language models for verifiable answers</a>
        <a href='/story/102'>Short link</a>
        </body></html>"

       "/news/lisp-ecosystem"
       "<html><head><title>Lisp in Python-Land</title></head><body>
        <h1>Lisp in Python-Land</h1>
        <h2>Hy 1.3 Brings Modern Async and Pattern Matching</h2>
        <a href='/story/201'>Hy programmers tap directly into Python asyncio, httpx, and structured concurrency</a>
        <a href='/about'>About</a>
        </body></html>"

       "/news/knowledge-graphs"
       "<html><head><title>Knowledge Graph Weekly</title></head><body>
        <h1>Knowledge Graph Weekly</h1>
        <h2>SHACL Validation Prevents Hallucinated Triples</h2>
        <a href='/story/301'>Graph quality pipelines catch schema violations before triples enter production stores</a>
        </body></html>"

       "/news/open-models"
       "<html><head><title>Open Weight Models</title></head><body>
        <h1>Open Weight Models</h1>
        <h2>Local Inference with Ollama and Quantized Weights</h2>
        <a href='/story/401'>Streaming NDJSON responses keep interactive terminal tools responsive under load</a>
        </body></html>"

       "/news/data-engineering"
       "<html><head><title>Data Systems</title></head><body>
        <h1>Data Systems</h1>
        <h2>Bounded Queues Tame Backpressure in Web Crawlers</h2>
        <a href='/story/501'>Producer-consumer pipelines decouple network latency from HTML parsing and indexing</a>
        </body></html>"

       "/news/python-runtime"
       "<html><head><title>Python Runtime Notes</title></head><body>
        <h1>Python Runtime Notes</h1>
        <h2>Free-Threaded Python and Async Event Loops</h2>
        <a href='/story/601'>Understanding when to reach for asyncio coroutines versus thread or process pools</a>
        </body></html>"

       "/news/semantic-web"
       "<html><head><title>Semantic Web Today</title></head><body>
        <h1>Semantic Web Today</h1>
        <h2>SPARQL Endpoints Meet Vector Search</h2>
        <a href='/story/701'>Hybrid GraphRAG architectures link dense embeddings back to explicit RDF provenance</a>
        </body></html>"

       "/news/testing-craft"
       "<html><head><title>Testing Craft</title></head><body>
        <h1>Testing Craft</h1>
        <h2>Deterministic Network Tests with Mock Transports</h2>
        <a href='/story/801'>Replacing live HTTP calls with in-memory transports eliminates flaky CI builds</a>
        </body></html>"})


(defn :async compare-sequential-vs-concurrent [[latency-seconds 0.04]
                                               [max-concurrency 4]]
  "Run sequential vs bounded-concurrent scraping against SAMPLE-NEWS-PAGES
  with simulated per-request latency and one flaky endpoint (/news/open-models)."
  (setv urls (lfor path (.keys SAMPLE-NEWS-PAGES) (+ "https://news.example" path)))

  (setv seq-mock (make-mock-transport SAMPLE-NEWS-PAGES
                                      :latency-seconds latency-seconds
                                      :flaky-counts {"/news/open-models" 1}))
  (with [:async client (httpx.AsyncClient :transport (get seq-mock "transport"))]
    (setv [seq-pages seq-elapsed] (await (scrape-pages-sequential client urls))))

  (setv conc-mock (make-mock-transport SAMPLE-NEWS-PAGES
                                       :latency-seconds latency-seconds
                                       :flaky-counts {"/news/open-models" 1}))
  (with [:async client (httpx.AsyncClient :transport (get conc-mock "transport"))]
    (setv [conc-pages conc-elapsed]
          (await (scrape-pages-concurrent client urls :max-concurrency max-concurrency))))

  (setv conc-stats ((get conc-mock "stats")))
  {"page_count" (len urls)
   "latency_seconds" latency-seconds
   "max_concurrency" max-concurrency
   "sequential_seconds" seq-elapsed
   "concurrent_seconds" conc-elapsed
   "speedup" (round (/ seq-elapsed (max conc-elapsed 1e-6)) 2)
   "max_in_flight" (get conc-stats "max_in_flight")
   "sequential_titles" (lfor p seq-pages (get p "title"))
   "concurrent_titles" (lfor p conc-pages (get p "title"))
   "pages" conc-pages})
