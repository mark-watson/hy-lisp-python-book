;; core_macros.hy -- Control-flow macros, timing macros, and AST inspection.

(import ast)
(import time)
(import hy.compiler [hy-compile])
(import hy.models [Keyword Symbol])


(defmacro unless [test #* body]
  "Evaluate body forms only when test is falsy."
  `(when (not ~test)
     ~@body))


(defmacro do-while [body-form condition]
  "Execute body-form at least once, repeating while condition is truthy."
  `(while True
     ~body-form
     (when (not ~condition)
       (break))))


(defmacro swap! [left right]
  "Swap two assignable places in place."
  `(setv [~left ~right] [~right ~left]))


(defmacro when-let [binding #* body]
  "Bind a symbol to an expression and run body only when the value is truthy.
  Usage: (when-let [user (find-user uid)] (greet user))"
  (when (!= (len binding) 2)
    (raise (SyntaxError "when-let expects a [symbol expr] binding pair")))
  (setv [sym expr] binding)
  `(do
     (setv ~sym ~expr)
     (when ~sym
       ~@body)))


(defmacro with-timer [label #* body]
  "Run body, print elapsed seconds with label, and return the body's value."
  (setv start (hy.gensym "start"))
  `(do
     (setv ~start (hy.I.time.perf-counter))
     (try
       (do ~@body)
       (finally
         (print ~label "took"
                (round (- (hy.I.time.perf-counter) ~start) 4)
                "s")))))


(defmacro timed [expr]
  "Evaluate expr once and return #(result elapsed-seconds)."
  (setv start (hy.gensym "start")
        result (hy.gensym "result"))
  `(do
     (setv ~start (hy.I.time.perf-counter)
           ~result ~expr)
     #(~result (- (hy.I.time.perf-counter) ~start))))


(defmacro mini-match [expr #* clauses]
  "Dispatch expr against [pattern result] clauses without re-evaluating expr.
  Use :else or _ for the wildcard branch."
  (setv target (hy.gensym "target")
        branches [])
  (for [clause clauses]
    (when (!= (len clause) 2)
      (raise (SyntaxError "mini-match clauses must be [pattern result] pairs")))
    (setv [pat result] clause)
    (if (or (= pat :else) (= pat '_))
        (.extend branches [True result])
        (.extend branches [`(= ~target ~pat) result])))
  `(do
     (setv ~target ~expr)
     (cond ~@branches)))


(defn expand-once-str [form [module None]]
  "Return the single-step macro expansion of form as Hy source text."
  (hy.repr (if (is module None)
               (hy.macroexpand-1 form)
               (hy.macroexpand-1 form module))))


(defn form-to-python [form [module-name "__main__"]]
  "Compile a quoted Hy form to formatted Python source code (like hy2py)."
  (setv expanded (hy.macroexpand form)
        py-ast (hy-compile expanded module-name)
        text (.strip (ast.unparse py-ast)))
  (.removeprefix text "import hy\n"))
