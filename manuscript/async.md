# Async and Concurrent Hy

In earlier chapters we fetched web pages one at a time with `urllib.request` and waited for complete replies from language models before printing a single word. That sequential style is easy to read, but it leaves the CPU idle while waiting for network sockets. In this chapter I show you how to write concurrent Hy programs using Python's `asyncio` library, `httpx`, queues, and worker pools.

The code for this chapter is in the directory **source_code_for_examples/async_hy**.

## What You Will Build

We build six small modules that progress from core `asyncio` syntax to a complete concurrent web scraper and indexing pipeline:

1. **basics.hy**: Coroutines (`defn :async` and `fn :async`), structured concurrency with `asyncio.TaskGroup`, timeouts, `except*` exception group handling, async context managers (`with :async`), async generators, and async comprehensions (`lfor :async`).
2. **bounded_fetch.hy**: An HTTP client built on `httpx.AsyncClient` that bounds in-flight requests with `asyncio.Semaphore`, paces requests with a rate limiter, retries transient `503`/`429` errors with exponential backoff, and tests cleanly offline with `httpx.MockTransport`.
3. **streaming_llm.hy**: An async generator that streams newline-delimited JSON (NDJSON) chunks from Ollama's `/api/chat` endpoint and Server-Sent Events (SSE) lines using `httpx` streaming and `.aiter-lines`.
4. **pipeline.hy**: A three-stage producer/consumer pipeline (`crawl -> extract -> index`) connected by bounded `asyncio.Queue` instances that apply backpressure automatically.
5. **cpu_offload.hy**: Helpers that offload blocking calls to threads via `asyncio.to_thread` and pure-Python CPU work to separate processes via `ProcessPoolExecutor`, including the setup needed so spawned worker processes can import `.hy` modules.
6. **async_scraper.hy**: A concurrent port of the book's `webscraping` example that compares sequential and bounded-concurrent execution times against a deterministic mock news server.

```text
+-----------------------------------------------------------------------+
|                       asyncio Event Loop (main)                       |
+-----------------------------------------------------------------------+
       |                         |                         |
       v                         v                         v
+--------------+         +---------------+         +--------------------+
| TaskGroup    |         | Streaming LLM |         | Executor Bridge    |
| + Semaphore  |         | .stream POST  |         | asyncio.to_thread  |
| + Retries    |         | .aiter_lines  |         | ProcessPoolExecutor|
+--------------+         +---------------+         +--------------------+
       |                         |                         |
       v                         v                         v
+-----------------------------------------------------------------------+
|            Bounded asyncio.Queue Pipeline (Backpressure)              |
|   [url-queue] ---> crawl-workers ---> [page-queue (maxsize=4)]        |
|               ---> extract-workers -> [doc-queue  (maxsize=4)]        |
|               ---> index-worker   ---> Inverted Keyword Index         |
+-----------------------------------------------------------------------+
```

## Why It Matters

Modern AI and data-collection programs spend most of their wall-clock time waiting on external systems:

- Scraping ten news pages sequentially with a 100 ms response time takes a full second, plus any retry delays when a server returns HTTP 503.
- Calling three external tools for an agent one after another multiplies tool latency.
- Waiting for an LLM to finish a 500-token answer before displaying anything makes an interactive command-line tool feel broken.

At the same time, launching 1,000 unbounded concurrent requests will exhaust file descriptors or trigger rate limits on the target server. Production async code needs structured task lifetimes, explicit concurrency limits, retries with backoff, bounded queues, and a clear split between I/O-bound tasks and CPU-bound tasks.

## The Concurrency Map

Before writing code, choose the concurrency model that matches your bottleneck:

| Workload Type | Bottleneck | Right Tool in Hy | Why |
| --- | --- | --- | --- |
| Many HTTP requests, database queries, LLM streams | Network I/O wait | `asyncio` (`defn :async`, `TaskGroup`, `httpx.AsyncClient`) | Single thread multiplexes thousands of sockets with minimal memory and no lock contention |
| Legacy synchronous I/O library (`urllib`, `sqlite3`, local file reads) | Blocking system call | `asyncio.to-thread` or `ThreadPoolExecutor` | Keeps the `asyncio` event loop responsive by running the blocking call on a worker thread |
| C extensions that release the GIL (`numpy`, `hashlib`, compression) | Native CPU compute | `ThreadPoolExecutor` / `asyncio.to-thread` | Threads run in parallel once the C function releases the GIL |
| Pure-Python / pure-Hy CPU loops (parsing, prime search, graph search) | CPU bytecode execution under standard GIL | `ProcessPoolExecutor` via `loop.run-in-executor` | Separate OS processes each have their own interpreter and bypass the GIL |
| Pure-Python CPU work on a Python 3.13/3.14+ free-threaded build (`python3.14t`) | Multi-core CPU without process IPC | `ThreadPoolExecutor` (verify with `sys._is_gil_enabled`) | When the GIL is disabled at runtime, threads execute Python bytecode in parallel |

## The Hy Angle

Hy maps every Python async construct directly onto existing Lisp forms using the `:async` keyword modifier instead of inventing a separate set of macro names:

| Construct | Hy 1.3.1 Form | Compiled Python |
| --- | --- | --- |
| Named coroutine | `(defn :async fetch [url] ...)` | `async def fetch(url): ...` |
| Anonymous coroutine | `(fn :async [x] ...)` | `async def _hy_anon(x): ...` |
| Await expression | `(await (fetch url))` | `await fetch(url)` |
| Async context manager | `(with [:async c (Client)] ...)` | `async with Client() as c: ...` |
| Async loop | `(for [:async line lines] ...)` | `async for line in lines: ...` |
| Async comprehension | `(lfor :async x aiter (* x x))` | `[x * x async for x in aiter]` |
| Exception group handler | `(except* [eg ValueError] ...)` | `except* ValueError as eg: ...` |

Because `:async` is a modifier on `defn`, `fn`, `with`, `for`, `lfor`, `gfor`, `sfor`, and `dfor`, the structure of your code stays identical when you move from synchronous Hy to asynchronous Hy.

## Python Equivalent (`hy2py`)

You can verify how Hy compiles async forms at any time by running `uv run hy2py`. Here is a comparison between our Hy code in **basics.hy** and the Python AST code that `hy2py` generates:

```hy
;; Hy (from basics.hy)
(defn :async run-concurrent [items delay-seconds]
  (setv start (time.perf-counter))
  (setv tasks [])
  (with [:async tg (asyncio.TaskGroup)]
    (for [item items]
      (.append tasks (.create-task tg (simulated-io item delay-seconds)))))
  (setv results (lfor t tasks (.result t)))
  #(results (- (time.perf-counter) start)))

(defn :async collect-even-squares [n [delay-seconds 0.002]]
  (lfor :async x (count-stream n delay-seconds)
        :if (= (% x 2) 0)
        (* x x)))
```

Running `uv run hy2py basics.hy` produces the exact Python equivalent:

```python
async def run_concurrent(items, delay_seconds):
    start = time.perf_counter()
    tasks = []
    _hy_anon_1 = None
    async with asyncio.TaskGroup() as tg:
        for item in items:
            tasks.append(tg.create_task(simulated_io(item, delay_seconds)))
        _hy_anon_1 = None
    results = [t.result() for t in tasks]
    return (results, time.perf_counter() - start)

async def collect_even_squares(n, delay_seconds=0.002):
    return [x * x async for x in count_stream(n, delay_seconds) if x % 2 == 0]
```

## Run It

The project directory **source_code_for_examples/async_hy** is layout-complete with `pyproject.toml`, `conftest.py`, six modules, `demo.hy`, and `test_async.hy`:

```text
async_hy/
├── basics.hy          # defn :async, fn :async, TaskGroup, timeout, except*, async generators
├── bounded_fetch.hy   # httpx.AsyncClient, Semaphore, exponential backoff, rate limiter
├── streaming_llm.hy   # Ollama NDJSON and SSE streaming via httpx .stream / .aiter-lines
├── pipeline.hy        # Bounded asyncio.Queue pipeline: crawl -> extract -> index
├── cpu_offload.hy     # asyncio.to_thread, ThreadPoolExecutor, ProcessPoolExecutor, GIL check
├── async_scraper.hy   # Case study: sequential vs concurrent BeautifulSoup scraper
├── demo.hy            # Guided tour that runs all six modules and prints timings
├── test_async.hy      # Deterministic pytest-asyncio test suite (11 tests, offline)
├── conftest.py        # pytest hook to collect test_*.hy files
└── pyproject.toml     # Dependencies: hy, httpx, beautifulsoup4, pytest, pytest-asyncio
```

Install the environment, run the test suite, and run the guided tour:

```bash
cd source_code_for_examples/async_hy
uv sync
uv run pytest -q
uv run hy demo.hy
```

Here is the real output captured from `uv run hy demo.hy`:

```text
=== 1. Async Basics & Structured Concurrency ===
Sequential (4 x 30ms): 124.3 ms
Concurrent TaskGroup : 31.2 ms
fn :async squares    : [4, 9, 25, 49]
Timeout (fast)       : {'ok': 'ready'}
Timeout (expired)    : {'error': 'timeout'}
except* ValueErrors  : ['negative item: -2', 'negative item: -5']
except* KeyErrors    : ["'missing item'"]
lfor :async squares  : [0, 4, 16, 36] (sum 0..5 = 15, 32.3 ms)

=== 2. Bounded HTTP Client with Retries & Rate Limiting ===
Fetched items        : 6
Max in-flight (cap 3): 3
Attempts per path    : {'/item/1': 1, '/item/2': 3, '/item/3': 1, '/item/4': 1, '/item/5': 2, '/item/6': 1}

=== 3. Streaming LLM Output (NDJSON / Ollama) ===
Streamed text        : Hy streams NDJSON tokens with for :async.
Chunks received      : 6
Time to first token  : 9.4 ms
Live Ollama check    : Ollama not reachable (ReadTimeout); used MockTransport stream.

=== 4. Producer/Consumer Queue Pipeline (crawl -> extract -> index) ===
Indexed documents    : 8
Distinct index terms : 134
  term 'datalog' -> ['https://news.example/news/ai-research']
  term 'asyncio' -> ['https://news.example/news/lisp-ecosystem', 'https://news.example/news/python-runtime']
  term 'shacl' -> ['https://news.example/news/knowledge-graphs']
  term 'ndjson' -> ['https://news.example/news/open-models']
  term 'backpressure' -> ['https://news.example/news/data-engineering']

=== 5. Threads, Processes & Free-Threading Check ===
Runtime status       : {'python_version': '3.14.7', 'gil_enabled': True, 'free_threaded': False}
to_thread SHA-256[0] : 47d0f73c9d255333
ProcessPool primes   : [1229, 1033] (total 2262 primes < 20,000)

=== 6. Case Study: Sequential vs Concurrent Web Scraper ===
Pages scraped        : 8 (simulated 40ms latency + 1 retry)
Sequential time      : 396.1 ms
Concurrent (sem=4)   : 128.8 ms
Measured speedup     : 3.08x (max in-flight: 4)
Sample extracted summary from /news/lisp-ecosystem:
  Hy programmers tap directly into Python asyncio, httpx, and structured concurrency
```

## How It Works

Let's walk through each of the six modules in detail.

### 1. Core Async Forms and Structured Concurrency: `basics.hy`

A function defined with `(defn :async ...)` returns a coroutine object when called. To execute it from synchronous code at the top level of a script, pass the coroutine to `(asyncio.run ...)`. Inside a coroutine, `(await expr)` suspends the current coroutine until `expr` completes, allowing the event loop to run other ready tasks.

Here are the core functions in **basics.hy**:

```hy
(defn :async simulated-io [label delay-seconds]
  "Simulate a non-blocking I/O operation that takes delay-seconds."
  (await (asyncio.sleep delay-seconds))
  {"label" label "delay" delay-seconds})


(defn :async run-sequential [items delay-seconds]
  "Run simulated-io one item at a time and return #(results elapsed-seconds)."
  (setv start (time.perf-counter))
  (setv results [])
  (for [item items]
    (.append results (await (simulated-io item delay-seconds))))
  #(results (- (time.perf-counter) start)))


(defn :async run-concurrent [items delay-seconds]
  "Run simulated-io concurrently with asyncio.TaskGroup and return #(results elapsed-seconds)."
  (setv start (time.perf-counter))
  (setv tasks [])
  (with [:async tg (asyncio.TaskGroup)]
    (for [item items]
      (.append tasks (.create-task tg (simulated-io item delay-seconds)))))
  (setv results (lfor t tasks (.result t)))
  #(results (- (time.perf-counter) start)))


(defn :async run-with-timeout [coro timeout-seconds]
  "Run coro inside asyncio.timeout; return {:ok result} or {:error 'timeout'}."
  (try
    (with [:async (asyncio.timeout timeout-seconds)]
      {"ok" (await coro)})
    (except [TimeoutError]
      {"error" "timeout"})))


(defn :async run-taskgroup-with-except-star [items]
  "Run risky-worker over items in a TaskGroup and classify failures with except*."
  (setv value-errors []
        key-errors []
        tasks [])
  (try
    (with [:async tg (asyncio.TaskGroup)]
      (for [item items]
        (.append tasks (.create-task tg (risky-worker item)))))
    (except* [eg ValueError]
      (for [exc eg.exceptions]
        (.append value-errors (str exc))))
    (except* [eg KeyError]
      (for [exc eg.exceptions]
        (.append key-errors (str exc)))))
  {"results" (if (or value-errors key-errors)
                 []
                 (lfor t tasks (.result t)))
   "value_errors" value-errors
   "key_errors" key-errors})


(defclass AsyncTimer []
  "Async context manager that records elapsed wall-clock time in seconds."

  (defn __init__ [self label]
    (setv self.label label
          self.start-time 0.0
          self.elapsed 0.0))

  (defn :async __aenter__ [self]
    (setv self.start-time (time.perf-counter))
    self)

  (defn :async __aexit__ [self exc-type exc-val exc-tb]
    (await (asyncio.sleep 0))
    (setv self.elapsed (- (time.perf-counter) self.start-time))
    False))


(defn :async count-stream [n [delay-seconds 0.005]]
  "Async generator yielding integers 0 .. n-1 after a short delay."
  (for [i (range n)]
    (await (asyncio.sleep delay-seconds))
    (yield i)))


(defn :async collect-even-squares [n [delay-seconds 0.002]]
  "Use an async list comprehension (lfor :async ...) over an async generator."
  (lfor :async x (count-stream n delay-seconds)
        :if (= (% x 2) 0)
        (* x x)))
```

Four details in `basics.hy` are worth highlighting:

1. **Structured concurrency with `TaskGroup`**: In `run-concurrent`, `(with [:async tg (asyncio.TaskGroup)] ...)` guarantees that every task spawned with `(.create-task tg ...)` has finished (or been cancelled and awaited) before execution leaves the `with` block. Unlike raw `asyncio.create_task`, `TaskGroup` never leaks orphan background tasks.
2. **Cancellation and `asyncio.timeout`**: In `run-with-timeout`, `(with [:async (asyncio.timeout timeout-seconds)] ...)` cancels the inner task if the deadline expires and raises `TimeoutError` at the `with` boundary.
3. **Exception groups and `except*`**: Because multiple tasks inside a `TaskGroup` can fail during the same turn of the event loop, `TaskGroup` wraps uncaught task exceptions in an `ExceptionGroup`. Hy supports Python's `except*` syntax directly: `(except* [eg ValueError] ...)` catches the subgroup of `ValueError` exceptions while allowing a second `(except* [eg KeyError] ...)` clause in the same `try` form to handle `KeyError` failures from sibling tasks.
4. **Async context managers, generators, and comprehensions**: Defining `(defn :async __aenter__ [self] ...)` and `(defn :async __aexit__ [self exc-type exc-val exc-tb] ...)` makes `AsyncTimer` work with `(with [:async timer (AsyncTimer ...)] ...)`. Putting `(yield i)` inside a `(defn :async ...)` function turns `count-stream` into an async generator, which we consume with `(lfor :async x ...)` or `(for [:async x ...] ...)`.

### 2. Bounded HTTP Concurrency, Retries, and Rate Limiting: `bounded_fetch.hy`

Spawning a task per URL in a `TaskGroup` without a concurrency limit will fire all requests simultaneously. In **bounded_fetch.hy**, we combine `httpx.AsyncClient` with `asyncio.Semaphore`, an interval rate limiter, and exponential backoff:

```hy
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
```

Notice where the semaphore is acquired in `fetch-with-retry`:

- `(with [:async semaphore] (await (_do-attempt)))` holds a semaphore slot only while the HTTP request is in flight, and releases the slot before `(await (asyncio.sleep ...))` during a retry backoff delay. If a task slept while holding the semaphore, backing-off tasks would block healthy requests from using the connection pool.
- `AsyncRateLimiter` uses an `asyncio.Lock` and `time.monotonic` to space request starts by `1.0 / rate-per-second` seconds.

### 3. Streaming LLM Output (NDJSON and SSE): `streaming_llm.hy`

Local model servers such as Ollama stream responses as newline-delimited JSON (`application/x-ndjson`), where each line is a self-contained JSON object with a `"message"` chunk and a boolean `"done"` flag. OpenAI-compatible APIs use Server-Sent Events (`text/event-stream`), where each payload line starts with `data: ` and the stream ends with `data: [DONE]`.

In **streaming_llm.hy**, we parse both formats and expose an async generator `stream-ollama-chat` using `(.stream client "POST" ...)` and `(.aiter-lines response)`:

```hy
(defn parse-ndjson-line [line]
  "Parse one NDJSON line from an Ollama /api/chat stream.
  Return #(token is-done) or #(None False) for blank lines."
  (setv stripped (.strip line))
  (when (not stripped)
    (return #(None False)))
  (setv payload (json.loads stripped)
        msg (.get payload "message" {})
        token (.get msg "content" "")
        done (bool (.get payload "done" False)))
  #(token done))


(defn parse-sse-line [line]
  "Parse one Server-Sent Events line ('data: ...').
  Return #(token is-done) or #(None False) for comments/non-data lines."
  (setv stripped (.strip line))
  (when (or (not stripped) (not (.startswith stripped "data:")))
    (return #(None False)))
  (setv data-str (.strip (cut stripped 5 None)))
  (when (= data-str "[DONE]")
    (return #("" True)))
  (setv payload (json.loads data-str)
        choices (.get payload "choices" [])
        delta (if choices (.get (get choices 0) "delta" {}) {})
        token (.get delta "content" ""))
  #(token False))


(defn :async stream-ollama-chat [client prompt
                                 [model "qwen3.5:4b"]
                                 [url "http://127.0.0.1:11434/api/chat"]]
  "Async generator yielding text chunks from an Ollama /api/chat NDJSON stream."
  (setv body {"model" model
              "messages" [{"role" "user" "content" prompt}]
              "stream" True})
  (with [:async response (.stream client "POST" url :json body)]
    (.raise-for-status response)
    (for [:async line (.aiter-lines response)]
      (setv [token done] (parse-ndjson-line line))
      (when token
        (yield token))
      (when done
        (break)))))
```

Because `stream-ollama-chat` is an async generator, callers process tokens as they arrive (`(for [:async token (stream-ollama-chat ...)] ...)`) and can measure time-to-first-token (TTFT) separately from total generation time. When Ollama is not running locally, `try-live-ollama` catches the connection or timeout error and reports that the offline `FakeNDJSONByteStream` transport was used.

### 4. Producer/Consumer Pipelines with `asyncio.Queue`: `pipeline.hy`

When a workflow has distinct stages with different speeds, such as downloading HTML, parsing DOM trees, and updating an index, connecting worker pools with bounded `asyncio.Queue` instances decouples the stages and bounds memory usage. If the parser falls behind the downloader, `(await (.put page-queue ...))` pauses the crawl workers as soon as `page-queue` reaches `maxsize`.

Here is **pipeline.hy**:

```hy
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
```

Each stage shuts down cleanly using sentinel `None` values:

1. Before starting, we enqueue one `None` sentinel per `crawl-worker` at the tail of `url-queue`.
2. `coordinator` runs all `crawl-worker` tasks inside an inner `TaskGroup`. Once that `TaskGroup` exits, every URL has been fetched and placed onto `page-queue`, so `coordinator` pushes one `None` sentinel per `extract-worker` onto `page-queue`.
3. `extract-stage` runs all `extract-worker` tasks in its own `TaskGroup` and then pushes a single `None` sentinel onto `doc-queue` to stop `index-worker`.

### 5. Threads, Processes, and Free-Threaded Python: `cpu_offload.hy`

Never run a CPU-heavy function or a blocking synchronous library directly on the `asyncio` event loop thread; doing so freezes every other coroutine until the function returns. Instead, delegate blocking or GIL-releasing calls to a thread pool with `(asyncio.to-thread fn #* args)`, and delegate pure-Python CPU work to a `ProcessPoolExecutor` via `(.run-in-executor loop pool fn arg)`.

Running `ProcessPoolExecutor` from a `.hy` script involves a subtle interaction with Python's `spawn` start method (the default on macOS, Windows, and Python 3.14+ on Linux):

1. When you launch a program with `uv run hy demo.hy`, `sys.executable` points to the `hy` wrapper script rather than `python`, and `__main__.__file__` points to `demo.hy`.
2. When `multiprocessing` spawns a worker process, it runs `sys.executable -c "from multiprocessing.spawn import spawn_main; ..."` and tries to compile `__main__.__file__` as Python syntax before running your pool initializer.
3. Even after the worker starts Python, a fresh interpreter cannot import functions defined in `.hy` modules until `import hy` has registered Hy's import hook.

Our helper `make-hy-process-pool` in **cpu_offload.hy** solves all three issues in twenty lines:

```hy
(defn ensure-python-spawn-executable []
  "When invoked via the hy CLI, sys.executable points to the hy script and
  __main__.__file__ points to a .hy script that Python's spawn bootstrapper
  cannot compile as .py. Point multiprocessing at the sibling python binary
  and clear .hy __main__.__file__ so worker processes start cleanly."
  (setv exe (Path sys.executable))
  (when (in exe.name #{"hy" "hy.exe"})
    (for [candidate ["python" "python3" "python.exe"]]
      (setv py (.with-name exe candidate))
      (when (.exists py)
        (multiprocessing.set-executable (str py))
        (break))))
  (setv main-mod (.get sys.modules "__main__")
        main-file (getattr main-mod "__file__" None))
  (when (and (isinstance main-file str) (.endswith main-file ".hy"))
    (setv main-mod.__file__ None
          main-mod.__spec__ None)))


(defn make-hy-process-pool [[max-workers 2]]
  "Create a ProcessPoolExecutor whose workers import hy on startup so they can
  unpickle functions defined in .hy modules."
  (ensure-python-spawn-executable)
  (ProcessPoolExecutor :max-workers max-workers
                       :initializer builtins.__import__
                       :initargs #("hy")))


(defn :async offload-with-to-thread [payloads [iterations 25000]]
  "Run blocking-digest-work across payloads concurrently via asyncio.to_thread."
  (setv tasks [])
  (with [:async tg (asyncio.TaskGroup)]
    (for [p payloads]
      (.append tasks
               (.create-task tg (asyncio.to-thread blocking-digest-work p iterations)))))
  (lfor t tasks (.result t)))


(defn :async offload-cpu-process-pool [ranges [max-workers 2]]
  "Run pure-Python count-primes-in-range across multiple worker processes."
  (setv loop (asyncio.get-running-loop))
  (with [pool (make-hy-process-pool :max-workers max-workers)]
    (setv futures
          (lfor r ranges
                (.run-in-executor loop pool count-primes-in-range r)))
    (list (await (asyncio.gather #* futures)))))
```

Passing `:initializer builtins.__import__ :initargs #("hy")` ensures every worker process imports `hy` at startup before unpickling any task function from `cpu_offload.hy`.

#### A Note on Free-Threaded Python (PEP 703)

Python 3.13 introduced an experimental free-threaded build (`python3.13t` / `python3.14t`) that disables the Global Interpreter Lock (GIL), and Hy 1.3.1 runs on Python 3.9 through 3.15. You can check at runtime whether the current interpreter has the GIL enabled with `python-gil-status` in **cpu_offload.hy**:

```hy
(defn python-gil-status []
  "Return a dict describing the current Python version and whether the GIL is enabled."
  (setv check-fn (getattr sys "_is_gil_enabled" None)
        gil-enabled (if (callable check-fn) (check-fn) True))
  {"python_version" (get (.split sys.version) 0)
   "gil_enabled" gil-enabled
   "free_threaded" (not gil-enabled)})
```

Even on a free-threaded build, `asyncio` remains the right choice for high-concurrency network I/O because coroutines cost a few kilobytes of memory compared to OS threads and avoid shared-state data races by switching only at explicit `await` points.

### 6. Case Study: Porting the Web Scraper to Async (`async_scraper.hy`)

In the "Responsible Web Scraping" chapter (**source_code_for_examples/webscraping**), `get_web_page.hy`, `get_page_data.hy`, and `npr_front_page_summary.hy` used synchronous `urllib.request.urlopen` calls to download pages one by one and extract BeautifulSoup tag dictionaries and long headlines (anchor text longer than 40 characters).

In **async_scraper.hy**, we keep the same data extraction functions (`get-element-data` and `parse-page-elements`) and implement both a sequential scraper and a semaphore-bounded concurrent scraper:

```hy
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
```

When we run `compare-sequential-vs-concurrent` over our 8 sample news pages with a 40 ms per-request simulated latency and one transient HTTP 503 failure on `/news/open-models`:

| Mode | In-Flight Cap | Total Requests (with 1 Retry) | Measured Time | Speedup |
| --- | --- | --- | --- | --- |
| `scrape-pages-sequential` | 1 | 9 | 396.1 ms | 1.00x |
| `scrape-pages-concurrent` | 4 (`Semaphore(4)`) | 9 | 128.8 ms | 3.08x |

Both functions return the exact same list of parsed page dictionaries in the same URL order, because `scrape-pages-concurrent` collects `(.result t)` from the `tasks` list in the order the tasks were created.

## Tests

Testing async code against live websites or live LLM servers leads to slow, flaky tests. In **test_async.hy**, we configure `pytest-asyncio` with `asyncio_mode = "auto"` in `pyproject.toml` so every `(defn :async test-... [])` function runs automatically inside an event loop, and we replace network sockets with `httpx.MockTransport`.

Here is how `make-mock-transport` in **bounded_fetch.hy** simulates latency, tracks maximum in-flight concurrency, and injects a configurable number of initial HTTP 503 failures per path:

```hy
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
```

Notice the `(nonlocal in-flight max-in-flight)` declaration inside `handler`. Each time a request enters `handler`, it increments `in-flight`, updates `max-in-flight`, sleeps for `latency-seconds`, and decrements `in-flight` inside `(finally ...)`. Our test in **test_async.hy** then asserts both that retries succeeded and that the semaphore never allowed more than 3 concurrent requests:

```hy
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
```

Run the full test suite with `pytest`:

```bash
$ uv run pytest -q
...........                                                              [100%]
11 passed in 0.80s
```

## Wrap Up

Hy gives you full access to Python's modern concurrency stack with clean, consistent syntax: `:async` modifiers on functions, loops, context managers, and comprehensions; `asyncio.TaskGroup` and `except*` for structured concurrency; `httpx.AsyncClient` for bounded HTTP and LLM streaming; `asyncio.Queue` for backpressure-aware pipelines; and `to-thread` / `ProcessPoolExecutor` when work must leave the event loop.

## Optional Practice Problems

1. **Add Jitter and `Retry-After` Support to `fetch-with-retry` (Small)**:
   Modify `fetch-with-retry` in `bounded_fetch.hy` so that when a response has status `429` and includes a `"Retry-After"` header (in seconds), it sleeps for `(float (get response.headers "Retry-After"))` instead of the exponential backoff formula. When `"Retry-After"` is absent, add uniform random jitter between `0` and `0.005` seconds to the backoff delay so concurrent retries do not fire in lockstep. Add a unit test in `test_async.hy` using `httpx.MockTransport`.

2. **Add an Async Summarization Stage to the Queue Pipeline (Open-Ended)**:
   Extend `run-crawl-extract-index` in `pipeline.hy` with a fourth stage (`summarize-worker`) that reads extracted documents from `doc-queue`, calls `collect-chat-stream` from `streaming_llm.hy` (using `make-fake-ollama-transport` by default or live Ollama when a `--live` flag is set) to generate a one-sentence summary of each page, and stores the summary alongside the document in the index. Bound the summarization stage with a semaphore so at most two LLM streams run at the same time.

## Further Reading

- [Hy 1.3.1 Manual: Core Macros (`defn`, `fn`, `with`, `for`, `lfor`, `try`)](https://hylang.org/hy/doc/v1.3.1/api)
- [Python `asyncio` Documentation: Coroutines and Tasks (`TaskGroup`, `timeout`)](https://docs.python.org/3/library/asyncio-task.html)
- [HTTPX Async Support and `MockTransport`](https://www.python-httpx.org/async/)
- Matthew Fowler, *Python Concurrency with asyncio* (Manning)
- Luciano Ramalho, *Fluent Python*, 2nd Edition, Chapters 19-21 (O'Reilly)
