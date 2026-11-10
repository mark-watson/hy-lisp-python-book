;; hygiene.hy -- Macro hygiene: multiple evaluation, variable capture, and fixes.

(require hyrule [defmacro! def-gensyms])


;; ---------- 1. Multiple evaluation ----------

(defmacro square-bad [x]
  "BROKEN: evaluates x twice when x has side effects."
  `(* ~x ~x))


(defmacro square-good [x]
  "HYGIENIC: binds x to a fresh gensym so x is evaluated once."
  (setv val (hy.gensym "val"))
  `(do
     (setv ~val ~x)
     (* ~val ~val)))


(defmacro! square-o! [o!x]
  "HYGIENIC (via hyrule defmacro!): o!x evaluates once and binds to g!x."
  `(* ~g!x ~g!x))


;; ---------- 2. Accidental variable capture ----------

(defmacro sum-steps-bad [n #* body]
  "BROKEN: leaks loop variable 'step' and accumulator 'total' into caller scope."
  `(do
     (setv total 0)
     (for [step (range ~n)]
       (+= total (do ~@body)))
     total))


(defmacro sum-steps-good [n #* body]
  "HYGIENIC: uses def-gensyms so caller variables named step or total are safe."
  (def-gensyms total step limit)
  `(do
     (setv ~limit ~n
           ~total 0)
     (for [~step (range ~limit)]
       (+= ~total (do ~@body)))
     ~total))


;; ---------- 3. Intentional capture (anaphoric macro) ----------

(defmacro aif [test-form then-form [else-form None]]
  "Anaphoric if: intentionally binds 'it' to the value of test-form."
  `(do
     (setv it ~test-form)
     (if it
         ~then-form
         ~else-form)))
