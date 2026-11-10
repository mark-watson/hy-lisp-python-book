# GraphRAG and Knowledge Graph Quality (`kg-rag`)

This project implements a complete knowledge graph quality and GraphRAG pipeline in Hy 1.3.1 using `rdflib` and `pyshacl`. It demonstrates:

1. **Corpus Ingestion and Extraction** (`corpus.hy`, `extract.hy`): Loads six short documents in `data/`, splits them into chunks with stable IDs (`doc1#chunk0`, etc.), and extracts structured triples with a deterministic `FakeExtractor` (plus an optional `OllamaExtractor` that degrades gracefully when Ollama is offline).
2. **PROV-O Triple Provenance and SPARQL Update Rollback** (`kg.hy`): Reifies every extracted assertion as an `rdf:Statement` linked via `prov:wasDerivedFrom` to its source chunk IRI and an `ex:confidence` score. Supports incremental `SPARQL Update` (`INSERT DATA`, `DELETE/INSERT`) with snapshot rollback when validation fails.
3. **Entity Resolution** (`resolve.hy`): Groups entities by blocking key (`Class:first_char`), computes `difflib.SequenceMatcher` string similarity, emits `owl:sameAs` and canonicalizes URIs for high-similarity pairs (`>= 0.88`), and places ambiguous pairs (`0.72` to `0.88`) into a human review queue.
4. **RDFS Inference and SHACL Validation** (`quality.hy`): Materializes RDFS class and property hierarchies using SPARQL `CONSTRUCT` rules and validates the graph against `data/shapes.ttl` with `pyshacl`, demonstrating both a passing graph and a failing sample report.
5. **Hybrid GraphRAG Retrieval and Evaluation** (`retrieve.hy`, `graphrag.hy`, `evaluate.hy`): Compares a keyword TF-IDF cosine chunk baseline against 1-to-2 hop graph neighborhood expansion, token-budget context assembly, connected-component community summaries for global search, and benchmark evaluation of retrieval recall, citation accuracy, and groundedness.

## Project Structure

```text
graphrag_kg_quality/
├── data/
│   ├── doc1_hy_ecosystem.txt
│   ├── doc2_nsk_engine.txt
│   ├── doc3_kgcreator.txt
│   ├── doc4_kgn_navigator.txt
│   ├── doc5_zvec_rag.txt
│   ├── doc6_shacl_prov.txt
│   └── shapes.ttl          # SHACL NodeShapes for projects, people, and provenance
├── corpus.hy               # Document parser and fixed-window sentence chunker
├── extract.hy              # Deterministic FakeExtractor and optional OllamaExtractor
├── kg.hy                   # RDF builder, PROV-O reification, transactional SPARQL Update
├── quality.hy              # RDFS CONSTRUCT inference and pyshacl validation
├── resolve.hy              # Blocking, string similarity, owl:sameAs canonicalization
├── retrieve.hy             # Keyword baseline, 1-2 hop GraphRAG, community summaries
├── graphrag.hy             # End-to-end GraphRAGPipeline and grounded answer synthesis
├── evaluate.hy             # Benchmark suite for recall, citation accuracy, groundedness
├── demo.hy                 # Guided walkthrough script
├── test_graphrag.hy        # Offline pytest test suite (10 tests)
├── conftest.py             # Pytest collector for .hy test modules
└── pyproject.toml          # Project metadata and dependencies
```

## Prerequisites

- Python 3.12+
- [`uv`](https://docs.astral.sh/uv/) package manager
- No external database, API key, or running LLM server is required.

## Running the Demo and Tests

Install dependencies, run the guided walkthrough, and execute the test suite:

```bash
uv sync
uv run hy demo.hy
uv run pytest -q
```
