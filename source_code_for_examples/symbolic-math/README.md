# Symbolic Math in Hy

**Book Chapter:** [Symbolic Mathematics in Common Lisp](https://leanpub.com/read/lovinglisp/symbolic-mathematics-in-common-lisp) — *Loving Common Lisp* (source of implementation logic).

This directory contains a port of the Common Lisp symbolic mathematics library from *Loving Common Lisp* to the **Hy** programming language.

## Project Structure

```
symbolic-math/
├── data.hy            ← Core classes (SymVariable, SymConstant, SymTerm, etc.)
├── differentiation.hy ← Symbolic differentiation (power rule)
├── integration.hy     ← Symbolic integration (reverse power rule & FTC)
├── main.hy            ← Combined smoke test runner
├── pyproject.toml     ← Dependency configuration (uv)
└── README.md          ← This file
```

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager

## Running the Examples

You can run individual smoke tests for each module or the combined main entrypoint:

```bash
# Run core data layer tests
uv run hy data.hy

# Run differentiation tests
uv run hy differentiation.hy

# Run integration tests
uv run hy integration.hy

# Run the complete test suite
uv run hy main.hy
```
