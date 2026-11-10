(import dataclasses [dataclass])
(import pathlib [Path])
(import pyshacl [validate])
(import rdflib [Graph Literal Namespace RDF RDFS XSD])
(import kg [EX PROV clone-graph])

(setv SH (Namespace "http://www.w3.org/ns/shacl#"))

(defclass [(dataclass :frozen True)] ValidationResult []
  "Structured result of a SHACL validation pass."
  #^ bool conforms
  #^ int violation-count
  #^ list violations
  #^ str report-text)

(defn default-shapes-path []
  (/ (. (Path __file__) parent) "data" "shapes.ttl"))

(defn load-shapes-graph [[shapes-path None]]
  (setv p (if (is shapes-path None) (default-shapes-path) (Path shapes-path))
        sg (Graph))
  (.parse sg (str p) :format "turtle")
  sg)

(defn validate-graph [data-graph [shapes-path None]]
  "Validate data-graph against SHACL shapes and return a ValidationResult."
  (setv sg (load-shapes-graph shapes-path)
        #(conforms results-graph results-text)
        (validate data-graph
                  :shacl_graph sg
                  :inference "none"
                  :serialize_report_graph False)
        q "
          PREFIX sh: <http://www.w3.org/ns/shacl#>
          SELECT ?focus ?path ?msg WHERE {
            ?vr a sh:ValidationResult ;
                sh:focusNode ?focus ;
                sh:resultMessage ?msg .
            OPTIONAL { ?vr sh:resultPath ?path }
          }
          ORDER BY ?focus ?msg
        "
        violations [])
  (for [row (.query results-graph q)]
    (.append violations
      {"focus_node" (str row.focus)
       "path" (if row.path (str row.path) "")
       "message" (str row.msg)}))
  (ValidationResult :conforms (bool conforms)
                    :violation-count (len violations)
                    :violations violations
                    :report-text (.strip results-text)))

(defn make-invalid-graph-sample [base-graph]
  "Clone base-graph and inject two malformed records that violate shapes.ttl."
  (setv bad-g (clone-graph base-graph))
  ;; 1. A SoftwareProject missing both rdfs:label and ex:createdBy
  (.add bad-g #(EX.orphan_agent RDF.type EX.SoftwareProject))
  ;; 2. A reified statement with confidence > 1.0 and no prov:wasDerivedFrom
  (.add bad-g #(EX.stmt_bad_conf RDF.type RDF.Statement))
  (.add bad-g #(EX.stmt_bad_conf EX.confidence (Literal 1.45 :datatype XSD.double)))
  bad-g)

(setv RDFS_CONSTRUCT_RULES
  ["PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    CONSTRUCT { ?c1 rdfs:subClassOf ?c3 }
    WHERE { ?c1 rdfs:subClassOf ?c2 . ?c2 rdfs:subClassOf ?c3 . FILTER(?c1 != ?c3) }"
   "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    CONSTRUCT { ?x a ?c2 }
    WHERE { ?x a ?c1 . ?c1 rdfs:subClassOf ?c2 . }"
   "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    CONSTRUCT { ?p1 rdfs:subPropertyOf ?p3 }
    WHERE { ?p1 rdfs:subPropertyOf ?p2 . ?p2 rdfs:subPropertyOf ?p3 . FILTER(?p1 != ?p3) }"
   "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    CONSTRUCT { ?s ?p2 ?o }
    WHERE { ?p1 rdfs:subPropertyOf ?p2 . ?s ?p1 ?o . }"
   "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    CONSTRUCT { ?s a ?dom }
    WHERE { ?p rdfs:domain ?dom . ?s ?p ?o . }"
   "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    CONSTRUCT { ?o a ?rng }
    WHERE { ?p rdfs:range ?rng . ?s ?p ?o . }"])

(defn apply-rdfs-inference [g [max-passes 6]]
  "Materialize RDFS closure in g using SPARQL CONSTRUCT rules; return added triples."
  (setv added []
        pass-num 0)
  (while (< pass-num max-passes)
    (setv new-in-pass [])
    (for [rule RDFS_CONSTRUCT_RULES]
      (setv constructed (.query g rule))
      (for [triple constructed]
        (when (not (in triple g))
          (.add g triple)
          (.append new-in-pass triple)
          (.append added triple))))
    (when (= (len new-in-pass) 0)
      (break))
    (setv pass-num (+ pass-num 1)))
  added)
