#!/usr/bin/env hy
"Bounded producer/consumer pipeline with asyncio.Queue:
crawl -> extract -> index."

(import asyncio)
(import re)
(import bs4 [BeautifulSoup])


(setv WORD-RE (re.compile r"[a-zA-Z]{3,}"))


(defn extract-document [url html]
  "Parse HTML with BeautifulSoup and return title, links, and lowercase words."
  (setv soup (BeautifulSoup html "html.parser")
        title-tag (.find soup "title")
        title (if title-tag (.strip (.get-text title-tag)) "")
        links (lfor a (.find-all soup "a")
                    :if (.get a "href")
                    (.get a "href"))
        body-text (.get-text soup " " :strip True)
        words (lfor m (.findall WORD-RE body-text) (.lower m)))
  {"url" url
   "title" title
   "links" links
   "words" words})


(defn :async run-crawl-extract-index [urls fetch-fn
                                      [crawl-workers 3]
                                      [extract-workers 2]
                                      [queue-maxsize 4]]
  "Run a three-stage asyncio.Queue pipeline (crawl -> extract -> index)
  with bounded queues for backpressure. Return the inverted index and docs."
  (setv url-queue (asyncio.Queue)
        page-queue (asyncio.Queue :maxsize queue-maxsize)
        doc-queue (asyncio.Queue :maxsize queue-maxsize)
        documents {}
        inverted-index {})

  (for [u urls]
    (.put-nowait url-queue u))
  (for [_ (range crawl-workers)]
    (.put-nowait url-queue None))

  (defn :async crawl-worker []
    (while True
      (setv url (await (.get url-queue)))
      (try
        (when (is url None)
          (break))
        (setv html (await (fetch-fn url)))
        (await (.put page-queue #(url html)))
        (finally
          (.task-done url-queue)))))

  (defn :async extract-worker []
    (while True
      (setv item (await (.get page-queue)))
      (try
        (when (is item None)
          (break))
        (setv [url html] item
              doc (extract-document url html))
        (await (.put doc-queue doc))
        (finally
          (.task-done page-queue)))))

  (defn :async index-worker []
    (while True
      (setv doc (await (.get doc-queue)))
      (try
        (when (is doc None)
          (break))
        (setv url (get doc "url"))
        (setv (get documents url) doc)
        (for [word (set (get doc "words"))]
          (when (not (in word inverted-index))
            (setv (get inverted-index word) (set)))
          (.add (get inverted-index word) url))
        (finally
          (.task-done doc-queue)))))

  ;; Stage coordination: when all crawl workers finish, send sentinel None
  ;; tokens to extract workers; when extract workers finish, stop index-worker.
  (defn :async coordinator []
    (with [:async crawl-tg (asyncio.TaskGroup)]
      (for [_ (range crawl-workers)]
        (.create-task crawl-tg (crawl-worker))))
    (for [_ (range extract-workers)]
      (await (.put page-queue None))))

  (defn :async extract-stage []
    (with [:async extract-tg (asyncio.TaskGroup)]
      (for [_ (range extract-workers)]
        (.create-task extract-tg (extract-worker))))
    (await (.put doc-queue None)))

  (with [:async tg (asyncio.TaskGroup)]
    (.create-task tg (coordinator))
    (.create-task tg (extract-stage))
    (.create-task tg (index-worker)))

  (setv sorted-index
        (dfor [word url-set] (.items inverted-index)
              word (sorted url-set)))
  {"documents" documents
   "index" sorted-index})
