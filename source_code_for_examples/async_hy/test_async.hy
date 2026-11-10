"Deterministic pytest-asyncio test suite for async_hy.
All HTTP and streaming tests run in-memory via httpx.MockTransport."

(import asyncio)
(import httpx)
(import pytest)

(import basics [simulated-io
                run-sequential
                run-concurrent
                transform-with-async-fn
                run-with-timeout
                run-taskgroup-with-except-star
                AsyncTimer
                count-stream
                collect-even-squares
                sum-stream])
(import bounded_fetch [AsyncRateLimiter
                       fetch-with-retry
                       fetch-all-bounded
                       make-mock-transport])
(import streaming_llm [parse-ndjson-line
                       parse-sse-line
                       stream-ollama-chat
                       collect-chat-stream
                       make-fake-ollama-transport
                       try-live-ollama])
(import pipeline [extract-document run-crawl-extract-index])
(import cpu_offload [blocking-digest-work
                     count-primes-in-range
                     offload-with-to-thread
                     offload-with-thread-pool
                     offload-cpu-process-pool
                     python-gil-status])
(import async_scraper [get-element-data
                       parse-page-elements
                       scrape-pages-sequential
                       scrape-pages-concurrent
                       compare-sequential-vs-concurrent
                       SAMPLE-NEWS-PAGES])


(defn :async test-sequential-vs-concurrent-basics []
  (setv items ["a" "b" "c" "d"]
        [seq-res seq-elapsed] (await (run-sequential items 0.02))
        [conc-res conc-elapsed] (await (run-concurrent items 0.02)))
  (assert (= (lfor r seq-res (get r "label")) items))
  (assert (= (lfor r conc-res (get r "label")) items))
  (assert (< conc-elapsed (* seq-elapsed 0.65))))


(defn :async test-async-fn-and-timeout []
  (setv squares (await (transform-with-async-fn [1 2 4 6])))
  (assert (= squares [1 4 16 36]))
  (setv ok (await (run-with-timeout (simulated-io "fast" 0.005) 0.1)))
  (assert (= (get (get ok "ok") "label") "fast"))
  (setv timed-out (await (run-with-timeout (simulated-io "slow" 0.1) 0.01)))
  (assert (= (get timed-out "error") "timeout")))


(defn :async test-taskgroup-except-star []
  (setv ok-report (await (run-taskgroup-with-except-star [2 3 4])))
  (assert (= (get ok-report "results") [20 30 40]))
  (assert (= (get ok-report "value_errors") []))
  (assert (= (get ok-report "key_errors") []))

  (setv err-report (await (run-taskgroup-with-except-star [1 -3 None -7])))
  (assert (= (get err-report "results") []))
  (assert (= (len (get err-report "value_errors")) 2))
  (assert (= (len (get err-report "key_errors")) 1)))


(defn :async test-async-timer-and-generators []
  (with [:async timer (AsyncTimer "gen-test")]
    (setv evens (await (collect-even-squares 6 0.002)))
    (setv total (await (sum-stream (count-stream 5 0.002)))))
  (assert (= evens [0 4 16]))
  (assert (= total 10))
  (assert (> timer.elapsed 0.01)))


(defn :async test-bounded-fetch-semaphore-and-retries []
  (setv routes (dfor i (range 1 9) f"/p/{i}" f"body-{i}")
        mock (make-mock-transport routes
                                  :latency-seconds 0.015
                                  :flaky-counts {"/p/2" 2 "/p/6" 1})
        urls (lfor i (range 1 9) f"https://test.local/p/{i}"))
  (with [:async client (httpx.AsyncClient :transport (get mock "transport"))]
    (setv res (await (fetch-all-bounded client urls
                                        :max-concurrency 3
                                        :max-retries 3
                                        :base-delay 0.005))))
  (assert (= (len res) 8))
  (setv stats ((get mock "stats")))
  (assert (<= (get stats "max_in_flight") 3))
  (assert (= (get (get stats "call_counts") "/p/2") 3))
  (assert (= (get (get stats "call_counts") "/p/6") 2)))


(defn :async test-rate-limiter []
  (setv limiter (AsyncRateLimiter 100.0)
        start (asyncio.get-running-loop))
  (setv t0 (.time start))
  (for [_ (range 4)]
    (await (.acquire limiter)))
  (setv elapsed (- (.time start) t0))
  ;; 4 acquisitions at 100 req/s require at least 3 intervals of 10ms = ~30ms
  (assert (>= elapsed 0.025)))


(defn test-parse-ndjson-and-sse-lines []
  (assert (= (parse-ndjson-line "") #(None False)))
  (assert (= (parse-ndjson-line "{\"message\":{\"content\":\"Hi\"},\"done\":false}")
             #("Hi" False)))
  (assert (= (parse-ndjson-line "{\"message\":{\"content\":\"\"},\"done\":true}")
             #("" True)))
  (assert (= (parse-sse-line ": keep-alive") #(None False)))
  (assert (= (parse-sse-line "data: {\"choices\":[{\"delta\":{\"content\":\"Yo\"}}]}")
             #("Yo" False)))
  (assert (= (parse-sse-line "data: [DONE]") #("" True))))


(defn :async test-streaming-ollama-mock []
  (setv tokens ["Lisp " "syntax " "meets " "Python " "asyncio."]
        transport (make-fake-ollama-transport tokens :chunk-delay 0.002))
  (with [:async client (httpx.AsyncClient :transport transport)]
    (setv result (await (collect-chat-stream client "test prompt"))))
  (assert (= (get result "text") "Lisp syntax meets Python asyncio."))
  (assert (= (get result "chunk_count") 5))
  (assert (> (get result "total_seconds") 0.0))
  (setv fallback (await (try-live-ollama "hi" :url "http://127.0.0.1:9/api/chat" :timeout 0.05)))
  (assert (= (get fallback "live") False))
  (assert (in "Ollama not reachable" (get fallback "note"))))


(defn :async test-pipeline-crawl-extract-index []
  (setv pages {"https://site.test/a"
               "<html><head><title>Alpha Page</title></head><body>
                <a href='/b'>Beta link</a><p>Hy macros and asyncio queues</p></body></html>"
               "https://site.test/b"
               "<html><head><title>Beta Page</title></head><body>
                <a href='/a'>Alpha link</a><p>Asyncio tasks and bounded queues</p></body></html>"})
  (defn :async fake-fetch [url]
    (await (asyncio.sleep 0.002))
    (get pages url))
  (setv out (await (run-crawl-extract-index (list (.keys pages)) fake-fetch
                                            :crawl-workers 2
                                            :extract-workers 2
                                            :queue-maxsize 2))
        idx (get out "index"))
  (assert (= (len (get out "documents")) 2))
  (assert (= (get idx "asyncio") ["https://site.test/a" "https://site.test/b"]))
  (assert (= (get idx "macros") ["https://site.test/a"])))


(defn :async test-cpu-offload-threads-and-processes []
  (setv status (python-gil-status))
  (assert (in "gil_enabled" status))
  (setv expected (blocking-digest-work "hy-test" 2000)
        via-to-thread (await (offload-with-to-thread ["hy-test"] 2000))
        via-pool (await (offload-with-thread-pool ["hy-test"] :max-workers 2 :iterations 2000)))
  (assert (= (get via-to-thread 0) expected))
  (assert (= (get via-pool 0) expected))

  (setv counts (await (offload-cpu-process-pool [#(2 1000) #(1000 2000)] :max-workers 2)))
  (assert (= counts [168 135])))


(defn :async test-async-scraper-case-study []
  (setv report (await (compare-sequential-vs-concurrent :latency-seconds 0.025
                                                        :max-concurrency 4)))
  (assert (= (get report "page_count") 8))
  (assert (= (get report "sequential_titles") (get report "concurrent_titles")))
  (assert (<= (get report "max_in_flight") 4))
  (assert (> (get report "speedup") 1.8)))
