;;;; integration.hy — Symbolic integration of polynomials
;;;;

(import fractions [Fraction])
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
;;;; 1.  Term-level integration  (reverse power rule)
;;;; ─────────────────────────────────────────────────────────────────────────

(defn integrate-term [term]
  "Apply the reverse power rule to a single monomial TERM."
  (assert (term-p term))
  (setv c term.coefficient)
  (setv v term.variable)
  (setv n term.exponent)
  (setv new-exp (+ n 1))
  (setv new-coef (if (isinstance c #(int Fraction))
                     (Fraction c new-exp)
                     (/ c new-exp)))
  (make-term new-coef v new-exp))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 2.  Polynomial antiderivative  (sum + reverse power)
;;;; ─────────────────────────────────────────────────────────────────────────

(defn integrate [poly]
  "Return the antiderivative of polynomial POLY (without +C)."
  (assert (polynomial-p poly))
  (setv new-terms (lfor term poly.terms (integrate-term term)))
  (if (not new-terms)
      (zero-polynomial poly.variable)
      (make-polynomial poly.variable new-terms :domain poly.domain)))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 3.  Definite integral evaluation  (Fundamental Theorem of Calculus)
;;;; ─────────────────────────────────────────────────────────────────────────

(defn %resolve-bound [bound]
  "Internal: convert a bound (number or SymConstant) to a float."
  (cond
    (is bound None) (raise (ValueError "Bound is None"))
    (isinstance bound #(int float Fraction)) (float bound)
    (constant-p bound) (float (constant-numeric-value bound))
    True (raise (ValueError f"Unrecognised bound type: {bound}"))))

(defn evaluate-definite [poly lower upper]
  "Evaluate the definite integral ∫[lower,upper] POLY dx numerically."
  (assert (polynomial-p poly))
  (setv F (integrate poly))
  (setv a (%resolve-bound lower))
  (setv b (%resolve-bound upper))
  (- (polynomial-evaluate F b)
     (polynomial-evaluate F a)))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 4.  Higher-order (iterated) antiderivatives
;;;; ─────────────────────────────────────────────────────────────────────────

(defn integrate-n [poly n]
  "Return the N-th iterated antiderivative of POLY."
  (assert (polynomial-p poly))
  (assert (and (isinstance n int) (>= n 0)))
  (if (= n 0)
      poly
      (integrate-n (integrate poly) (- n 1))))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 5.  sym-integral shell constructors
;;;; ─────────────────────────────────────────────────────────────────────────

(defn make-indefinite-integral [poly]
  "Create a SymIntegral wrapping the antiderivative of POLY (indefinite form)."
  (assert (polynomial-p poly))
  (make-integral poly poly.variable))

(defn make-definite-integral [poly lower upper]
  "Create a SymIntegral wrapping POLY with explicit bounds lower and upper."
  (assert (polynomial-p poly))
  (make-integral poly poly.variable :lower lower :upper upper))


;;;; ─────────────────────────────────────────────────────────────────────────
;;;; 6.  Smoke test
;;;; ─────────────────────────────────────────────────────────────────────────

(defn run-smoke-test []
  "Run a quick sanity check on the integration functions."
  (setv x (make-variable "x"))
  (setv pi-c (make-constant "pi" "pi"))

  ;; p = 3x² - x + 5
  (setv p (make-polynomial x
                           [(make-term 3 x 2)
                            (make-term -1 x 1)
                            (make-term 5 x 0)]))
  ;; ∫p dx = x³ - (1/2)x² + 5x
  (setv ip (integrate p))
  ;; ∫²p dx = (1/4)x⁴ - (1/6)x³ + (5/2)x²
  (setv iip (integrate-n p 2))

  ;; q = 6x + 2
  (setv q (make-polynomial x
                           [(make-term 6 x 1)
                            (make-term 2 x 0)]))
  ;; ∫q dx = 3x² + 2x
  (setv iq (integrate q))

  ;; Definite: ∫₀¹ p dx  = 5.5
  (setv def-01 (evaluate-definite p 0 1))
  ;; Definite: ∫₀¹ q dx = 5
  (setv def-q-01 (evaluate-definite q 0 1))
  ;; Definite: ∫₀^π p dx
  (setv def-pi (evaluate-definite p 0 pi-c))

  ;; sym-integral shells
  (setv indef-shell (make-indefinite-integral p))
  (setv def-shell (make-definite-integral p 0 1))
  (setv pi-shell (make-definite-integral p 0 pi-c))

  (print "\n=== Integration Smoke Test ===\n")
  (print f"p              : {(polynomial->string p)}")
  (print f"∫p dx          : {(polynomial->string ip)}")
  (print f"∫∫p dx dx      : {(polynomial->string iip)}")
  (print)
  (print f"q              : {(polynomial->string q)}")
  (print f"∫q dx          : {(polynomial->string iq)}")
  (print)
  (print f"∫₀¹  p dx      : {def-01}  (expected 5.5)")
  (print f"∫₀¹  q dx      : {def-q-01}  (expected 5.0)")
  (print f"∫₀^π p dx      : {def-pi}")
  (print)
  (print f"indef shell    : {(integral->string indef-shell)}")
  (print f"def [0,1]      : {(integral->string def-shell)}")
  (print f"def [0,pi]     : {(integral->string pi-shell)}")
  (print "\n==============================\n"))

(when (= __name__ "__main__")
  (run-smoke-test))
