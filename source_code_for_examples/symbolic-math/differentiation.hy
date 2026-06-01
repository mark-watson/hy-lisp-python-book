;;;; differentiation.hy — Symbolic differentiation of polynomials
;;;;

(import data [
  SymVariable SymConstant SymTerm SymPolynomial SymIntegral
  make-variable make-constant make-term make-polynomial
  polynomial-normalize polynomial-degree polynomial-leading-term
  polynomial-add polynomial-negate polynomial-subtract polynomial-scale
  polynomial-evaluate polynomial->string zero-polynomial constant-polynomial identity-polynomial
  make-integral integral-p integral-integrand integral-variable
  integral-lower integral-upper integral-definite-p integral->string
  variable-p variable-name variable-domain variable=
  constant-p constant-name constant-value constant-numeric-value
  term-p term-coefficient term-variable term-exponent term= term-negate term-scale term->string
  polynomial-p polynomial-variable polynomial-terms polynomial-domain
])

;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 1.  Term-level differentiation  (power rule)
;;;; ─────────────────────────────────────────────────────────────────────────

(defn differentiate-term [term]
  "Apply the power rule to a single monomial TERM.
  d/dx(c · x^n) = n·c · x^(n-1)   for n ≥ 1
  d/dx(c)       = 0                 for n = 0  (returns None)"
  (assert (term-p term))
  (setv c term.coefficient)
  (setv v term.variable)
  (setv n term.exponent)
  (if (= n 0)
      None
      (make-term (* n c) v (- n 1))))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 2.  Polynomial differentiation  (sum + power)
;;;; ─────────────────────────────────────────────────────────────────────────

(defn differentiate [poly]
  "Differentiate polynomial POLY with respect to its variable."
  (assert (polynomial-p poly))
  (setv diff-terms [])
  (for [term poly.terms]
    (setv dt (differentiate-term term))
    (when (not (is dt None))
      (.append diff-terms dt)))
  (if (not diff-terms)
      (zero-polynomial poly.variable)
      (make-polynomial poly.variable diff-terms :domain poly.domain)))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 3.  Higher-order derivatives
;;;; ─────────────────────────────────────────────────────────────────────────

(defn differentiate-n [poly n]
  "Return the N-th derivative of polynomial POLY."
  (assert (polynomial-p poly))
  (assert (and (isinstance n int) (>= n 0)))
  (if (= n 0)
      poly
      (differentiate-n (differentiate poly) (- n 1))))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 4.  Convenience: numerical gradient & critical-point test
;;;; ─────────────────────────────────────────────────────────────────────────

(defn gradient-at [poly value]
  "Return the numerical value of the derivative of POLY at VALUE."
  (assert (polynomial-p poly))
  (polynomial-evaluate (differentiate poly) value))

(defn critical-point-p [poly value [tolerance 1e-9]]
  "Return True if VALUE is (numerically) a critical point of POLY."
  (< (abs (gradient-at poly value)) tolerance))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 5.  Smoke test
;;;; ─────────────────────────────────────────────────────────────────────────

(defn run-smoke-test []
  "Run a quick sanity check on the differentiation functions."
  (setv x (make-variable "x"))

  ;; p = 3x² - x + 5
  (setv p (make-polynomial x
                           [(make-term 3 x 2)
                            (make-term -1 x 1)
                            (make-term 5 x 0)]))
  ;; p' = 6x - 1
  (setv dp (differentiate p))
  ;; p'' = 6
  (setv ddp (differentiate dp))
  ;; p''' = 0
  (setv dddp (differentiate ddp))

  ;; q = x^4 - 2x^3 + x
  (setv q (make-polynomial x
                           [(make-term 1 x 4)
                            (make-term -2 x 3)
                            (make-term 1 x 1)]))
  ;; q' = 4x^3 - 6x^2 + 1
  (setv dq (differentiate q))
  ;; q'' = 12x^2 - 12x
  (setv ddq (differentiate-n q 2))

  ;; Critical point of p: p'(x)=0 → 6x-1=0 → x=1/6
  (setv cp (/ 1 6))

  (print "\n=== Differentiation Smoke Test ===\n")
  (print f"p            : {(polynomial->string p)}")
  (print f"p'           : {(polynomial->string dp)}")
  (print f"p''          : {(polynomial->string ddp)}")
  (print f"p'''         : {(polynomial->string dddp)}")
  (print)
  (print f"q            : {(polynomial->string q)}")
  (print f"q'           : {(polynomial->string dq)}")
  (print f"q'' (via n=2): {(polynomial->string ddq)}")
  (print)
  (print f"gradient-at(p, 0)      : {(gradient-at p 0)}  (expected -1)")
  (print f"gradient-at(p, 1)      : {(gradient-at p 1)}  (expected 5)")
  (print f"critical-point-p(p,1/6): {(critical-point-p p cp)}  (expected True)")
  (print f"critical-point-p(p,0)  : {(critical-point-p p 0)}  (expected False)")
  (print "\n==================================\n"))

(when (= __name__ "__main__")
  (run-smoke-test))
