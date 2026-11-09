;; Tests for data.hy, differentiation.hy and integration.hy  --  run with:  uv run pytest

(import math)
(import fractions [Fraction])
(import pytest)
(import data [make-variable make-constant make-term make-polynomial
              polynomial-add polynomial-subtract polynomial-scale
              polynomial-degree polynomial-leading-term polynomial-evaluate
              polynomial->string zero-polynomial constant-polynomial
              identity-polynomial make-integral integral->string
              integral-definite-p])
(import differentiation [differentiate differentiate-n gradient-at
                         critical-point-p])
(import integration [integrate integrate-n evaluate-definite
                     make-definite-integral make-indefinite-integral])


;; ---------- helpers ----------

(setv x (make-variable "x"))

(defn poly [#* coeff-exp-pairs]
  "Build a polynomial in x from (coefficient exponent) pairs."
  (make-polynomial x (lfor [c e] coeff-exp-pairs (make-term c x e))))

(defn p [] (poly [3 2] [-1 1] [5 0]))   ; 3x^2 - x + 5


;; ---------- data layer ----------

(defn test-make-polynomial-combines-and-sorts-terms []
  (setv q (poly [1 0] [2 1] [3 1] [4 2]))
  (assert (= (polynomial->string q) "4x^2 + 5x + 1"))
  (assert (= (polynomial-degree q) 2))
  (assert (= (. (polynomial-leading-term q) coefficient) 4)))

(defn test-make-polynomial-drops-zero-terms []
  (setv q (poly [2 1] [-2 1] [7 0]))
  (assert (= (polynomial->string q) "7")))

(defn test-make-polynomial-rejects-other-variable []
  (with [(pytest.raises AssertionError)]
    (make-polynomial x [(make-term 1 (make-variable "y") 1)])))

(defn test-make-term-rejects-negative-exponent []
  (with [(pytest.raises AssertionError)]
    (make-term 1 x -1)))

(defn test-polynomial-add-subtract-scale []
  (setv q (poly [1 1] [2 0]))                  ; x + 2
  (assert (= (polynomial->string (polynomial-add (p) q)) "3x^2 + 7"))
  (assert (= (polynomial->string (polynomial-subtract (p) q)) "3x^2 + -2x + 3"))
  (assert (= (polynomial->string (polynomial-scale (p) 2)) "6x^2 + -2x + 10")))

(defn test-polynomial-evaluate []
  (assert (= (polynomial-evaluate (p) 0) 5))
  (assert (= (polynomial-evaluate (p) 1) 7))
  (assert (= (polynomial-evaluate (p) 2) 15)))

(defn test-special-polynomials []
  (assert (= (polynomial->string (zero-polynomial x)) "0"))
  (assert (= (polynomial-degree (zero-polynomial x)) -1))
  (assert (= (polynomial->string (constant-polynomial x 4)) "4"))
  (assert (= (polynomial->string (identity-polynomial x)) "1x")))

(defn test-make-constant []
  (assert (= (.numeric-value (make-constant "pi" "pi")) math.pi))
  (with [(pytest.raises AssertionError)]
    (make-constant "bad" "tau")))

(defn test-integral-shells []
  (setv indef (make-integral (p) x))
  (setv def (make-integral (p) x :lower 0 :upper (make-constant "pi" "pi")))
  (assert (not (integral-definite-p indef)))
  (assert (integral-definite-p def))
  (assert (= (integral->string indef) "∫(3x^2 + -1x + 5) dx"))
  (assert (= (integral->string def) "∫[0,pi](3x^2 + -1x + 5) dx"))
  (with [(pytest.raises AssertionError)]
    (make-integral (p) x :lower 0)))


;; ---------- differentiation ----------

(defn test-differentiate []
  (assert (= (polynomial->string (differentiate (p))) "6x + -1"))
  (assert (= (polynomial->string (differentiate-n (p) 2)) "6"))
  (assert (= (polynomial->string (differentiate-n (p) 3)) "0"))
  (assert (= (differentiate-n (p) 0) (p))))

(defn test-differentiate-higher-degree []
  (setv q (poly [1 4] [-2 3] [1 1]))           ; x^4 - 2x^3 + x
  (assert (= (polynomial->string (differentiate q)) "4x^3 + -6x^2 + 1"))
  (assert (= (polynomial->string (differentiate-n q 2)) "12x^2 + -12x")))

(defn test-gradient-and-critical-points []
  (assert (= (gradient-at (p) 0) -1))
  (assert (= (gradient-at (p) 1) 5))
  (assert (critical-point-p (p) (/ 1 6)))
  (assert (not (critical-point-p (p) 0))))


;; ---------- integration ----------

(defn test-integrate-uses-exact-fractions []
  (setv ip (integrate (p)))                    ; x^3 - 1/2 x^2 + 5x
  (assert (= (lfor t ip.terms t.coefficient) [1 (Fraction -1 2) 5]))
  (assert (= (lfor t ip.terms t.exponent) [3 2 1])))

(defn test-integrate-then-differentiate-is-identity []
  (assert (= (differentiate (integrate (p))) (p))))

(defn test-integrate-n []
  (setv iip (integrate-n (p) 2))
  (assert (= (lfor t iip.terms t.coefficient)
             [(Fraction 1 4) (Fraction -1 6) (Fraction 5 2)]))
  (assert (= (integrate-n (p) 0) (p))))

(defn test-evaluate-definite []
  (assert (= (evaluate-definite (p) 0 1) 5.5))
  (assert (= (evaluate-definite (poly [6 1] [2 0]) 0 1) 5.0))
  ;; ∫0^π (3x^2 - x + 5) dx = π^3 - π^2/2 + 5π
  (setv expected (+ (** math.pi 3) (- (/ (** math.pi 2) 2)) (* 5 math.pi)))
  (assert (math.isclose (evaluate-definite (p) 0 (make-constant "pi" "pi"))
                        expected)))

(defn test-evaluate-definite-rejects-missing-bound []
  (with [(pytest.raises ValueError)]
    (evaluate-definite (p) None 1)))

(defn test-integral-constructors []
  (assert (not (integral-definite-p (make-indefinite-integral (p)))))
  (assert (integral-definite-p (make-definite-integral (p) 0 1))))
