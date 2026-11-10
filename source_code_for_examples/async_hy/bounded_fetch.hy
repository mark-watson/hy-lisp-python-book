#!/usr/bin/env hy
"Bounded HTTP concurrency with httpx.AsyncClient, semaphores, exponential
backoff retries, rate limiting, and deterministic MockTransport fakes."

(import asyncio)
(import time)
(import httpx)


(setv RETRIABLE-STATUS-CODES #{429 500 502 503 504})


(defclass AsyncRateLimiter []
  "Enforce a minimum interval between request starts across concurrent tasks."

  (defn __init__ [self rate-per-second]
    (setv self.min-interval (/ 1.0 rate-per-second)
          self.lock (asyncio.Lock)
          self.next-allowed 0.0))

  (defn :async acquire [self]
    (with [:async self.lock]
      (setv now (time.monotonic))
      (when (< now self.next-allowed)
        (await (asyncio.sleep (- self.next-allowed now)))
        (setv now (time.monotonic)))
      (setv self.next-allowed (+ now self.min-interval)))))


(defn :async fetch-with-retry [client url
                               [max-retries 3]
                               [base-delay 0.02]
                               [semaphore None]
                               [rate-limiter None]]
  "Fetch url with optional semaphore, rate limiter, and exponential backoff."
  (defn :async _do-attempt []
    (when (is-not rate-limiter None)
      (await (.acquire rate-limiter)))
    (await (.get client url)))

  (setv attempt 0)
  (while True
    (+= attempt 1)
    (try
      (setv response
            (if (is-not semaphore None)
                (with [:async semaphore]
                  (await (_do-attempt)))
                (await (_do-attempt))))
      (if (and (in response.status-code RETRIABLE-STATUS-CODES)
               (<= attempt max-retries))
          (await (asyncio.sleep (* base-delay (** 2 (- attempt 1)))))
          (do
            (.raise-for-status response)
            (return {"url" url
                     "status" response.status-code
                     "text" response.text
                     "attempts" attempt})))
      (except [exc httpx.RequestError]
        (when (> attempt max-retries)
          (raise exc))
        (await (asyncio.sleep (* base-delay (** 2 (- attempt 1)))))))))


(defn :async fetch-all-bounded [client urls
                                [max-concurrency 4]
                                [max-retries 3]
                                [base-delay 0.02]
                                [rate-per-second None]]
  "Fetch all urls concurrently under a semaphore and optional rate limiter."
  (setv sem (asyncio.Semaphore max-concurrency)
        limiter (if (is-not rate-per-second None)
                    (AsyncRateLimiter rate-per-second)
                    None)
        tasks [])
  (with [:async tg (asyncio.TaskGroup)]
    (for [url urls]
      (.append tasks
               (.create-task tg
                 (fetch-with-retry client url
                                   :max-retries max-retries
                                   :base-delay base-delay
                                   :semaphore sem
                                   :rate-limiter limiter)))))
  (lfor t tasks (.result t)))


(defn make-mock-transport [routes [latency-seconds 0.02] [flaky-counts None]]
  "Build an httpx.MockTransport with artificial latency and optional transient 503s.
  routes maps a URL path (like '/page/1') to a body string or #(status body).
  flaky-counts maps a URL path to the number of initial 503 responses before 200."
  (setv remaining-failures (dict (or flaky-counts {}))
        call-counts {}
        in-flight 0
        max-in-flight 0)

  (defn :async handler [request]
    (nonlocal in-flight max-in-flight)
    (setv path request.url.path)
    (setv (get call-counts path) (+ (.get call-counts path 0) 1))
    (+= in-flight 1)
    (when (> in-flight max-in-flight)
      (setv max-in-flight in-flight))
    (try
      (when (> latency-seconds 0)
        (await (asyncio.sleep latency-seconds)))
      (setv fails-left (.get remaining-failures path 0))
      (when (> fails-left 0)
        (setv (get remaining-failures path) (- fails-left 1))
        (return (httpx.Response 503 :text "Service Temporarily Unavailable")))
      (when (not (in path routes))
        (return (httpx.Response 404 :text "Not Found")))
      (setv entry (get routes path))
      (if (isinstance entry tuple)
          (httpx.Response (get entry 0) :text (get entry 1))
          (httpx.Response 200 :text entry))
      (finally
        (-= in-flight 1))))

  (setv transport (httpx.MockTransport handler))
  {"transport" transport
   "call_counts" call-counts
   "stats" (fn [] {"max_in_flight" max-in-flight
                   "call_counts" (dict call-counts)})})
