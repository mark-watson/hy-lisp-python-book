# Knowledge Graph Visualization with GraphViz

**Note:** This example is **not yet covered in the book** but is useful for learning to use GraphViz from Hy programs.

This script reads RDF-style triple data from `test.triples` (a subset from the [Salesforce MultiHopKG](https://github.com/salesforce/MultiHopKG) project containing UMLS medical-ontology relationships) and renders it as a graph using [GraphViz](https://graphviz.org/), producing a PDF visualization.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager
- [GraphViz](https://graphviz.org/) installed on your system (`brew install graphviz` on macOS)

## Running the Example

```bash
uv sync
uv run hy UMLS_graph.hy
```

This generates `umls_graph.pdf` in the current directory.
