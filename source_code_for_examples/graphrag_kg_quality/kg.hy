(import copy)
(import hashlib)
(import rdflib [Graph Namespace URIRef Literal RDF RDFS OWL XSD])

(setv EX (Namespace "http://example.org/kgrag/")
      PROV (Namespace "http://www.w3.org/ns/prov#"))

(defn make-empty-graph []
  "Create an rdflib Graph with standard namespace bindings."
  (setv g (Graph))
  (.bind g "ex" EX)
  (.bind g "prov" PROV)
  (.bind g "owl" OWL)
  (.bind g "rdfs" RDFS)
  g)

(defn load-ontology-schema [g]
  "Insert RDFS class and property hierarchy axioms into g."
  (setv subclass-pairs
    [#(EX.NeuralSymbolicSystem EX.KnowledgeGraphSystem)
     #(EX.KnowledgeGraphSystem EX.SoftwareProject)
     #(EX.VectorRAGSystem EX.RetrievalSystem)
     #(EX.GraphRAGSystem EX.RetrievalSystem)
     #(EX.RetrievalSystem EX.SoftwareProject)
     #(EX.SoftwareProject EX.AISoftware)])
  (for [#(sub sup) subclass-pairs]
    (.add g #(sub RDFS.subClassOf sup)))

  (setv subprop-pairs
    [#(EX.authoredBy EX.createdBy)
     #(EX.usesDatastore EX.usesComponent)
     #(EX.usesComponent EX.dependsOn)])
  (for [#(subp supp) subprop-pairs]
    (.add g #(subp RDFS.subPropertyOf supp)))

  (.add g #(EX.createdBy RDFS.domain EX.SoftwareProject))
  (.add g #(EX.createdBy RDFS.range EX.Person))
  g)

(defn chunk-uri [chunk-id]
  "Convert a chunk identifier like doc1#chunk0 into a stable IRI."
  (setv safe (.replace chunk-id "#" "_"))
  (get EX f"chunk_{safe}"))

(defn statement-uri [s-slug p-slug o-slug chunk-id]
  "Deterministic IRI for a reified provenance statement."
  (setv raw f"{s-slug}|{p-slug}|{o-slug}|{chunk-id}"
        digest (cut (.hexdigest (hashlib.sha1 (.encode raw "utf-8"))) 0 10))
  (get EX f"stmt_{digest}"))

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

(defn build-kg [batch [include-schema True]]
  "Construct an RDF graph from an ExtractionBatch with full PROV-O metadata."
  (setv g (make-empty-graph))
  (when include-schema
    (load-ontology-schema g))
  (for [ent batch.entities]
    (setv u (get EX ent.local-id)
          cls (get EX ent.entity-type))
    (.add g #(u RDF.type cls))
    (.add g #(u RDFS.label (Literal ent.label :datatype XSD.string))))
  (for [tr batch.triples]
    (add-provenance-triple g tr))
  g)

(defn clone-graph [g]
  "Create a deep copy of an rdflib Graph for snapshot rollback."
  (setv copy-g (make-empty-graph))
  (for [triple g]
    (.add copy-g triple))
  copy-g)

(defn provenance-for-triple [g s-slug p-slug o-slug]
  "Return a list of dicts with chunk_id, doc_id, and confidence for (s, p, o)."
  (setv q "
    PREFIX ex:   <http://example.org/kgrag/>
    PREFIX prov: <http://www.w3.org/ns/prov#>
    PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    SELECT ?chunkId ?docId ?conf WHERE {
      ?stmt a rdf:Statement ;
            rdf:subject ?s ;
            rdf:predicate ?p ;
            rdf:object ?o ;
            prov:wasDerivedFrom ?c ;
            ex:confidence ?conf .
      ?c ex:chunkId ?chunkId ;
         ex:docId ?docId .
    }
    ORDER BY DESC(?conf) ?chunkId
  "
        rows (.query g q :initBindings {"s" (get EX s-slug)
                                        "p" (get EX p-slug)
                                        "o" (get EX o-slug)})
        out [])
  (for [r rows]
    (.append out {"chunk_id" (str r.chunkId)
                  "doc_id" (str r.docId)
                  "confidence" (float r.conf)}))
  out)

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
