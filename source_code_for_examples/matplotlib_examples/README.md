# Matplotlib Plot Examples

**Book Chapter:** [Introduction to the Hy Language](https://leanpub.com/read/hy-lisp-python/leanpub-auto-introduction-to-the-hy-language) — *A Lisp Programmer Living in Python-Land* (free to read online).

These examples show how to use [Matplotlib](https://matplotlib.org/) and [NumPy](https://numpy.org/) from Hy to plot common activation functions used in deep learning:

- **`plot_relu.hy`** — plots the ReLU (Rectified Linear Unit) function.
- **`plot_sigmoid.hy`** — plots the Sigmoid function.

Each script opens an interactive Matplotlib window displaying the graph.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager

## Running the Examples

```bash
uv sync
uv run hy plot_relu.hy
uv run hy plot_sigmoid.hy
```
