#!/usr/bin/env hy
"Guided tour of Async and Concurrent Hy.
Runs all six modules offline using deterministic mock transports and prints
measured sequential vs concurrent timings."

(import asyncio)
(import httpx)

(import basics [run-sequential
                run-concurrent
                transform-with-async-fn
                run-with-timeout
                run-taskgroup-with-except-star
                AsyncTimer
                collect-even-squares
                count-stream
                sum-stream])
(import bounded_fetch [fetch-all-bounded make-mock-transport])
(import streaming_llm [collect-chat-stream
                       make-fake-ollama-transport
                       try-live-ollama])
(import pipeline [run-crawl-extract-index])
(import cpu_offload [offload-with-to-thread
                     offload-cpu-process-pool
                     python-gil-status])
(import async_scraper [SAMPLE-NEWS-PAGES compare-sequential-vs-concurrent])


(defn :async demo-basics []
  (print "=== 1. Async Basics & Structured Concurrency ===")
  (setv items ["doc-1" "doc-2" "doc-3" "doc-4"]
        [seq-res seq-time] (await (run-sequential items 0.03))
        [conc-res conc-time] (await (run-concurrent items 0.03)))
  (print f"Sequential (4 x 30ms): {(round (* seq-time 1000) 1)} ms")
  (print f"Concurrent TaskGroup : {(round (* conc-time 1000) 1)} ms")
  (print "fn :async squares    :" (await (transform-with-async-fn [2 3 5 7])))
  (print "Timeout (fast)       :" (await (run-with-timeout (asyncio.sleep 0.005 :result "ready") 0.05)))
  (print "Timeout (expired)    :" (await (run-with-timeout (asyncio.sleep 0.08 :result "late") 0.01)))
  (setv eg-report (await (run-taskgroup-with-except-star [1 -2 None -5])))
  (print "except* ValueErrors  :" (get eg-report "value_errors"))
  (print "except* KeyErrors    :" (get eg-report "key_errors"))
  (with [:async timer (AsyncTimer "even-squares")]
    (setv squares (await (collect-even-squares 8 0.002)))
    (setv total (await (sum-stream (count-stream 6 0.002)))))
  (print f"lfor :async squares  : {squares} (sum 0..5 = {total}, {(round (* timer.elapsed 1000) 1)} ms)")
  (print))


(defn :async demo-bounded-fetch []
  (print "=== 2. Bounded HTTP Client with Retries & Rate Limiting ===")
  (setv routes (dfor i (range 1 7) f"/item/{i}" f"payload-{i}")
        mock (make-mock-transport routes
                                  :latency-seconds 0.025
                                  :flaky-counts {"/item/2" 2 "/item/5" 1})
        urls (lfor i (range 1 7) f"https://api.example/item/{i}"))
  (with [:async client (httpx.AsyncClient :transport (get mock "transport"))]
    (setv results (await (fetch-all-bounded client urls
                                            :max-concurrency 3
                                            :max-retries 3
                                            :base-delay 0.01
                                            :rate-per-second 120.0))))
  (setv stats ((get mock "stats")))
  (print "Fetched items        :" (len results))
  (print "Max in-flight (cap 3):" (get stats "max_in_flight"))
  (print "Attempts per path    :" (get stats "call_counts"))
  (print))


(defn :async demo-streaming-llm []
  (print "=== 3. Streaming LLM Output (NDJSON / Ollama) ===")
  (setv tokens ["Hy " "streams " "NDJSON " "tokens " "with " "for :async."]
        transport (make-fake-ollama-transport tokens :chunk-delay 0.008))
  (with [:async client (httpx.AsyncClient :transport transport)]
    (setv stream-res (await (collect-chat-stream client "Explain async Hy in one sentence."))))
  (print "Streamed text        :" (get stream-res "text"))
  (print "Chunks received      :" (get stream-res "chunk_count"))
  (setv ttft-ms (round (* (get stream-res "ttft_seconds") 1000) 1))
  (print f"Time to first token  : {ttft-ms} ms")
  (setv live-check (await (try-live-ollama "Say hello in five words." :timeout 0.4)))
  (if (get live-check "live")
      (print "Live Ollama reply    :" (.strip (get live-check "text")))
      (print "Live Ollama check    :" (get live-check "note")))
  (print))


(defn :async demo-pipeline []
  (print "=== 4. Producer/Consumer Queue Pipeline (crawl -> extract -> index) ===")
  (setv urls (lfor path (.keys SAMPLE-NEWS-PAGES) (+ "https://news.example" path)))
  (defn :async fake-fetch [url]
    (await (asyncio.sleep 0.005))
    (setv path (.replace url "https://news.example" ""))
    (get SAMPLE-NEWS-PAGES path))
  (setv result (await (run-crawl-extract-index urls fake-fetch
                                               :crawl-workers 3
                                               :extract-workers 2
                                               :queue-maxsize 3))
        index (get result "index"))
  (print "Indexed documents    :" (len (get result "documents")))
  (print "Distinct index terms :" (len index))
  (for [term ["datalog" "asyncio" "shacl" "ndjson" "backpressure"]]
    (print f"  term '{term}' -> {(.get index term [])}"))
  (print))


(defn :async demo-cpu-offload []
  (print "=== 5. Threads, Processes & Free-Threading Check ===")
  (setv gil-info (python-gil-status))
  (print "Runtime status       :" gil-info)
  (setv digests (await (offload-with-to-thread ["block-a" "block-b" "block-c"] 15000)))
  (print "to_thread SHA-256[0] :" (cut (get digests 0) 0 16))
  (setv prime-counts (await (offload-cpu-process-pool [#(2 10000) #(10000 20000)] :max-workers 2)))
  (print "ProcessPool primes   :" prime-counts "(total" (sum prime-counts) "primes < 20,000)")
  (print))


(defn :async demo-case-study []
  (print "=== 6. Case Study: Sequential vs Concurrent Web Scraper ===")
  (setv report (await (compare-sequential-vs-concurrent :latency-seconds 0.04
                                                        :max-concurrency 4)))
  (setv page-count (get report "page_count")
        seq-ms (round (* (get report "sequential_seconds") 1000) 1)
        conc-ms (round (* (get report "concurrent_seconds") 1000) 1)
        speedup (get report "speedup")
        max-flight (get report "max_in_flight"))
  (print f"Pages scraped        : {page-count} (simulated 40ms latency + 1 retry)")
  (print f"Sequential time      : {seq-ms} ms")
  (print f"Concurrent (sem=4)   : {conc-ms} ms")
  (print f"Measured speedup     : {speedup}x (max in-flight: {max-flight})")
  (print "Sample extracted summary from /news/lisp-ecosystem:")
  (for [p (get report "pages")]
    (when (.endswith (get p "url") "/news/lisp-ecosystem")
      (print " " (get p "summary")))))


(defn :async main []
  (await (demo-basics))
  (await (demo-bounded-fetch))
  (await (demo-streaming-llm))
  (await (demo-pipeline))
  (await (demo-cpu-offload))
  (await (demo-case-study)))


(when (= __name__ "__main__")
  (asyncio.run (main)))
