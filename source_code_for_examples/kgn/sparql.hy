;; Provides helper functions to execute SPARQL queries against Wikidata and DBpedia endpoints.
(import json)
(import requests)

(setv wikidata-endpoint "https://query.wikidata.org/bigdata/namespace/wdq/sparql")
(setv dbpedia-endpoint "https://dbpedia.org/sparql")

(defn do-query-helper [endpoint query]
  ;; Internal helper to send the SPARQL query to the given HTTP endpoint and process the JSON response.
  ;; Construct a request
  (setv params { "query" query "format" "json"})
        
  ;; Call the API
  (setv response (requests.get endpoint :params params))
  (print response)        
  (setv json-data (response.json))
        
  (setv vars (get (get json-data "head") "vars"))
        
  (setv results (get json-data "results"))
        
  (if (in "bindings" results)
    (do
      (setv bindings (get results "bindings"))
      (print f"  Found {(len bindings)} results")
      (setv qr
            (lfor binding bindings
                (lfor var vars
                   [var (get (get binding var) "value")])))
      qr)
    (do
      (print "  No results found (empty bindings)")
      [])))

(defn wikidata-sparql [query]
  ;; Wrapper to execute a SPARQL query on the Wikidata endpoint.
  (do-query-helper wikidata-endpoint query))

(defn dbpedia-sparql [query]
  ;; Wrapper to execute a SPARQL query on the DBpedia endpoint.
  (do-query-helper dbpedia-endpoint query))

;;(print (dbpedia-sparql "select ?s ?p ?o { ?s ?p ?o } limit 4"))
