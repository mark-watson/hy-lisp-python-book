;; demo.hy -- Guided tour of Hy macros, hygiene, reader macros, and the HTML/SVG DSL.

(import os)
(import sqlite3)
(import core_macros [expand-once-str form-to-python])
(import html_dsl [raw])
(import reader_macros [execute-sql])

(require core_macros [unless do-while swap! when-let with-timer timed mini-match])
(require hygiene [square-bad square-good square-o! sum-steps-bad sum-steps-good aif])
(require reader_macros :readers [env sql json])
(require html_dsl [html svg])


(defn demo-core-macros []
  (print "=== 1. Core Macros and Expansion ===")
  (setv items [])
  (unless (> (len items) 0)
    (.append items "initialized"))
  (print "unless result:" items)

  (setv count 0
        steps [])
  (do-while
    (do
      (.append steps count)
      (+= count 1))
    (< count 3))
  (print "do-while steps:" steps)

  (setv left "alpha"
        right "omega")
  (swap! left right)
  (print "after swap!:" left right)

  (setv lookup {"hy" "1.3.1"})
  (when-let [ver (.get lookup "hy")]
    (print "when-let found version:" ver))

  (for [code [200 404 503]]
    (print f"HTTP {code} ->"
           (mini-match code
             [200 "OK"]
             [404 "Not Found"]
             [:else "Server Error"])))

  (print "\nMacroexpansion of (unless ready (boot)):")
  (print " " (expand-once-str '(unless ready (boot))))
  (print "Python AST via form-to-python:")
  (print " " (form-to-python '(swap! a b))))


(defn demo-hygiene []
  (print "\n=== 2. Hygiene: Multiple Evaluation and Capture ===")
  (setv calls 0)
  (defn bump []
    (nonlocal calls)
    (+= calls 1)
    4)

  (setv bad-ans (square-bad (bump))
        bad-calls calls)
  (setv calls 0
        good-ans (square-good (bump))
        good-calls calls)
  (setv calls 0
        o-ans (square-o! (bump))
        o-calls calls)
  (print f"square-bad(bump):  result={bad-ans}, calls={bad-calls} (evaluated twice!)")
  (print f"square-good(bump): result={good-ans}, calls={good-calls}")
  (print f"square-o!(bump):   result={o-ans}, calls={o-calls}")

  (setv step 10)
  (setv captured (sum-steps-bad 3 step))
  (setv step 10)
  (setv hygienic (sum-steps-good 3 step))
  (print f"sum-steps-bad  with outer step=10: {captured} (captured 'step'!)")
  (print f"sum-steps-good with outer step=10: {hygienic} (outer step preserved)")

  (setv msg (aif (.get {"author" "Mark"} "author")
                 f"Hello, {it}!"
                 "Anonymous"))
  (print "anaphoric aif:" msg))


(defn demo-reader-macros []
  (print "\n=== 3. Reader Macros (#env, #json, #sql) ===")
  (setv (get os.environ "DEMO_ENV_NAME") "hy-macros")
  (print "#env DEMO_ENV_NAME:" #env "DEMO_ENV_NAME")
  (print "#env with default: " #env ["MISSING_KEY" "fallback-value"])

  (setv pkg #json "{\"name\": \"hy\", \"release\": 1.3, \"lisp\": true}")
  (print "#json parsed at read time:" pkg)

  (setv conn (sqlite3.connect ":memory:"))
  (.execute conn "CREATE TABLE languages (name TEXT, year INT, lisp INT)")
  (.executemany conn
    "INSERT INTO languages VALUES (?, ?, ?)"
    [#("Common Lisp" 1984 1)
     #("Python" 1991 0)
     #("Clojure" 2007 1)
     #("Hy" 2013 1)])
  (setv min-year 2000
        q #sql ["SELECT name, year FROM languages WHERE lisp = 1 AND year >= ? ORDER BY year"
                min-year])
  (print "Compiled SqlQuery:" q)
  (print "Query results:" (execute-sql conn q))
  (.close conn))


(defn demo-html-dsl []
  (print "\n=== 4. Compile-Time HTML and SVG DSL ===")
  (setv user "<script>alert(1)</script>"
        items ["Macros" "Reader Macros" "DSLs"])
  (setv card
    (html
      [:div {:class "card" :data-kind "demo"}
       [:h2 "Topic Summary"]
       [:p "Viewer: " user]
       [:ul (lfor item items (html [:li item]))]
       [:hr]]))
  (print "Rendered HTML (with automatic escaping):")
  (print card)

  (print "\nMacroexpansion of static + dynamic HTML:")
  (print " " (hy.repr (hy.macroexpand-1 '(html [:div {:class "box"} [:h1 "Title"] [:p user]]))))

  (setv badge
    (svg {:width 140 :height 40 :viewBox "0 0 140 40"}
      [:rect {:x 2 :y 2 :width 136 :height 36 :rx 6 :fill "#eef"}]
      [:text {:x 70 :y 25 :text-anchor "middle"} "Hy 1.3.1"]))
  (print "\nRendered SVG:")
  (print badge))


(when (= __name__ "__main__")
  (demo-core-macros)
  (demo-hygiene)
  (demo-reader-macros)
  (demo-html-dsl))
