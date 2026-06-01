;;;; data.hy — Core data structures for symbolic mathematics
;;;;

(import math)
(import fractions [Fraction])

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 1.  SYM-VARIABLE
;;;; ─────────────────────────────────────────────────────────────────────────

(defclass SymVariable []
  "A symbolic variable such as x, y, or t.
  domain may be 'real' (default), 'complex', or 'integer'."
  (defn __init__ [self name [domain "real"]]
    (setv self.name name)
    (setv self.domain domain))

  (defn __eq__ [self other]
    (and (isinstance other SymVariable)
         (= self.name other.name)
         (= self.domain other.domain)))

  (defn __repr__ [self]
    f"SymVariable(name={self.name}, domain={self.domain})"))

(defn make-variable [name [domain "real"]]
  "Create a symbolic variable with name and optional domain."
  (assert (in domain ["real" "complex" "integer"])
          f"domain must be 'real', 'complex', or 'integer', got {domain}")
  (SymVariable name domain))

(defn variable-p [obj]
  "Return True if OBJ is a SymVariable."
  (isinstance obj SymVariable))

(defn variable-name [obj]
  "Return the name of the SymVariable."
  obj.name)

(defn variable-domain [obj]
  "Return the domain of the SymVariable."
  obj.domain)

(defn variable= [a b]
  "Return True if variables A and B represent the same symbolic variable."
  (and (variable-p a)
       (variable-p b)
       (= a.name b.name)
       (= a.domain b.domain)))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 2.  SYM-CONSTANT
;;;; ─────────────────────────────────────────────────────────────────────────

(defclass SymConstant []
  "A named mathematical constant."
  (defn __init__ [self name value]
    (setv self.name name)
    (setv self.value value))

  (defn __eq__ [self other]
    (and (isinstance other SymConstant)
         (= self.name other.name)
         (= self.value other.value)))

  (defn __repr__ [self]
    f"SymConstant(name={self.name}, value={self.value})")

  (defn numeric-value [self]
    (cond
      (= self.value "pi") math.pi
      (= self.value "e") (math.exp 1.0)
      True self.value)))

(defn make-constant [name value]
  "Create a named constant with name and value."
  (assert (or (isinstance value #(int float))
              (in value ["pi" "e"]))
          f"value must be a number, 'pi', or 'e', got {value}")
  (SymConstant name value))

(defn constant-p [obj]
  "Return True if OBJ is a SymConstant."
  (isinstance obj SymConstant))

(defn constant-name [obj]
  "Return the name of the constant."
  obj.name)

(defn constant-value [obj]
  "Return the value of the constant."
  obj.value)

(defn constant-numeric-value [c]
  "Return the numeric (floating-point) value of constant C."
  (.numeric-value c))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 3.  SYM-TERM  (monomial:  coefficient * variable ^ exponent)
;;;; ─────────────────────────────────────────────────────────────────────────

(defclass SymTerm []
  "A single monomial: COEFFICIENT * VARIABLE ^ EXPONENT."
  (defn __init__ [self coefficient variable exponent]
    (setv self.coefficient coefficient)
    (setv self.variable variable)
    (setv self.exponent exponent))

  (defn __eq__ [self other]
    (and (isinstance other SymTerm)
         (= self.coefficient other.coefficient)
         (variable= self.variable other.variable)
         (= self.exponent other.exponent)))

  (defn __repr__ [self]
    f"SymTerm(coefficient={self.coefficient}, variable={self.variable}, exponent={self.exponent})")

  (defn negate [self]
    (SymTerm (- self.coefficient) self.variable self.exponent))

  (defn scale [self scalar]
    (SymTerm (* scalar self.coefficient) self.variable self.exponent))

  (defn to-string [self]
    (cond
      (= self.exponent 0) (str self.coefficient)
      (= self.exponent 1) f"{self.coefficient}{self.variable.name}"
      True f"{self.coefficient}{self.variable.name}^{self.exponent}")))

(defn make-term [coefficient variable exponent]
  "Create a monomial term."
  (assert (isinstance coefficient #(int float Fraction)))
  (assert (variable-p variable))
  (assert (and (isinstance exponent int) (>= exponent 0)))
  (SymTerm coefficient variable exponent))

(defn term-p [obj]
  "Return True if OBJ is a SymTerm."
  (isinstance obj SymTerm))

(defn term-coefficient [obj]
  obj.coefficient)

(defn term-variable [obj]
  obj.variable)

(defn term-exponent [obj]
  obj.exponent)

(defn term= [a b]
  (= a b))

(defn term-negate [term]
  (.negate term))

(defn term-scale [term scalar]
  (.scale term scalar))

(defn term->string [term]
  (.to-string term))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 4.  SYM-POLYNOMIAL
;;;; ─────────────────────────────────────────────────────────────────────────

(defclass SymPolynomial []
  "A polynomial in one variable represented as an ordered list of terms."
  (defn __init__ [self variable terms [domain "real"]]
    (setv self.variable variable)
    (setv self.terms terms)
    (setv self.domain domain))

  (defn __eq__ [self other]
    (and (isinstance other SymPolynomial)
         (variable= self.variable other.variable)
         (= self.terms other.terms)
         (= self.domain other.domain)))

  (defn __repr__ [self]
    f"SymPolynomial(variable={self.variable}, terms={self.terms}, domain={self.domain})"))

(defn polynomial-p [obj]
  "Return True if OBJ is a SymPolynomial."
  (isinstance obj SymPolynomial))

(defn %sort-and-combine-terms [terms]
  "Internal: combine like-exponent terms, drop zero coefficients, sort descending."
  (setv table {})
  (for [term terms]
    (setv e term.exponent)
    (setv (get table e) (+ (.get table e 0) term.coefficient)))
  (setv result [])
  (for [[exp coeff] (.items table)]
    (when (not (math.isclose coeff 0.0 :abs-tol 1e-12))
      (.append result #(exp coeff))))
  (setv sorted-pairs (sorted result :key (fn [x] (get x 0)) :reverse True))
  sorted-pairs)

(defn make-polynomial [variable terms [domain "real"]]
  "Create a polynomial in variable from a list of terms."
  (assert (variable-p variable))
  (for [term terms]
    (assert (term-p term))
    (assert (variable= variable term.variable)
            f"Term variable {term.variable.name} does not match polynomial variable {variable.name}"))
  (assert (in domain ["real" "complex"]))
  (setv pairs (%sort-and-combine-terms terms))
  (setv new-terms (lfor #(exp coeff) pairs
                        (SymTerm coeff variable exp)))
  (SymPolynomial variable new-terms domain))

(defn polynomial-variable [obj]
  obj.variable)

(defn polynomial-terms [obj]
  obj.terms)

(defn polynomial-domain [obj]
  obj.domain)

(defn polynomial-normalize [poly]
  "Return POLY with terms re-sorted and zero-coefficient terms removed."
  (make-polynomial poly.variable poly.terms :domain poly.domain))

(defn polynomial-degree [poly]
  "Return the degree (highest exponent) of POLY. -1 for zero polynomial."
  (if (not poly.terms)
      -1
      (. (get poly.terms 0) exponent)))

(defn polynomial-leading-term [poly]
  "Return the leading term of POLY, or None."
  (if (not poly.terms)
      None
      (get poly.terms 0)))

(defn polynomial-add [p q]
  "Return P + Q as a new polynomial."
  (assert (variable= p.variable q.variable)
          f"Cannot add polynomials in different variables: {p.variable.name} and {q.variable.name}")
  (make-polynomial p.variable
                   (+ p.terms q.terms)
                   :domain p.domain))

(defn polynomial-negate [poly]
  "Return -POLY as a new polynomial."
  (make-polynomial poly.variable
                   (lfor term poly.terms (term-negate term))
                   :domain poly.domain))

(defn polynomial-subtract [p q]
  "Return P - Q as a new polynomial."
  (polynomial-add p (polynomial-negate q)))

(defn polynomial-scale [poly scalar]
  "Return SCALAR * POLY as a new polynomial."
  (make-polynomial poly.variable
                   (lfor term poly.terms (term-scale term scalar))
                   :domain poly.domain))

(defn polynomial-evaluate [poly value]
  "Evaluate POLY at value."
  (sum (lfor term poly.terms
             (* term.coefficient (** value term.exponent)))))

(defn polynomial->string [poly]
  "Return a human-readable string representation of POLY."
  (if (not poly.terms)
      "0"
      (.join " + " (lfor term poly.terms (term->string term)))))

(defn zero-polynomial [variable]
  "Return the zero polynomial in variable."
  (SymPolynomial variable [] "real"))

(defn constant-polynomial [variable value]
  "Return the constant polynomial value in variable."
  (make-polynomial variable [(make-term value variable 0)]))

(defn identity-polynomial [variable]
  "Return the polynomial x in variable."
  (make-polynomial variable [(make-term 1 variable 1)]))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 5.  SYM-INTEGRAL
;;;; ─────────────────────────────────────────────────────────────────────────

(defclass SymIntegral []
  "Represents a definite or indefinite integral."
  (defn __init__ [self integrand variable [lower None] [upper None]]
    (setv self.integrand integrand)
    (setv self.variable variable)
    (setv self.lower lower)
    (setv self.upper upper))

  (defn __repr__ [self]
    f"SymIntegral(integrand={self.integrand}, variable={self.variable}, lower={self.lower}, upper={self.upper})")

  (defn definite-p [self]
    (not (is self.lower None))))

(defn make-integral [integrand variable [lower None] [upper None]]
  "Create a symbolic integral."
  (assert (variable-p variable))
  (assert (or (and (is lower None) (is upper None))
              (and (not (is lower None)) (not (is upper None))))
          "Either both lower and upper must be provided, or neither.")
  (SymIntegral integrand variable lower upper))

(defn integral-p [obj]
  "Return True if OBJ is a SymIntegral."
  (isinstance obj SymIntegral))

(defn integral-integrand [obj]
  obj.integrand)

(defn integral-variable [obj]
  obj.variable)

(defn integral-lower [obj]
  obj.lower)

(defn integral-upper [obj]
  obj.upper)

(defn integral-definite-p [integral]
  (.definite-p integral))

(defn %bound->string [bound]
  "Internal: render a bound as a string."
  (cond
    (is bound None) ""
    (constant-p bound) (str (constant-name bound))
    True (str bound)))

(defn integral->string [integral]
  "Return a human-readable string for integral."
  (setv var (str (variable-name integral.variable)))
  (setv body
        (if (polynomial-p integral.integrand)
            (polynomial->string integral.integrand)
            (str integral.integrand)))
  (setv bounds
        (if (integral-definite-p integral)
            f"[{(%bound->string integral.lower)},{(%bound->string integral.upper)}]"
            ""))
  f"∫{bounds}({body}) d{var}")


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 6.  Quick smoke-test
;;;; ─────────────────────────────────────────────────────────────────────────

(defn run-smoke-test []
  "Run a quick sanity check printing results."
  (setv x (make-variable "x"))
  (setv pi-const (make-constant "pi" "pi"))

  ;; Build 3x² - x + 5
  (setv p (make-polynomial x
                           [(make-term 3 x 2)
                            (make-term -1 x 1)
                            (make-term 5 x 0)]))
  ;; Build x + 2
  (setv q (make-polynomial x
                           [(make-term 1 x 1)
                            (make-term 2 x 0)]))

  (setv sum (polynomial-add p q))
  (setv diff (polynomial-subtract p q))
  (setv scaled (polynomial-scale p 2))
  (setv indef (make-integral p x))
  (setv def (make-integral p x :lower 0 :upper 1))
  (setv pi-int (make-integral p x :lower 0 :upper pi-const))

  (print "\n=== Symbolic Math Data Layer Smoke Test ===\n")
  (print f"p         : {(polynomial->string p)}")
  (print f"q         : {(polynomial->string q)}")
  (print f"p + q     : {(polynomial->string sum)}")
  (print f"p - q     : {(polynomial->string diff)}")
  (print f"2 * p     : {(polynomial->string scaled)}")
  (print f"degree(p) : {(polynomial-degree p)}")
  (print f"p(0)      : {(polynomial-evaluate p 0)}")
  (print f"p(1)      : {(polynomial-evaluate p 1)}")
  (print f"p(2)      : {(polynomial-evaluate p 2)}")
  (print f"indef     : {(integral->string indef)}")
  (print f"def       : {(integral->string def)}")
  (print f"pi-int    : {(integral->string pi-int)}")
  (print "\n===========================================\n"))

(when (= __name__ "__main__")
  (run-smoke-test))
