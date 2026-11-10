# GraphRAG and Knowledge Graph Quality

Earlier chapters in this book built a substantial semantic technology stack. In the **rdf-sparql** chapter, I implemented an in-memory RDF datastore and SPARQL pattern matcher. In **kgcreator**, I extracted RDF triples from plain text using spaCy and `schema.org`. In **kgn**, I queried public SPARQL endpoints to find multi-hop relationships. In **NSK**, I combined a Datalog-style triplestore and unification engine with a local Ollama neural fallback. And in **zvec_RAG**, I indexed text chunks into a local vector store for retrieval-augmented generation (RAG).

Those chapters left two practical questions open:

1. **How do you know a generated knowledge graph is valid and consistent?** Automated extractors produce duplicate entity names, missing properties, and bad confidence scores. Without validation, entity resolution, and provenance tracking, errors accumulate in the store.
2. **How do you combine structured RDF graphs with unstructured text chunks during RAG?** Vector-only and chunk-only retrieval work well when one text passage holds the whole answer. They fail when a question requires connecting facts across documents or resolving aliases.

This chapter solves both problems by building **kg-rag**, an end-to-end knowledge graph quality and GraphRAG pipeline in Hy. The code for this chapter is in the directory **source_code_for_examples/graphrag_kg_quality**.

## What You Will Build

The `kg-rag` project processes a bundled set of six short documents describing the software projects in this book (`KGCreator`, `KGN`, `NSK`, `zvec_RAG`, and `kg-rag`). It extracts entities and triples, records chunk-level provenance using the W3C PROV-O vocabulary, merges duplicate entities with `owl:sameAs`, infers implicit triples with RDFS rules, validates the graph with SHACL shapes (`pyshacl`), supports transactional `SPARQL Update` with snapshot rollback, and answers questions with both local 2-hop neighborhood expansion and global community summaries.

```text
+-------------------+     +-----------------------+     +------------------------+
|  Bundled Corpus   | --> |   Extractor Layer     | --> | RDF Graph + Provenance |
|  data/doc1..6.txt |     | FakeExtractor / Ollama|     | reified rdf:Statement  |
+-------------------+     +-----------------------+     | prov:wasDerivedFrom    |
                                                        +------------------------+
                                                                    |
        +-----------------------------------------------------------+
        v
+------------------------+     +------------------------+     +------------------+
|   Entity Resolution    | --> |    RDFS Inference      | --> | SHACL Validation |
| Blocking + Sequence    |     | SPARQL CONSTRUCT rules |     | data/shapes.ttl  |
| Matcher + owl:sameAs   |     | subClass / subProperty |     | pyshacl report   |
+------------------------+     +------------------------+     +------------------+
                                                                    |
        +-----------------------------------------------------------+
        v
+--------------------------------------------------------------------------------+
|                         Hybrid GraphRAG Retrieval                              |
|  * Baseline: Keyword TF-IDF cosine chunk search                                |
|  * Local Search: Entity linking -> 1-2 hop SPARQL expansion -> provenance      |
|                  chunk boosting -> token-budget context assembly               |
|  * Global Search: Connected-component community summaries                      |
+--------------------------------------------------------------------------------+
        |
        v
+--------------------------------------------------------------------------------+
|              Grounded Answer Synthesis & Benchmark Evaluation                  |
|  * Answers cite [triple: s p o] and [chunk: docX#chunkY]                       |
|  * Metrics: Retrieval Recall, Citation Accuracy, Groundedness                  |
+--------------------------------------------------------------------------------+
```

## Why It Matters

When you extract triples from text with NLP rules (`kgcreator`) or a language model (`NSK`), three failure modes appear right away:

- **Unverified structure**: A project node may lack a label or creator, or a confidence score may fall outside `[0.0, 1.0]`. Shapes Constraint Language (SHACL) catches these violations before bad facts enter the index.
- **Fragmented identities**: One document refers to `"Mark L. Watson"` and `"KG-Creator"`, while another refers to `"Mark Watson"` and `"KGCreator"`. Until you resolve those aliases to canonical URIs, a multi-hop query stops at the document boundary.
- **Missing provenance**: When a RAG system states a fact, the user needs to know which document chunk produced that triple and how confident the extractor was.

At retrieval time, chunk-only RAG (`zvec_RAG`) scores each passage independently. Consider this multi-hop question from our benchmark:

> *"Which database stores embeddings for the RAG system built by Mark L. Watson, and which model generates its answers?"*

Document 1 states that `Mark L. Watson` created `zvec_RAG`. Document 5 states that `zvec_RAG` stores embeddings in `Alibaba zvec` and generates answers with `qwen3:1.7b`, without mentioning `Mark L. Watson`. A chunk-only retriever under a tight token budget picks either Document 1 or Document 5, missing half the chain. GraphRAG links `Mark L. Watson` to `mark_watson` via `owl:sameAs`, walks one hop to `zvec_rag`, and walks a second hop to `zvec_db` and `qwen3_1_7b`, pulling the exact supporting chunks via `prov:wasDerivedFrom`.

## The Hy Angle

Hy makes RDF manipulation, rule execution, and retrieval scoring concise:

- **Frozen dataclasses with type annotations (`#^`)**: Records such as `DocChunk`, `ExtractedTriple`, `ValidationResult`, `ResolutionCandidate`, and `ScoredTriple` are immutable values declared in four to eight lines each.
- **Comprehensions (`lfor`, `gfor`, `dfor`)**: Computing TF-IDF vectors, filtering triples inside a connected component, and building lookup maps take a single expression.
- **Tuple unpacking (`#(s p o)`)**: `rdflib` represents every triple as a 3-tuple. Hy unpacks `(for [#(s p o) g] ...)` directly in loops and comprehensions.
- **First-class validators for transactions**: Our `transactional-sparql-update` function takes an optional validator lambda `(fn [g] ...)`, runs a SPARQL Update, checks the post-update graph with SHACL, and restores the snapshot if validation fails.

## Python Equivalent

To see how Hy maps to Python when working with `rdflib`, compare our RDFS closure loop in `quality.hy` with the equivalent Python code.

In Hy:

```hy
(defn apply-rdfs-inference [g [max-passes 6]]
  (setv added []
        pass-num 0)
  (while (< pass-num max-passes)
    (setv new-in-pass [])
    (for [rule RDFS_CONSTRUCT_RULES]
      (for [triple (.query g rule)]
        (when (not (in triple g))
          (.add g triple)
          (.append new-in-pass triple)
          (.append added triple))))
    (when (= (len new-in-pass) 0)
      (break))
    (setv pass-num (+ pass-num 1)))
  added)
```

In Python:

```python
def apply_rdfs_inference(g, max_passes=6):
    added = []
    for _ in range(max_passes):
        new_in_pass = []
        for rule in RDFS_CONSTRUCT_RULES:
            for triple in g.query(rule):
                if triple not in g:
                    g.add(triple)
                    new_in_pass.append(triple)
                    added.append(triple)
        if not new_in_pass:
            break
    return added
```

Both compile to the same bytecode and call `g.query(rule)` on the underlying `rdflib.Graph`.

## Run It

The project runs offline with no API keys or external database servers. If you want to test live extraction with Ollama (`OllamaExtractor`), start Ollama locally; if Ollama is not running, the extractor prints a short notice and falls back to `FakeExtractor`.

Run the walkthrough and test suite with `uv`:

```bash
cd source_code_for_examples/graphrag_kg_quality
uv sync
uv run hy demo.hy
uv run pytest -q
```

Here is the actual output from `uv run hy demo.hy`:

```text
=== 1. Corpus & Extraction ===
Loaded 12 text chunks across 6 documents.
Extracted 27 entities and 30 raw triples.
Provenance for (kgcreator usesComponent spacy): [{'chunk_id': 'doc3#chunk0', 'doc_id': 'doc3_kgcreator', 'confidence': 0.95}]

=== 2. Entity Resolution (Blocking + String Similarity) ===
  [auto-merge] mark_l_watson (Mark L. Watson) -> mark_watson (Mark Watson) [block=Person:m, sim=0.9167]
  [auto-merge] kg_creator (KG-Creator) -> kgcreator (KGCreator) [block=System:k, sim=0.9474]
  [review-queue] qwen3_5_4b (qwen3.5:4b) ? qwen3_1_7b (qwen3:1.7b) [block=Component:q, sim=0.7778]
  [review-queue] mark_l_watson (Mark L. Watson) ? m_watson (M. Watson) [block=Person:m, sim=0.7619]
  [review-queue] m_watson (M. Watson) ? mark_watson (Mark Watson) [block=Person:m, sim=0.8421]

=== 3. RDFS Inference & SHACL Validation ===
RDFS inference derived 37 implicit triples.
Clean graph SHACL conforms: True (violations: 0)
Corrupted sample SHACL conforms: False (violations: 4)
  - focus=http://example.org/kgrag/orphan_agent | Every SoftwareProject must have at least one string rdfs:label.
  - focus=http://example.org/kgrag/orphan_agent | Every SoftwareProject must specify an ex:createdBy pointing to an ex:Person.
  - focus=http://example.org/kgrag/stmt_bad_conf | Every reified rdf:Statement must have an xsd:double ex:confidence in [0.0, 1.0].
  - focus=http://example.org/kgrag/stmt_bad_conf | Every reified rdf:Statement must link to a source chunk IRI via prov:wasDerivedFrom.

=== 4. SPARQL Update & Snapshot Rollback ===
Valid SPARQL Update: ok=True, triples 377 -> 378
Invalid SPARQL Update rolled back: ok=False, triples restored to 378

=== 5. Baseline vs GraphRAG Retrieval (Local & Global) ===
Question: Which database stores embeddings for the RAG system built by Mark L. Watson, and which model generates its answers?
  Baseline chunks: ['doc5#chunk1', 'doc5#chunk0']
  GraphRAG seeds:  ['mark_watson']
  GraphRAG chunks: ['doc6#chunk0', 'doc5#chunk1', 'doc5#chunk0', 'doc1#chunk0']
  GraphRAG cited triples (10): ['zvec_rag usesEmbeddingModel embeddinggemma', 'zvec_rag usesGenerationModel qwen3_1_7b', 'kg_rag createdBy mark_watson', 'zvec_rag createdBy mark_watson']
  Global search communities: 3
    * [community_3: KG Quality & GraphRAG Validation] Entities: kg_rag, prov_o, pyshacl, shacl, sparql_2hop. Key relations: kg_rag dependsOn pyshacl; kg_rag dependsOn sparql_2hop; kg_rag tracksProvenanceWith prov_o; kg_rag usesComponent pyshacl; kg_rag usesComponent sparql_2hop.
    * [community_2: Local Vector RAG Pipeline] Entities: embeddinggemma, qwen3_1_7b, zvec_db, zvec_rag. Key relations: zvec_rag dependsOn zvec_db; zvec_rag usesComponent zvec_db; zvec_rag usesDatastore zvec_db; zvec_rag usesEmbeddingModel embeddinggemma; zvec_rag usesGenerationModel qwen3_1_7b.
    * [community_1: Symbolic & Neural-Symbolic Graph Systems] Entities: datalog_rules, dbpedia, hy_lang, kgcreator, kgn, nsk, nsk_engine, ollama_fallback, qwen3_5_4b, rdf_datastore, rdflib_store, schema_org, spacy, turtle_rdf, unification. Key relations: kgcreator dependsOn hy_lang; kgcreator dependsOn rdflib_store; kgcreator dependsOn spacy; kgcreator linksEntitiesTo dbpedia; kgcreator usesComponent hy_lang.

=== 6. Benchmark Evaluation Table ===
Case | Mode           | Recall | CiteAcc | Grounded
-----+----------------+--------+---------+---------
Q1   | Baseline       |   0.67 |    1.00 |     0.67
Q1   | GraphRAG       |   1.00 |    1.00 |     1.00
Q2   | Baseline       |   0.33 |    1.00 |     0.00
Q2   | GraphRAG       |   1.00 |    1.00 |     1.00
Q3   | Baseline       |   1.00 |    1.00 |     0.67
Q3   | GraphRAG       |   1.00 |    1.00 |     1.00
Q4   | Baseline       |   1.00 |    1.00 |     0.33
Q4   | GraphRAG       |   1.00 |    1.00 |     1.00
Q5   | Baseline       |   1.00 |    1.00 |     0.67
Q5   | GraphRAG       |   1.00 |    1.00 |     1.00
Q6   | Baseline       |   0.20 |    1.00 |     0.20
Q6   | GraphRAG       |   1.00 |    1.00 |     1.00
-----+----------------+--------+---------+---------
AVG  | Baseline       |   0.70 |    1.00 |     0.42
AVG  | GraphRAG       |   1.00 |    1.00 |     1.00
```

## How It Works

### 1. Corpus Ingestion and Triple Extraction: `corpus.hy` and `extract.hy`

The `data/` directory holds six short text files (`doc1_hy_ecosystem.txt` through `doc6_shacl_prov.txt`). Each document starts with `Document:` and `Source:` metadata lines followed by four sentences. `corpus.hy` reads these files and groups every two sentences into a `DocChunk` with a stable identifier such as `doc1#chunk0`:

```hy
(defclass [(dataclass :frozen True)] DocChunk []
  "A text chunk with provenance identifiers."
  #^ str doc-id
  #^ str chunk-id
  #^ str source-uri
  #^ str text)

(defn chunk-lines [doc-id source-uri lines [sentences-per-chunk 2]]
  "Group body lines into fixed-line-count chunks with stable IDs."
  (setv chunks []
        idx 0
        i 0)
  (while (< i (len lines))
    (setv group (cut lines i (+ i sentences-per-chunk))
          short-id (get (.split doc-id "_" 1) 0)
          chunk-id f"{short-id}#chunk{idx}"
          text (.join " " group))
    (.append chunks (DocChunk :doc-id doc-id
                              :chunk-id chunk-id
                              :source-uri source-uri
                              :text text))
    (setv idx (+ idx 1)
          i (+ i sentences-per-chunk)))
  chunks)
```

In `extract.hy`, every extracted triple carries its source `doc-id`, `chunk-id`, and a floating-point `confidence` in `[0.0, 1.0]`:

```hy
(defclass [(dataclass :frozen True)] EntityRecord []
  "An extracted entity with local slug, human label, and ontology class."
  #^ str local-id
  #^ str label
  #^ str entity-type)

(defclass [(dataclass :frozen True)] ExtractedTriple []
  "A subject-predicate-object assertion tied to a document chunk and confidence."
  #^ str subject
  #^ str predicate
  #^ str object-val
  #^ str doc-id
  #^ str chunk-id
  #^ float confidence)
```

`FakeExtractor` matches deterministic text triggers so tests run in under a second without network calls. `OllamaExtractor` sends a JSON-mode request to a local Ollama server and falls back to `FakeExtractor` when Ollama is unreachable.

### 2. RDF Graph Construction, PROV-O Provenance, and SPARQL Update: `kg.hy`

When we load an `ExtractedTriple` into `rdflib`, asserting `(s, p, o)` alone loses the chunk ID and confidence score. In `kg.hy`, `add-provenance-triple` adds both the domain triple and a reified `rdf:Statement` node linked to a `prov:Entity` chunk node via `prov:wasDerivedFrom`:

```hy
(defn add-provenance-triple [g triple-rec]
  "Add both the asserted triple and its reified rdf:Statement provenance node."
  (setv s-ref (get EX triple-rec.subject)
        p-ref (get EX triple-rec.predicate)
        o-ref (get EX triple-rec.object-val)
        c-ref (chunk-uri triple-rec.chunk-id)
        stmt (statement-uri triple-rec.subject
                            triple-rec.predicate
                            triple-rec.object-val
                            triple-rec.chunk-id))
  (.add g #(s-ref p-ref o-ref))
  (.add g #(c-ref RDF.type PROV.Entity))
  (.add g #(c-ref EX.chunkId (Literal triple-rec.chunk-id :datatype XSD.string)))
  (.add g #(c-ref EX.docId (Literal triple-rec.doc-id :datatype XSD.string)))
  (.add g #(stmt RDF.type RDF.Statement))
  (.add g #(stmt RDF.subject s-ref))
  (.add g #(stmt RDF.predicate p-ref))
  (.add g #(stmt RDF.object o-ref))
  (.add g #(stmt PROV.wasDerivedFrom c-ref))
  (.add g #(stmt EX.fromDocument (Literal triple-rec.doc-id :datatype XSD.string)))
  (.add g #(stmt EX.confidence (Literal (float triple-rec.confidence) :datatype XSD.double)))
  stmt)
```

At retrieval time, `provenance-for-triple` runs a SPARQL query over the reified statements to recover every chunk and confidence score supporting `(s, p, o)`.

Knowledge graphs also change over time as documents are edited or retracted. `transactional-sparql-update` clones the graph before running a `SPARQL Update` (`INSERT DATA`, `DELETE WHERE`, or `DELETE/INSERT`), runs an optional validation callback afterward, and restores the snapshot if either the update or validation fails:

```hy
(defn transactional-sparql-update [g update-query [validator None]]
  "Run a SPARQL Update on g; roll back to a snapshot if execution or validator fails."
  (setv snapshot (clone-graph g))
  (try
    (.update g update-query)
    (when (not (is validator None))
      (setv #(ok reason) (validator g))
      (when (not ok)
        (raise (ValueError f"Post-update validation failed: {reason}"))))
    #(True "committed" (len g))
    (except [e Exception]
      (.remove g #(None None None))
      (for [triple snapshot]
        (.add g triple))
      #(False (str e) (len g)))))
```

### 3. Entity Resolution: Blocking, Similarity, and `owl:sameAs` in `resolve.hy`

Comparing every entity pair in an `N`-node graph takes `O(N^2)` string comparisons. `resolve.hy` avoids quadratic blowup by grouping entities into blocks that share a coarse ontology class (`Person`, `System`, `Component`, `Standard`) and the first character of their normalized label:

```hy
(defn normalize-label [label]
  "Lowercase label, strip periods, and collapse whitespace."
  (setv s (.replace (.lower label) "." "")
        s (re.sub r"\s+" " " (.strip s)))
  s)

(defn blocking-key [entity]
  "Group entities by coarse ontology class and first character of normalized label."
  (setv norm (normalize-label entity.label)
        first-ch (if (> (len norm) 0) (get norm 0) "_"))
  f"{(coarse-type entity.entity-type)}:{first-ch}")

(defn label-similarity [label-a label-b]
  "Compute string similarity in [0.0, 1.0] using difflib.SequenceMatcher."
  (setv na (normalize-label label-a)
        nb (normalize-label label-b))
  (.ratio (SequenceMatcher None na nb)))
```

Within each block, `resolve-entities` applies two thresholds:

- **Auto-merge (`>= 0.88`)**: High-similarity pairs such as `"Mark L. Watson"` vs `"Mark Watson"` (`0.9167`) and `"KG-Creator"` vs `"KGCreator"` (`0.9474`) emit an `owl:sameAs` link and call `canonicalize-uri-in-graph`, which rewrites triples (including provenance `rdf:subject` and `rdf:object` pointers) to use the canonical URI.
- **Human review queue (`0.72` to `0.88`)**: Ambiguous pairs such as `"M. Watson"` vs `"Mark Watson"` (`0.8421`) and `"qwen3.5:4b"` vs `"qwen3:1.7b"` (`0.7778`) are not merged automatically. Notice that the two Qwen model names have high character overlap (`0.7778`) even though they are distinct models; routing this band to a review list prevents false merges.

### 4. RDFS Inference and SHACL Validation: `quality.hy` and `data/shapes.ttl`

Before validating the graph with SHACL, `apply-rdfs-inference` runs six SPARQL `CONSTRUCT` rules to materialize the RDFS closure:

1. Transitive `rdfs:subClassOf` chains.
2. Instance typing across `rdfs:subClassOf` (so an `ex:NeuralSymbolicSystem` such as `ex:nsk` becomes an `ex:SoftwareProject` and an `ex:AISoftware`).
3. Transitive `rdfs:subPropertyOf` chains.
4. Property inheritance across `rdfs:subPropertyOf` (so `(ex:nsk ex:authoredBy ex:mark_watson)` derives `(ex:nsk ex:createdBy ex:mark_watson)`).
5. `rdfs:domain` typing.
6. `rdfs:range` typing.

Once RDFS inference completes, `validate-graph` checks the graph against `data/shapes.ttl` using `pyshacl`:

```turtle
ex:SoftwareProjectShape
    a sh:NodeShape ;
    sh:targetClass ex:SoftwareProject ;
    sh:property [
        sh:path rdfs:label ;
        sh:minCount 1 ;
        sh:datatype xsd:string ;
        sh:message "Every SoftwareProject must have at least one string rdfs:label." ;
    ] ;
    sh:property [
        sh:path ex:createdBy ;
        sh:minCount 1 ;
        sh:class ex:Person ;
        sh:message "Every SoftwareProject must specify an ex:createdBy pointing to an ex:Person." ;
    ] .

ex:ProvenanceStatementShape
    a sh:NodeShape ;
    sh:targetClass rdf:Statement ;
    sh:property [
        sh:path prov:wasDerivedFrom ;
        sh:minCount 1 ;
        sh:nodeKind sh:IRI ;
        sh:message "Every reified rdf:Statement must link to a source chunk IRI via prov:wasDerivedFrom." ;
    ] ;
    sh:property [
        sh:path ex:confidence ;
        sh:minCount 1 ;
        sh:datatype xsd:double ;
        sh:minInclusive 0.0 ;
        sh:maxInclusive 1.0 ;
        sh:message "Every reified rdf:Statement must have an xsd:double ex:confidence in [0.0, 1.0]." ;
    ] .
```

Our resolved and inferred graph passes with zero violations. To show how SHACL catches bad extractions, `make-invalid-graph-sample` in `quality.hy` injects an unattributed `ex:orphan_agent` project and a `ex:stmt_bad_conf` statement with `ex:confidence 1.45`. Running `validate-graph` on that sample returns `conforms=False` and extracts each `sh:ValidationResult` focus node and message via SPARQL.

### 5. Property Graphs vs RDF: A Short Neo4j and Cypher Comparison

Caution: this chapter is not a Neo4j manual. Our priority is trustworthy retrieval, and `rdflib` + `pyshacl` runs in-process with zero external services. Still, many engineering teams store knowledge graphs in property graph databases such as Neo4j, so it helps to see how the two models compare.

| Feature | RDF + SPARQL (`rdflib`) | Property Graph + Cypher (Neo4j) |
| --- | --- | --- |
| Core unit | Triple `(subject, predicate, object)` with global IRIs | Labeled nodes and directed relationships with key-value maps |
| Edge attributes | Reification (`rdf:Statement`) or RDF-star | Native properties stored directly on relationships |
| Schema validation | W3C SHACL (`pyshacl`) and OWL/RDFS entailment | Property existence/type constraints; no built-in RDFS reasoner |
| Federation & standards | W3C standards (Turtle, JSON-LD, SPARQL 1.1, PROV-O) | GQL / openCypher; database-specific storage |

Here are two SPARQL queries from our pipeline alongside their Cypher equivalents:

**Query A: Fetch provenance chunk ID and confidence for a triple.**

In SPARQL (using our reified `rdf:Statement` model):

```sparql
PREFIX ex:   <http://example.org/kgrag/>
PREFIX prov: <http://www.w3.org/ns/prov#>
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT ?chunkId ?conf WHERE {
  ?stmt a rdf:Statement ;
        rdf:subject ex:kgcreator ;
        rdf:predicate ex:usesComponent ;
        rdf:object ex:spacy ;
        prov:wasDerivedFrom ?c ;
        ex:confidence ?conf .
  ?c ex:chunkId ?chunkId .
}
```

In Cypher (where chunk ID and confidence live as relationship properties):

```cypher
MATCH (:SoftwareProject {id: 'kgcreator'})-[r:USES_COMPONENT]->(:Component {id: 'spacy'})
RETURN r.chunk_id AS chunkId, r.confidence AS conf
```

**Query B: Two-hop traversal from an author to components used by that author's projects.**

In SPARQL:

```sparql
PREFIX ex: <http://example.org/kgrag/>
SELECT ?project ?component WHERE {
  ?project ex:createdBy ex:mark_watson ;
           ex:usesComponent ?component .
}
```

In Cypher:

```cypher
MATCH (p:SoftwareProject)-[:CREATED_BY]->(:Person {id: 'mark_watson'}),
      (p)-[:USES_COMPONENT]->(c:Component)
RETURN p.id AS project, c.id AS component
```

Choose RDF when you need standard vocabularies (`schema.org`, `PROV-O`), RDFS/OWL inference, or SHACL validation. Choose a property graph when edge-heavy analytics and relationship properties dominate and you do not need semantic web ontologies.

### 6. Hybrid Retrieval, Token Budgets, and Community Summaries: `retrieve.hy` and `graphrag.hy`

`retrieve.hy` implements two retrievers:

1. **`KeywordRetriever` (Baseline)**: Computes IDF-weighted bag-of-words vectors over chunks and ranks chunks by cosine similarity against the query, packing top chunks up to `token-budget`. This stands in for a chunk-only vector baseline without requiring a multi-gigabyte embedding model in CI.
2. **`GraphRetriever` (Local and Global GraphRAG)**:
   - **Entity linking (`link-entities`)**: Matches query terms against `rdfs:label` values, resolves `owl:sameAs` aliases to canonical URIs, and maps class phrases such as `"AI software"` to instances of `ex:AISoftware`.
   - **Neighborhood expansion (`expand-neighborhood`)**: Walks 1-hop and 2-hop outgoing and incoming edges around seed entities, attaching provenance chunk IDs and confidence scores to every `ScoredTriple`.
   - **Provenance chunk boosting and token budgeting (`local-search`)**: Ranks neighborhood triples by non-seed query token overlap, allocates up to 35% of `token-budget` to structured triples, boosts the retrieval score of source chunks linked via `prov:wasDerivedFrom` to those triples, and fills the remaining token budget with the highest-scoring chunks:

```hy
    ;; Assemble top triples within 35% of the token budget first
    (setv kept-triples []
          used 0
          triple-budget (int (* token-budget 0.35)))
    (for [st ranked-triples]
      (setv t-cost 6)
      (when (<= (+ used t-cost) triple-budget)
        (.append kept-triples st)
        (setv used (+ used t-cost))))

    ;; Boost chunks referenced via prov:wasDerivedFrom by kept triples
    (setv chunk-boost {}
          kw-scores (dfor #(sim ch) (.score-chunks self.keyword query) ch.chunk-id sim))
    (for [st kept-triples]
      (setv weight (if (= st.hop 1) 0.45 0.35))
      (for [cid st.chunk-ids]
        (setv (get chunk-boost cid)
              (+ (.get chunk-boost cid 0.0) (* weight st.confidence)))))
```

For broad thematic questions (such as *"Compare the major knowledge graph and RAG architectures in this corpus"*), `build-communities` removes high-degree author hub edges (`createdBy`, `authoredBy`) and finds connected components in the technical dependency graph. This partitions the graph into three communities (`KG Quality & GraphRAG Validation`, `Local Vector RAG Pipeline`, and `Symbolic & Neural-Symbolic Graph Systems`) and builds a `CommunitySummary` with member entities, key triples, and supporting chunk IDs for `global-search`.

In `graphrag.hy`, `synthesize-grounded-answer` formats an `AnswerResult` that cites every used triple (`[triple: s p o]`) and chunk (`[chunk: docX#chunkY]`).

### 7. Evaluating Retrieval and Groundedness: `evaluate.hy`

`evaluate.hy` defines six benchmark questions (`Q1` through `Q6`) and scores both `baseline` and `graphrag_local` on three metrics in `[0.0, 1.0]`:

- **Retrieval Recall**: Fraction of gold source chunks present in the retrieved chunks or triple provenance links.
- **Citation Accuracy**: Fraction of `[triple: ...]` and `[chunk: ...]` citations in the answer that exist in the retrieved context.
- **Groundedness**: Fraction of required target facts present in the context-backed answer.

Across the six benchmark questions, the chunk-only baseline averages `0.70` recall and `0.42` groundedness because multi-hop questions (`Q1`, `Q2`, `Q6`) split facts across documents or use entity aliases (`Mark L. Watson`, `KG-Creator`). GraphRAG reaches `1.00` recall, `1.00` citation accuracy, and `1.00` groundedness while staying inside its 180-token context budget.

## Tests

The test suite lives in `test_graphrag.hy` and runs offline in one second:

```bash
$ uv run pytest -q
..........                                                               [100%]
10 passed in 1.00s
```

The 10 tests verify:

1. `test-corpus-loading`: 12 chunks load with stable `docX#chunkY` IDs.
2. `test-extraction-and-provenance`: `provenance-for-triple` returns `doc3#chunk0` and confidence `0.95` for `(kgcreator usesComponent spacy)`.
3. `test-ollama-extractor-graceful-fallback`: `OllamaExtractor` falls back cleanly to `FakeExtractor` when pointed at an closed port.
4. `test-entity-resolution-blocking-and-canonicalization`: `mark_l_watson` and `kg_creator` auto-merge via `owl:sameAs` and rewrite triples, while `m_watson` enters the human review queue.
5. `test-rdfs-inference-and-shacl-validation`: RDFS `CONSTRUCT` rules infer `ex:SoftwareProject` and `ex:createdBy` on `ex:nsk`; the clean graph passes SHACL and the corrupted sample fails with 4 violations.
6. `test-sparql-update-and-rollback`: A valid `SPARQL Update` commits, while an update that violates SHACL rolls back to the snapshot.
7. `test-retrieval-token-budget-and-modes`: Local and global GraphRAG respect `token-budget` and recover 2-hop facts.
8. `test-blocking-and-similarity-primitives`: Unit checks on `blocking-key` and `label-similarity`.
9. `test-sparql-syntax-error-rollback`: Malformed SPARQL Update syntax rolls back cleanly.
10. `test-evaluation-metrics-graphrag-outperforms-baseline`: Confirms GraphRAG outperforms the baseline on both recall and groundedness with `1.0` citation accuracy.

## Wrap Up

A knowledge graph is only as useful as its quality controls and its retrieval path. By combining PROV-O reification, entity resolution with `owl:sameAs`, RDFS `CONSTRUCT` inference, SHACL validation, and 2-hop provenance-boosted retrieval, `kg-rag` turns raw text extractions into a verifiable GraphRAG system in about 650 lines of Hy.

## Exercises

1. **Confidence filtering in retrieval (small)**: Add a `:min-confidence` keyword parameter (default `0.90`) to `GraphRetriever.expand-neighborhood` in `retrieve.hy` so that triples whose provenance confidence is below `:min-confidence` are excluded during 1-to-2 hop traversal. Write a pytest test showing that lowering or raising `:min-confidence` changes the retrieved triple set.
2. **RDF-star / named-graph provenance and LLM judge (open-ended)**: Refactor `kg.hy` to store each document's assertions in a separate named graph within an `rdflib.Dataset` instead of reified `rdf:Statement` nodes, update `shapes.ttl` to validate the named graphs, and connect `GraphRAGPipeline` to a local Ollama model that grades answer faithfulness on a 1-to-5 rubric.

## Further Reading

- Aidan Hogan et al., *Knowledge Graphs* (Springer, 2021) for formal coverage of RDF, RDFS, OWL entailment, and SHACL validation shapes.
- Tomaž Bratanič and Oskar Hane, *Essential GraphRAG* (Manning) for hybrid vector + graph retrieval patterns and community summarization.
- W3C *Shapes Constraint Language (SHACL)* Recommendation (`https://www.w3.org/TR/shacl/`) and W3C *PROV-O: The PROV Ontology* (`https://www.w3.org/TR/prov-o/`).
- The `rdflib` documentation (`https://rdflib.readthedocs.io/`) and `pyshacl` repository (`https://github.com/RDFLib/pySHACL`).
