#!/usr/bin/env hy
"Core asyncio building blocks in Hy: coroutines, TaskGroup, timeouts,
exception groups (except*), async context managers, and async generators."

(import asyncio)
(import time)


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


(defn :async transform-with-async-fn [values]
  "Demonstrate an anonymous async function (fn :async ...) with asyncio.gather."
  (setv worker (fn :async [x]
                 (await (asyncio.sleep 0.005))
                 (* x x)))
  (await (asyncio.gather #* (lfor v values (worker v)))))


(defn :async run-with-timeout [coro timeout-seconds]
  "Run coro inside asyncio.timeout; return {:ok result} or {:error 'timeout'}."
  (try
    (with [:async (asyncio.timeout timeout-seconds)]
      {"ok" (await coro)})
    (except [TimeoutError]
      {"error" "timeout"})))


(defn :async risky-worker [item]
  "Raise ValueError on negative ints, KeyError on None, else return item * 10."
  (await (asyncio.sleep 0.005))
  (cond
    (is item None) (raise (KeyError "missing item"))
    (< item 0) (raise (ValueError f"negative item: {item}"))
    True (* item 10)))


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


(defn :async sum-stream [aiter]
  "Iterate over an async iterator using (for [:async x ...] ...)."
  (setv total 0)
  (for [:async x aiter]
    (+= total x))
  total)
