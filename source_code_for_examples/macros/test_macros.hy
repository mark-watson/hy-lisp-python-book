;; test_macros.hy -- Tests for core macros, hygiene, namespaces, and reader macros.

(import os)
(import sqlite3)
(import pytest)
(import core_macros [expand-once-str form-to-python])
(import reader_macros [SqlQuery execute-sql])

(require core_macros [unless do-while swap! when-let with-timer timed mini-match])
(require hygiene [square-bad square-good square-o! sum-steps-bad sum-steps-good aif])
(require reader_macros :readers [env sql json])


(defn test-unless-expansion-and-behavior []
  (assert (= (expand-once-str '(unless ready (launch)))
             "'(when (not ready) (launch))"))
  (setv log [])
  (unless False
    (.append log "first")
    (.append log "second"))
  (unless True
    (.append log "never"))
  (assert (= log ["first" "second"])))


(defn test-do-while-runs-at-least-once []
  (setv runs 0)
  (do-while (+= runs 1) False)
  (assert (= runs 1))

  (setv acc [])
  (do-while (.append acc (len acc)) (< (len acc) 4))
  (assert (= acc [0 1 2 3])))


(defn test-swap-variables-and-indexed-places []
  (setv a 10
        b 20)
  (swap! a b)
  (assert (= [a b] [20 10]))

  (setv items ["x" "y"])
  (swap! (get items 0) (get items 1))
  (assert (= items ["y" "x"])))


(defn test-when-let []
  (setv calls 0)
  (defn lookup [k]
    (nonlocal calls)
    (+= calls 1)
    (.get {"a" 42} k))

  (setv hit (when-let [val (lookup "a")] (+ val 8)))
  (setv miss (when-let [val (lookup "b")] (+ val 8)))
  (assert (= hit 50))
  (assert (is miss None))
  (assert (= calls 2)))


(defn test-with-timer-and-timed [capsys]
  (setv val (with-timer "work" (+ 20 22)))
  (assert (= val 42))
  (setv captured (.readouterr capsys))
  (assert (in "work took" captured.out))

  (setv [res elapsed] (timed (* 6 7)))
  (assert (= res 42))
  (assert (>= elapsed 0.0)))


(defn test-mini-match-evaluates-target-once []
  (setv evals 0)
  (defn get-code []
    (nonlocal evals)
    (+= evals 1)
    404)

  (setv label
    (mini-match (get-code)
      [200 "ok"]
      [404 "missing"]
      [:else "other"]))
  (assert (= label "missing"))
  (assert (= evals 1))

  (assert (= (mini-match 999 [1 "one"] [_ "fallback"]) "fallback")))


(defn test-hy2py-golden-translation []
  (setv py-swap (form-to-python '(swap! left right)))
  (assert (= (.strip py-swap) "[left, right] = [right, left]"))

  (setv py-unless (form-to-python '(unless done (step))))
  (assert (in "not done" py-unless))
  (assert (in "step()" py-unless)))


(defn test-multiple-evaluation-hygiene []
  (setv counter 0)
  (defn next-int []
    (nonlocal counter)
    (+= counter 1)
    3)

  (setv bad (square-bad (next-int)))
  (assert (= bad 9))
  (assert (= counter 2))

  (setv counter 0)
  (setv good (square-good (next-int)))
  (assert (= good 9))
  (assert (= counter 1))

  (setv counter 0)
  (setv good-o (square-o! (next-int)))
  (assert (= good-o 9))
  (assert (= counter 1)))


(defn test-variable-capture-hygiene []
  (setv step 10
        total 100)
  ;; Broken macro overwrites caller's 'step' with 0, 1, 2
  (assert (= (sum-steps-bad 3 step) 3))

  (setv step 10
        total 100)
  ;; Hygienic macro preserves caller's 'step' (10 + 10 + 10 = 30) and 'total'
  (assert (= (sum-steps-good 3 step) 30))
  (assert (= step 10))
  (assert (= total 100)))


(defn test-anaphoric-aif []
  (assert (= (aif (+ 2 3) (* it 10) 0) 50))
  (assert (= (aif None (* it 10) -1) -1)))


(defn test-hy-r-macro-namespace []
  (assert (= (hy.R.core_macros.unless False "via-hy-R") "via-hy-R")))


(defn test-reader-macro-env [monkeypatch]
  (.setenv monkeypatch "HY_BOOK_TEST_VAR" "configured")
  (.delenv monkeypatch "HY_BOOK_MISSING_VAR" :raising False)
  (assert (= #env "HY_BOOK_TEST_VAR" "configured"))
  (assert (is #env "HY_BOOK_MISSING_VAR" None))
  (assert (= #env ["HY_BOOK_MISSING_VAR" "default-val"] "default-val")))


(defn test-reader-macro-json []
  (setv data #json "{\"language\": \"Hy\", \"versions\": [1, 2, 3], \"active\": true}")
  (assert (= (get data "language") "Hy"))
  (assert (= (get data "versions") [1 2 3]))
  (assert (is (get data "active") True))

  (with [(pytest.raises Exception)]
    (hy.eval (hy.read "(do (require reader_macros :readers [json]) #json \"{broken\")"))))


(defn test-reader-macro-sql []
  (setv conn (sqlite3.connect ":memory:"))
  (.execute conn "CREATE TABLE books (title TEXT, pages INT)")
  (.executemany conn
    "INSERT INTO books VALUES (?, ?)"
    [#("On Lisp" 432)
     #("Practical Common Lisp" 499)
     #("Brief Guide" 90)])

  (setv min-pages 200
        q #sql ["  SELECT title, pages
                   FROM   books
                   WHERE  pages >= ?
                   ORDER BY pages " min-pages])
  (assert (isinstance q SqlQuery))
  (assert (= q.sql "SELECT title, pages FROM books WHERE pages >= ? ORDER BY pages"))
  (assert (= q.params #(200)))

  (setv rows (execute-sql conn q))
  (assert (= (len rows) 2))
  (assert (= (get (get rows 0) "title") "On Lisp"))
  (.close conn)

  ;; Mismatched '?' placeholder count fails at compile/read time
  (with [(pytest.raises Exception)]
    (hy.eval (hy.read "(do (require reader_macros :readers [sql]) #sql [\"SELECT ? AND ?\" 1])"))))
