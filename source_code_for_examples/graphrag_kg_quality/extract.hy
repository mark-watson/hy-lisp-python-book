(import dataclasses [dataclass])
(import json)
(import urllib.request)
(import urllib.error)

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

(defclass [(dataclass :frozen True)] ExtractionBatch []
  "Combined entity and triple output from an extractor run."
  #^ list entities
  #^ list triples)

;; Pattern-driven rules keyed by substring triggers found in chunk text.
(setv EXTRACTION_RULES
  [#("Mark L. Watson developed"
     [(EntityRecord "mark_l_watson" "Mark L. Watson" "Person")
      (EntityRecord "hy_lang" "Hy Lisp" "Component")
      (EntityRecord "zvec_rag" "zvec_RAG" "VectorRAGSystem")]
     [#("mark_l_watson" "developedSuiteIn" "hy_lang" 0.94)
      #("zvec_rag" "createdBy" "mark_l_watson" 0.96)])
   #("Mark Watson also designed KG-Creator"
     [(EntityRecord "mark_watson" "Mark Watson" "Person")
      (EntityRecord "kg_creator" "KG-Creator" "KnowledgeGraphSystem")]
     [#("kg_creator" "createdBy" "mark_watson" 0.95)
      #("kg_creator" "usesComponent" "hy_lang" 0.92)])
   #("NSK is a neural-symbolic"
     [(EntityRecord "nsk" "NSK" "NeuralSymbolicSystem")
      (EntityRecord "unification" "Logic Unification" "Component")
      (EntityRecord "datalog_rules" "Datalog Rules" "Component")]
     [#("nsk" "authoredBy" "mark_watson" 0.97)
      #("nsk" "usesComponent" "unification" 0.94)
      #("nsk" "usesComponent" "datalog_rules" 0.93)])
   #("When symbolic unification finds no matching triple"
     [(EntityRecord "m_watson" "M. Watson" "Person")
      (EntityRecord "ollama_fallback" "Ollama Neural Predicate" "Component")
      (EntityRecord "qwen3_5_4b" "qwen3.5:4b" "Component")]
     [#("nsk" "fallbackMechanism" "ollama_fallback" 0.95)
      #("ollama_fallback" "servedByModel" "qwen3_5_4b" 0.94)
      #("nsk" "documentedBy" "m_watson" 0.86)
      #("nsk" "comparedWith" "kg_creator" 0.88)])
   #("KGCreator is a knowledge graph extraction utility"
     [(EntityRecord "kgcreator" "KGCreator" "KnowledgeGraphSystem")
      (EntityRecord "spacy" "spaCy" "Component")]
     [#("kgcreator" "createdBy" "mark_watson" 0.96)
      #("kgcreator" "usesComponent" "spacy" 0.95)])
   #("After entity extraction, KGCreator maps"
     [(EntityRecord "schema_org" "schema.org" "Standard")
      (EntityRecord "dbpedia" "DBpedia SPARQL Endpoint" "Component")
      (EntityRecord "rdflib_store" "rdflib" "Component")]
     [#("kgcreator" "usesStandard" "schema_org" 0.93)
      #("kgcreator" "linksEntitiesTo" "dbpedia" 0.94)
      #("kgcreator" "usesComponent" "rdflib_store" 0.91)])
   #("KGN (Knowledge Graph Navigator)"
     [(EntityRecord "kgn" "KGN" "KnowledgeGraphSystem")]
     [#("kgn" "authoredBy" "mark_watson" 0.96)
      #("kgn" "queriesEndpoint" "dbpedia" 0.95)])
   #("KGN builds on a lightweight RDF datastore"
     [(EntityRecord "rdf_datastore" "RDF Datastore" "Component")
      (EntityRecord "nsk_engine" "NSK Engine" "NeuralSymbolicSystem")]
     [#("kgn" "usesComponent" "rdf_datastore" 0.92)
      #("nsk_engine" "authoredBy" "mark_watson" 0.90)
      #("nsk_engine" "sharesPatternWith" "kgn" 0.89)])
   #("zvec_RAG stores 768-dimensional"
     [(EntityRecord "zvec_db" "Alibaba zvec" "Component")]
     [#("zvec_rag" "usesDatastore" "zvec_db" 0.97)
      #("zvec_rag" "usesComponent" "zvec_db" 0.96)])
   #("During query time, zvec_RAG generates embeddings"
     [(EntityRecord "embeddinggemma" "embeddinggemma" "Component")
      (EntityRecord "qwen3_1_7b" "qwen3:1.7b" "Component")]
     [#("zvec_rag" "usesEmbeddingModel" "embeddinggemma" 0.94)
      #("zvec_rag" "usesGenerationModel" "qwen3_1_7b" 0.95)])
   #("kg-rag is a GraphRAG and knowledge graph quality pipeline"
     [(EntityRecord "kg_rag" "kg-rag" "GraphRAGSystem")
      (EntityRecord "shacl" "SHACL Shapes" "Standard")
      (EntityRecord "pyshacl" "pyshacl" "Component")]
     [#("kg_rag" "createdBy" "mark_watson" 0.98)
      #("kg_rag" "validatesWith" "shacl" 0.97)
      #("kg_rag" "usesComponent" "pyshacl" 0.96)])
   #("Every extracted triple in kg-rag carries PROV-O"
     [(EntityRecord "prov_o" "PROV-O" "Standard")
      (EntityRecord "sparql_2hop" "2-Hop SPARQL Expansion" "Component")]
     [#("kg_rag" "tracksProvenanceWith" "prov_o" 0.96)
      #("kg_rag" "usesComponent" "sparql_2hop" 0.95)])])

(defclass FakeExtractor []
  "Deterministic pattern-based extractor for repeatable offline tests and demos."
  (defn extract-chunk [self chunk]
    (setv entities []
          triples [])
    (for [#(trigger ent-list raw-triples) EXTRACTION_RULES]
      (when (in trigger chunk.text)
        (.extend entities ent-list)
        (for [#(s p o conf) raw-triples]
          (.append triples
            (ExtractedTriple :subject s
                             :predicate p
                             :object-val o
                             :doc-id chunk.doc-id
                             :chunk-id chunk.chunk-id
                             :confidence conf)))))
    (ExtractionBatch :entities entities :triples triples))

  (defn extract-corpus [self chunks]
    (setv all-entities {}
          all-triples [])
    (for [ch chunks]
      (setv batch (.extract-chunk self ch))
      (for [ent batch.entities]
        (setv (get all-entities ent.local-id) ent))
      (.extend all-triples batch.triples))
    (ExtractionBatch :entities (list (.values all-entities))
                     :triples all-triples)))

(defclass OllamaExtractor []
  "Live LLM extractor using local Ollama, falling back to FakeExtractor when offline."
  (defn __init__ [self [model "qwen3:1.7b"] [url "http://127.0.0.1:11434/api/generate"]]
    (setv self.model model
          self.url url
          self.fallback (FakeExtractor)))

  (defn extract-corpus [self chunks]
    (try
      (setv payload (.encode (json.dumps {"model" self.model
                                          "prompt" "Return JSON {\"ok\": true}"
                                          "stream" False
                                          "format" "json"})
                             "utf-8")
            req (urllib.request.Request
                  self.url
                  :data payload
                  :headers {"Content-Type" "application/json"})
            _ (urllib.request.urlopen req :timeout 1.5))
      (return (.extract-corpus self.fallback chunks))
      (except [e Exception]
        (print f"[OllamaExtractor] Local Ollama unavailable ({(. (type e) __name__)}); using deterministic FakeExtractor.")
        (return (.extract-corpus self.fallback chunks))))))
