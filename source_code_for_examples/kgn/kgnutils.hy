;; Utility functions for DBpedia entity retrieval and list manipulation.
(import sparql [dbpedia-sparql])
(import colorize [colorize-sparql])

(import pprint [pprint])

(defn dbpedia-get-entities-by-name [name dbpedia-type]
  ;; Queries DBpedia for entities matching a given name and DBpedia type.
  (setv sparql
        (.format "select distinct ?s ?desc {{ ?s ?p \"{}\"@en . ?s <http://dbpedia.org/ontology/description> ?desc . FILTER (lang(?desc) = 'en') . ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> {} . }} limit 15" name dbpedia-type))
  (print "Generated SPARQL to get DBPedia entity URIs from a name:")
  (print (colorize-sparql sparql))
  (dbpedia-sparql sparql))

;;(pprint (dbpedia-get-entities-by-name "Bill Gates" "<http://dbpedia.org/ontology/Person>"))

(defn first [a-list]
  ;; Returns the first element of a list.
  (get a-list 0))

(defn second [a-list]
  ;; Returns the second element of a list.
  (get a-list 1))
