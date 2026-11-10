;; terms.hy -- Graph terms, logic variables, and unification.
;;
;; A term is a keyword (:mark), a string, or a number. Two wrapper classes
;; give the query language its extra vocabulary:
;;
;;   ?name    (Var "name")        a logic variable
;;   ~:pred   (Neural :pred)      a relation the language model may complete
;;
;; Common Lisp needs reader macros for this syntax. Hy does not: ?name already
;; reads as a symbol, [s p o] as a list, and ~x as (unquote x). The functions
;; at the end of this file turn those forms into terms.

(import dataclasses [dataclass])
(import re)
(import hy.models [Keyword Symbol Expression String Integer Float List])


(defclass [(dataclass :frozen True)] Var []
  "A logic variable. Two variables with the same name are equal."
  #^ str name
  (defn __repr__ [self] (+ "?" self.name)))

(defclass [(dataclass :frozen True)] Neural []
  "A predicate that falls back to the language model when no fact matches."
  #^ object name
  (defn __repr__ [self] (+ "~" (show self.name))))


(defn show [term]
  "Render a term, a triple, or a pattern in the syntax you would type."
  (if (isinstance term #(list tuple))
      (+ "[" (.join " " (map show term)) "]")
      (hy.repr term)))

(defn to-keyword [text]
  "Turn text from a model or a JSON client into a keyword:
  \"Common Lisp\" becomes :common-lisp. Returns None when nothing is left."
  (setv name (.strip (re.sub r"[^\w+]+" "-" (.lower (str text))) "-"))
  (if name (Keyword name) None))

(defn ground? [x]
  "True when x contains no variables or neural predicates."
  (if (isinstance x #(list tuple))
      (all (map ground? x))
      (not (isinstance x #(Var Neural)))))

(defn variables [x [found None]]
  "Return the distinct variables in x, in order of first appearance."
  (setv found (if (is found None) [] found))
  (cond
    (isinstance x Var) (when (not-in x found) (.append found x))
    (isinstance x Neural) (variables x.name found)
    (isinstance x #(list tuple)) (for [item x] (variables item found)))
  found)


;; ---------- unification, in the Norvig/PAIP style ----------
;;
;; An environment is a dict from Var to value. Environments are never mutated:
;; binding a variable builds a new dict, so a generator that is still walking
;; one branch of a search cannot be disturbed by another. None means failure,
;; which leaves {} free to mean "success with no bindings".

(defn walk [x env]
  "Follow variable bindings in env until x is a value or an unbound variable."
  (while (and (isinstance x Var) (in x env))
    (setv x (get env x)))
  x)

(defn unify [x y [env {}]]
  "Unify x with y under env. Return the extended environment, or None."
  (when (is env None)
    (return None))
  (setv x (walk x env)
        y (walk y env))
  (cond
    (= x y) env
    (isinstance x Var) {#** env  x y}
    (isinstance y Var) {#** env  y x}
    (and (isinstance x #(list tuple)) (isinstance y #(list tuple))
         (= (len x) (len y)))
      (do
        (for [[a b] (zip x y)]
          (setv env (unify a b env)))
        env)
    True None))

(defn resolve [x env]
  "Replace every bound variable in x with its value."
  (setv x (walk x env))
  (if (isinstance x #(list tuple))
      (tuple (gfor item x (resolve item env)))
      x))


;; ---------- from Hy forms to terms ----------

(defn var-symbol? [form]
  (and (isinstance form Symbol) (> (len form) 1) (.startswith form "?")))

(defn unquote? [form]
  (and (isinstance form Expression) (= (len form) 2)
       (= (get form 0) 'unquote)))

(defn to-term [form]
  "Convert one form produced by the Hy reader into a term, without evaluating
  it. The REPL and the log replay use this, so neither can run code."
  (cond
    (isinstance form Keyword) (Keyword form.name)
    (var-symbol? form) (Var (cut (str form) 1 None))
    (unquote? form) (Neural (to-term (get form 1)))
    (isinstance form String) (str form)
    (isinstance form Integer) (int form)
    (isinstance form Float) (float form)
    (isinstance form Symbol)
      (raise (ValueError f"{form} is not a term; did you mean :{form} or ?{form}"))
    True (raise (ValueError f"not a term: {(hy.repr form)}"))))

(defn to-pattern [form]
  "Convert a [s p o] form into a pattern tuple."
  (when (not (and (isinstance form List) (= (len form) 3)))
    (raise (ValueError f"a pattern needs exactly three terms: {(hy.repr form)}")))
  (tuple (map to-term form)))

(defn compile-term [form]
  "Macro helper. Like to-term, but it returns code: ?x and ~p are rewritten and
  everything else is left for Hy to evaluate, so a pattern can mention ordinary
  variables and function calls."
  (cond
    (var-symbol? form) `(hy.I.nsk/terms.Var ~(cut (str form) 1 None))
    (unquote? form) `(hy.I.nsk/terms.Neural ~(compile-term (get form 1)))
    ;; A bare keyword in a call would be read as a keyword argument, so quote it.
    (isinstance form Keyword) `(quote ~form)
    True form))

(defn compile-pattern [form]
  (when (not (and (isinstance form List) (= (len form) 3)))
    (raise (ValueError f"a pattern needs exactly three terms: {(hy.repr form)}")))
  `#(~@(map compile-term form)))
