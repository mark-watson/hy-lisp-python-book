#!/usr/bin/env hy
"Bridging blocking I/O and CPU-bound work into asyncio with asyncio.to_thread,
ThreadPoolExecutor, ProcessPoolExecutor, and runtime GIL status inspection."

(import asyncio)
(import builtins)
(import concurrent.futures [ThreadPoolExecutor ProcessPoolExecutor])
(import hashlib)
(import multiprocessing)
(import pathlib [Path])
(import sys)


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


(defn blocking-digest-work [payload [iterations 25000]]
  "CPU/GIL-releasing work: repeated SHA-256 hashing."
  (setv data (.encode payload "utf-8"))
  (for [_ (range iterations)]
    (setv data (.digest (hashlib.sha256 data))))
  (.hex data))


(defn count-primes-in-range [bounds]
  "Pure-Python CPU-bound function suitable for ProcessPoolExecutor.
  Takes #(start end) and returns the count of primes in [start, end)."
  (setv [start end] bounds
        count 0)
  (for [n (range (max 2 start) end)]
    (setv is-prime True
          limit (int (** n 0.5)))
    (for [d (range 2 (+ limit 1))]
      (when (= (% n d) 0)
        (setv is-prime False)
        (break)))
    (when is-prime
      (+= count 1)))
  count)


(defn :async offload-with-to-thread [payloads [iterations 25000]]
  "Run blocking-digest-work across payloads concurrently via asyncio.to_thread."
  (setv tasks [])
  (with [:async tg (asyncio.TaskGroup)]
    (for [p payloads]
      (.append tasks
               (.create-task tg (asyncio.to-thread blocking-digest-work p iterations)))))
  (lfor t tasks (.result t)))


(defn :async offload-with-thread-pool [payloads [max-workers 4] [iterations 25000]]
  "Run blocking-digest-work on an explicit ThreadPoolExecutor via run_in_executor."
  (setv loop (asyncio.get-running-loop))
  (with [pool (ThreadPoolExecutor :max-workers max-workers)]
    (setv futures
          (lfor p payloads
                (.run-in-executor loop pool blocking-digest-work p iterations)))
    (list (await (asyncio.gather #* futures)))))


(defn :async offload-cpu-process-pool [ranges [max-workers 2]]
  "Run pure-Python count-primes-in-range across multiple worker processes."
  (setv loop (asyncio.get-running-loop))
  (with [pool (make-hy-process-pool :max-workers max-workers)]
    (setv futures
          (lfor r ranges
                (.run-in-executor loop pool count-primes-in-range r)))
    (list (await (asyncio.gather #* futures)))))


(defn python-gil-status []
  "Return a dict describing the current Python version and whether the GIL is enabled."
  (setv check-fn (getattr sys "_is_gil_enabled" None)
        gil-enabled (if (callable check-fn) (check-fn) True))
  {"python_version" (get (.split sys.version) 0)
   "gil_enabled" gil-enabled
   "free_threaded" (not gil-enabled)})
