# Symbolic Mathematics

Dear reader, this chapter is a love letter to Lisp's roots in symbolic computation. My interest in symbolic math software started in the 1980s when I had the Reduce symbolic math package running on my Xerox 1108 Lisp Machine. We build a small but complete symbolic mathematics library in Hy covering polynomial data structures, symbolic differentiation, and symbolic integration. I ported this example from the Common Lisp version in my book *Loving Common Lisp, The Savvy Programmer's Secret Weapon*.

The beauty of this example is that Hy's Lisp syntax makes the mathematical transformations read almost like the textbook rules they implement. The power rule for differentiation, for instance, is a single `if` expression. The fundamental theorem of calculus is three lines. This is exactly the kind of problem where Lisp shines.

## Project Overview

The library is split into three modules that build on each other:

```
symbolic-math/
├── data.hy            ← Core classes: variables, constants, terms, polynomials, integrals
├── differentiation.hy ← Symbolic differentiation (power rule, sum rule)
├── integration.hy     ← Symbolic integration (reverse power rule, FTC)
├── main.hy            ← Combined smoke test runner
└── pyproject.toml     ← Dependencies (just hy)
```

To run the complete test suite:

```bash
uv sync
uv run hy main.hy
```

## The Data Layer: data.hy

The foundation of any symbolic math system is its data representation. We need types for variables, constants, terms (monomials), polynomials, and integrals. In Common Lisp these were `defstruct` definitions; in Hy we use `defclass`.

### Symbolic Variables

A variable has a name and a domain (real, complex, or integer):

```hy
(defclass SymVariable []
  "A symbolic variable such as x, y, or t."
  (defn __init__ [self name [domain "real"]]
    (setv self.name name)
    (setv self.domain domain))

  (defn __eq__ [self other]
    (and (isinstance other SymVariable)
         (= self.name other.name)
         (= self.domain other.domain))))
```

We also define a constructor function and a predicate following Common Lisp naming conventions:

```hy
(defn make-variable [name [domain "real"]]
  "Create a symbolic variable with name and optional domain."
  (assert (in domain ["real" "complex" "integer"]))
  (SymVariable name domain))

(defn variable-p [obj]
  "Return True if OBJ is a SymVariable."
  (isinstance obj SymVariable))
```

The `-p` suffix on `variable-p` is a Lisp tradition for predicate functions (from "predicate"). And `make-variable` wraps the constructor with validation, just as the Common Lisp version used `check-type` assertions.

### Symbolic Constants

Constants like π and *e* can be stored symbolically and resolved to numeric values when needed:

```hy
(defclass SymConstant []
  "A named mathematical constant."
  (defn __init__ [self name value]
    (setv self.name name)
    (setv self.value value))

  (defn numeric-value [self]
    (cond
      (= self.value "pi") math.pi
      (= self.value "e") (math.exp 1.0)
      True self.value)))

(defn make-constant [name value]
  (SymConstant name value))
```

This lets us write integral bounds like `(make-constant "pi" "pi")` and defer numeric evaluation until the moment we actually need a floating-point result.

### Terms (Monomials)

A term represents a single monomial: *coefficient × variable^exponent*. For example, 3x² is the term with coefficient 3, variable x, and exponent 2:

```hy
(defclass SymTerm []
  "A single monomial: COEFFICIENT * VARIABLE ^ EXPONENT."
  (defn __init__ [self coefficient variable exponent]
    (setv self.coefficient coefficient)
    (setv self.variable variable)
    (setv self.exponent exponent))

  (defn negate [self]
    (SymTerm (- self.coefficient) self.variable self.exponent))

  (defn scale [self scalar]
    (SymTerm (* scalar self.coefficient) self.variable self.exponent))

  (defn to-string [self]
    (cond
      (= self.exponent 0) (str self.coefficient)
      (= self.exponent 1) f"{self.coefficient}{self.variable.name}"
      True f"{self.coefficient}{self.variable.name}^{self.exponent}")))
```

Note how the `to-string` method handles three cases: constant terms (exponent 0), linear terms (exponent 1, no caret), and general terms. This mirrors exactly the Common Lisp `term->string` function.

### Polynomials

A polynomial is a list of terms in one variable, kept sorted in descending exponent order. The key design decision, following the Common Lisp original, is that the `make-polynomial` constructor automatically combines like terms and drops zero-coefficient terms:

```hy
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
  (sorted result :key (fn [x] (get x 0)) :reverse True))
```

This function uses a dictionary as an accumulator (keyed by exponent) to merge coefficients. The `%` prefix is a Lisp convention for internal/private helper functions.

With the normalizer in place, polynomial arithmetic becomes straightforward:

```hy
(defn polynomial-add [p q]
  "Return P + Q as a new polynomial."
  (make-polynomial p.variable (+ p.terms q.terms) :domain p.domain))

(defn polynomial-negate [poly]
  (make-polynomial poly.variable
                   (lfor term poly.terms (term-negate term))
                   :domain poly.domain))

(defn polynomial-subtract [p q]
  (polynomial-add p (polynomial-negate q)))

(defn polynomial-scale [poly scalar]
  (make-polynomial poly.variable
                   (lfor term poly.terms (term-scale term scalar))
                   :domain poly.domain))
```

Addition simply concatenates the term lists and lets the normalizer handle merging. Subtraction negates then adds. This immutable, value oriented approach means we never mutate a polynomial and every operation returns a fresh one.

Evaluation substitutes a numeric value for the variable:

```hy
(defn polynomial-evaluate [poly value]
  "Evaluate POLY at value."
  (sum (lfor term poly.terms
             (* term.coefficient (** value term.exponent)))))
```

### Integrals

The integral structure wraps a polynomial with optional bounds, enabling both indefinite and definite integral representations:

```hy
(defn make-integral [integrand variable [lower None] [upper None]]
  "Create a symbolic integral."
  (assert (or (and (is lower None) (is upper None))
              (and (not (is lower None)) (not (is upper None))))
          "Either both lower and upper must be provided, or neither.")
  (SymIntegral integrand variable lower upper))
```

The string representation uses Unicode for a clean mathematical display:

```hy
(defn integral->string [integral]
  (setv var (str (variable-name integral.variable)))
  (setv body (polynomial->string integral.integrand))
  (setv bounds
        (if (integral-definite-p integral)
            f"[{(%bound->string integral.lower)},{(%bound->string integral.upper)}]"
            ""))
  f"∫{bounds}({body}) d{var}")
```

### Data Layer Smoke Test

Running `uv run hy data.hy` exercises the data layer:

```
=== Symbolic Math Data Layer Smoke Test ===

p         : 3x^2 + -1x + 5
q         : 1x + 2
p + q     : 3x^2 + 7
p - q     : 3x^2 + -2x + 3
2 * p     : 6x^2 + -2x + 10
degree(p) : 2
p(0)      : 5
p(1)      : 7
p(2)      : 15
indef     : ∫(3x^2 + -1x + 5) dx
def       : ∫[0,1](3x^2 + -1x + 5) dx
pi-int    : ∫[0,pi](3x^2 + -1x + 5) dx

===========================================
```

Notice how `p + q` correctly combined the x terms: -1x from p and 1x from q cancel out, leaving `3x^2 + 7`.


## Symbolic Differentiation: differentiation.hy

Calculus students learn three rules that suffice for differentiating any polynomial:

1. **Power rule:** d/dx(c · x^n) = n · c · x^(n-1)
2. **Sum rule:** d/dx(p + q) = p' + q'
3. **Constant rule:** d/dx(c) = 0

In Hy, the power rule is a single function:

```hy
(defn differentiate-term [term]
  "Apply the power rule to a single monomial TERM."
  (setv c term.coefficient)
  (setv v term.variable)
  (setv n term.exponent)
  (if (= n 0)
      None
      (make-term (* n c) v (- n 1))))
```

When the exponent is zero (a constant term), the derivative is zero—we return `None` and filter it out at the polynomial level. Otherwise, we multiply the coefficient by the exponent and reduce the exponent by one. That's the entire power rule.

Polynomial differentiation maps this over the terms and lets the constructor normalize:

```hy
(defn differentiate [poly]
  "Differentiate polynomial POLY with respect to its variable."
  (setv diff-terms [])
  (for [term poly.terms]
    (setv dt (differentiate-term term))
    (when (not (is dt None))
      (.append diff-terms dt)))
  (if (not diff-terms)
      (zero-polynomial poly.variable)
      (make-polynomial poly.variable diff-terms :domain poly.domain)))
```

Higher-order derivatives use natural recursion:

```hy
(defn differentiate-n [poly n]
  "Return the N-th derivative of polynomial POLY."
  (if (= n 0)
      poly
      (differentiate-n (differentiate poly) (- n 1))))
```

We also provide convenience functions for numerical evaluation:

```hy
(defn gradient-at [poly value]
  "Return the numerical value of the derivative of POLY at VALUE."
  (polynomial-evaluate (differentiate poly) value))

(defn critical-point-p [poly value [tolerance 1e-9]]
  "Return True if VALUE is (numerically) a critical point of POLY."
  (< (abs (gradient-at poly value)) tolerance))
```

### Differentiation Smoke Test

Running `uv run hy differentiation.hy`:

```
=== Differentiation Smoke Test ===

p            : 3x^2 + -1x + 5
p'           : 6x + -1
p''          : 6
p'''         : 0

q            : 1x^4 + -2x^3 + 1x
q'           : 4x^3 + -6x^2 + 1
q'' (via n=2): 12x^2 + -12x

gradient-at(p, 0)      : -1  (expected -1)
gradient-at(p, 1)      : 5  (expected 5)
critical-point-p(p,1/6): True  (expected True)
critical-point-p(p,0)  : False  (expected False)

==================================
```

The critical point test confirms that p'(1/6) = 0, since p'(x) = 6x - 1 and 6(1/6) - 1 = 0.


## Symbolic Integration: integration.hy

Integration is the reverse of differentiation. For polynomials, the key rule is the **reverse power rule**:

∫ c · x^n dx = (c / (n+1)) · x^(n+1) + C

Notice the division by (n+1). In Common Lisp, dividing two integers produces a rational number automatically. Python's integers don't do this—`3 / 2` gives `1.5`, not `3/2`. We use Python's `fractions.Fraction` class to preserve exact rational coefficients:

```hy
(import fractions [Fraction])

(defn integrate-term [term]
  "Apply the reverse power rule to a single monomial TERM."
  (setv c term.coefficient)
  (setv v term.variable)
  (setv n term.exponent)
  (setv new-exp (+ n 1))
  (setv new-coef (if (isinstance c #(int Fraction))
                     (Fraction c new-exp)
                     (/ c new-exp)))
  (make-term new-coef v new-exp))
```

When the coefficient is an integer or already a `Fraction`, we produce a `Fraction` result—keeping the representation exact. This means integrating `3x²` gives `1x³` (since `Fraction(3, 3)` simplifies to 1), and integrating `-1x` gives `-1/2x²` (since `Fraction(-1, 2)` stays as-is).

The polynomial antiderivative maps the term integrator:

```hy
(defn integrate [poly]
  "Return the antiderivative of polynomial POLY (without +C)."
  (setv new-terms (lfor term poly.terms (integrate-term term)))
  (if (not new-terms)
      (zero-polynomial poly.variable)
      (make-polynomial poly.variable new-terms :domain poly.domain)))
```

### The Fundamental Theorem of Calculus

For definite integrals, we apply the fundamental theorem: ∫[a,b] f(x) dx = F(b) - F(a), where F is the antiderivative.

```hy
(defn evaluate-definite [poly lower upper]
  "Evaluate the definite integral ∫[lower,upper] POLY dx numerically."
  (setv F (integrate poly))
  (setv a (%resolve-bound lower))
  (setv b (%resolve-bound upper))
  (- (polynomial-evaluate F b)
     (polynomial-evaluate F a)))
```

The `%resolve-bound` helper converts bounds—which may be plain numbers or symbolic constants like π—to floating-point values for evaluation.

### Integration Smoke Test

Running `uv run hy integration.hy`:

```
=== Integration Smoke Test ===

p              : 3x^2 + -1x + 5
∫p dx          : 1x^3 + -1/2x^2 + 5x
∫∫p dx dx      : 1/4x^4 + -1/6x^3 + 5/2x^2

q              : 6x + 2
∫q dx          : 3x^2 + 2x

∫₀¹  p dx      : 5.5  (expected 5.5)
∫₀¹  q dx      : 5.0  (expected 5.0)
∫₀^π p dx      : 41.7794377477041

indef shell    : ∫(3x^2 + -1x + 5) dx
def [0,1]      : ∫[0,1](3x^2 + -1x + 5) dx
def [0,pi]     : ∫[0,pi](3x^2 + -1x + 5) dx

==============================
```

Notice the exact rational coefficients: `-1/2`, `1/4`, `-1/6`, `5/2`. These come from `Fraction` arithmetic and match what Common Lisp produces natively. When we evaluate the definite integral ∫₀¹ p dx, the antiderivative F(x) = x³ - (1/2)x² + 5x is evaluated at x=1 and x=0, giving F(1) - F(0) = 1 - 0.5 + 5 - 0 = 5.5.


## Design Notes: From Common Lisp to Hy

Porting this library revealed several interesting contrasts between Common Lisp and Hy/Python:

**Structs vs. Classes.** Common Lisp's `defstruct` generates constructors, accessors, and predicates automatically. In Hy we define classes with explicit `__init__` and `__eq__` methods, plus standalone accessor functions like `term-coefficient` for API compatibility with the original.

**Exact Rationals.** Common Lisp keeps rationals exact by default—`(/ 3 2)` returns `3/2`, not `1.5`. Python's integers don't do this, so we import `fractions.Fraction` to preserve exact coefficients during integration. This is the one area where Common Lisp is genuinely more convenient for symbolic math.

**Immutability by Convention.** Both versions follow the same discipline: every arithmetic operation returns a new polynomial; nothing is ever mutated in place. In Common Lisp this is natural with `defstruct`; in Python/Hy we simply choose not to modify attributes after construction.

**Naming Conventions.** We kept the Lisp-style names—`make-polynomial`, `variable-p`, `polynomial->string`—which Hy auto-translates to Python's `make_polynomial`, `variable_p`, `polynomial_to_string`. The `-p` suffix for predicates and `->` for conversions are idiomatic Lisp that read naturally in Hy.


## Running the Full Test Suite

The file **main.hy** ties everything together:

```hy
(import data)
(import differentiation)
(import integration)

(defn main []
  (print "=========================================================")
  (print "=== RUNNING ALL SYMBOLIC MATH SMOKE TESTS IN HY ===")
  (print "=========================================================")
  (data.run-smoke-test)
  (differentiation.run-smoke-test)
  (integration.run-smoke-test))

(when (= __name__ "__main__")
  (main))
```

Run it with:

```bash
uv run hy main.hy
```

## Summary

We built a symbolic mathematics library from scratch in Hy, porting the data structures and algorithms from a Common Lisp implementation. The library demonstrates:

- **Lisp-style data modeling** with classes and constructor/predicate functions
- **Immutable arithmetic** where every operation returns fresh structures
- **Exact rational arithmetic** using Python's `fractions.Fraction`
- **Recursive algorithms** for higher-order derivatives and iterated integrals
- **The fundamental theorem of calculus** implemented in three lines of code

This is the kind of problem that Lisp was born to solve. The symbolic transformations—differentiating a term, integrating a polynomial, evaluating a definite integral—read almost identically to the mathematical rules they implement. Hy gives us this expressiveness while staying inside Python's ecosystem.

If you enjoy symbolic math software, you can try extending this example code:

1. **Polynomial multiplication** — Implement `polynomial-multiply` that distributes each term of one polynomial across the terms of another, then normalizes.
2. **Pretty printing** — Modify `term->string` to suppress the coefficient when it is 1 or -1 (printing `x^2` instead of `1x^2` and `-x` instead of `-1x`).
3. **Chain rule** — Extend differentiation to handle compositions like `(3x + 1)^4` by representing composite expressions as a new data type.
4. **Numeric integration** — Implement Simpson's rule as an alternative to the exact antiderivative approach, and compare accuracy for different step sizes.

## Optional Practice Problems

To solidify your understanding of symbolic mathematics in Hy, try implementing the following extensions to the codebase:

### Problem 1: Sleek Polynomial Formatting
Currently, polynomials print in a raw format (e.g., `3x^2 + -1x + 5` or `1x^3 + -1/2x^2 + 5x`).
Modify the `to-string` method of the [SymTerm](file:///Users/markwatson/GITHUB/hy-lisp-python-book/source_code_for_examples/symbolic-math/data.hy#L104-L130) class (or [term->string](file:///Users/markwatson/GITHUB/hy-lisp-python-book/source_code_for_examples/symbolic-math/data.hy#L161-L162) function) and the [polynomial->string](file:///Users/markwatson/GITHUB/hy-lisp-python-book/source_code_for_examples/symbolic-math/data.hy#L269-L273) function in [data.hy](file:///Users/markwatson/GITHUB/hy-lisp-python-book/source_code_for_examples/symbolic-math/data.hy) to:
- Suppress printing coefficients of `1` or `-1` (e.g., print `x^2` instead of `1x^2`, and `-x` instead of `-1x`), unless the exponent is `0`.
- Format subtraction cleanly (e.g., print `3x^2 - x + 5` instead of `3x^2 + -1x + 5`).

### Problem 2: Polynomial Multiplication
Implement polynomial multiplication in [data.hy](file:///Users/markwatson/GITHUB/hy-lisp-python-book/source_code_for_examples/symbolic-math/data.hy):
1. Define a helper function `(term-multiply t1 t2)` that multiplies coefficients, asserts they share the same variable (unless one has exponent 0), and adds their exponents.
2. Define a function `(polynomial-multiply p q)` that distributes each term in `p` across each term in `q` using your helper, returning a new normalized polynomial via `make-polynomial`.
3. Add a test case to `run-smoke-test` in [data.hy](file:///Users/markwatson/GITHUB/hy-lisp-python-book/source_code_for_examples/symbolic-math/data.hy) (e.g., multiplying `(x + 2)` by itself to get `x^2 + 4x + 4`).

### Problem 3: Numerical Integration (Trapezoidal Rule)
In [integration.hy](file:///Users/markwatson/GITHUB/hy-lisp-python-book/source_code_for_examples/symbolic-math/integration.hy), definite integration is computed analytically using the Fundamental Theorem of Calculus.
Implement a function `(integrate-trapezoidal poly lower upper [n-steps 100])` that computes the definite integral of `poly` from `lower` to `upper` numerically using the trapezoidal rule:
$$ \int_a^b f(x) dx \approx \frac{h}{2} \left[ f(a) + 2 \sum_{i=1}^{n-1} f(a + ih) + f(b) \right] $$
where $h = (b - a) / n$.
Compare the result with the analytical evaluation from [evaluate-definite](file:///Users/markwatson/GITHUB/hy-lisp-python-book/source_code_for_examples/symbolic-math/integration.hy#L61-L68) for $p = 3x^2 - x + 5$ over $[0, 1]$ and verify that the approximation converges as `n-steps` increases.
