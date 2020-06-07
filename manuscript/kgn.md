# Knowledge Graph Navigator {#kgn}

The Knowledge Graph Navigator (which I will often refer to as KGN) is a tool for processing a set of entity names and automatically exploring the public Knowledge Graph [DBPedia](http://dbpedia.org) using SPARQL queries. I wrote KGN in Common Lisp for my own use, to automate some things I used to do manually when exploring Knowledge Graphs, and later thought that KGN might be useful also for educational purposes. KGN uses NLP code developed in earlier chapters and we will reuse that code with a short review of using the APIs.

Please note that the example is a simplified version that I first wrote in Common Lisp and is also an example in my book [Loving Common Lisp, or the Savvy Programmer's Secret Weapon](https://leanpub.com/lovinglisp) that you can read for free online.

The following two screen shots show the text based user interface for this example. This example application asks the user for a list of entity names and uses SPARQL queries to discover potential matches in DBPedia. We use the python library [PyInquirer](https://github.com/CITGuru/PyInquirer) for requesting entity names and then to show the user a list of matches from DBPedia. The following screen shot shows these steps:

{width=70%}
![Initial user interaction with Knowledge Graph Navigator example](images/kgnuserselect.png)

To select the entities of interest, the user uses a space character to select or deselect an entity and the return (or enter) key to accept the list selections.

After the user selects entities from the list, the list disappears. The next screen shot shows the output from this example after the user finishes selecting entities of interest:

{width=70%}
![After the user selects entities of interest](images/kgnafter.png)

The code for this application is in the directory **kgn**. You will need to install the following Python library that supports console/text user interfaces:

    pip install PyInquirer

You will also need the **spacy** library and language model that we used in the earlier chapter on natural language processing. If you have not already done so install:

    pip install spacy
    python -m spacy download en_core_web_sm

After listing the generated SPARQL for finding information for the entities in the query, KGN searches for relationships between these entities. These discovered relationships can be seen at the end of the last screen shot. Please note that this step makes SPARQL queries on **O(n^2)** where **n** is the number of entities. Local caching of SPARQL queries to DBPedia helps make processing several entities possible.

Every time KGN makes a web service call to DBPedia the query and response are cached in a SQLite database in **~/.kgn_hy_cache.db** which can greatly speed up the program, especially in development mode when testing a set of queries. This caching also takes some load off of the public DBPedia endpoint, which is a polite thing to do.

## Review of NLP Utilities Used in Application

The NLP code we use is near the top of the file kgn.hy**"

{lang="hylang",linenos=off}
~~~~~~~~
(import spacy)

(setv nlp-model (spacy.load "en"))

(defn entities-in-text [s]
  (setv doc (nlp-model s))
  (setv ret {})
  (for
    [[ename etype] (lfor entity doc.ents [entity.text entity.label_])]
    
    (if (in etype ret)
        (setv (get ret etype) (+ (get ret etype) [ename]))
        (assoc ret etype [ename])))
  ret)
~~~~~~~~

Here is an example use of this function:

{linenos=off}
~~~~~~~~
=> (kgn.entities-in-text "Bill Gates, Microsoft, Seattle")
{'PERSON': ['Bill Gates'], 'ORG': ['Microsoft'], 'GPE': ['Seattle']}
~~~~~~~~

The entity type "GPE" indicates that the entity is some type of location.

## Developing Low-Level Caching SPARQL Utilities

While developing KGN and also using it as an end user, many SPARQL queries to DBPedia contain repeated entity names so it makes sense to write a caching layer.  We use a SQLite database "~/.kgn_hy_cache.db" to store queries and responses.

The caching layer is implemented in the file **cache.hy**:

{lang="hylang",linenos=on}
~~~~~~~~
(import [sqlite3 [connect version Error ]])
(import json)

(setv *db-path* "kgn_hy_cache.db")

(defn create-db []
  (try
    (setv conn (connect *db-path*))
    (print version)
    (setv cur (conn.cursor))
    (cur.execute "CREATE TABLE dbpedia (query string  PRIMARY KEY ASC, data json)")
    (conn.close)
    (except [e Exception] (print e))))

(defn save-query-results-dbpedia [query result]
  (try
    (setv conn (connect *db-path*))
    (setv cur (conn.cursor))
    (cur.execute "insert into dbpedia (query, data) values (?, ?)" [query (json.dumps result)])
    (conn.commit)
    (conn.close)
    (except [e Exception] (print e))))
 
(defn fetch-result-dbpedia [query]
  (setv results [])
  (setv conn (connect *db-path*))
  (setv cur (conn.cursor))
  (cur.execute "select data from dbpedia where query = ? limit 1" [query])
  (setv d (cur.fetchall))
  (if (> (len d) 0)
      (setv results (json.loads (first (first d)))))
  (conn.close)
  results)
 
(create-db)
~~~~~~~~

TBD

### SPARQL Utilities

TBD

{lang="hylang",linenos=on}
~~~~~~~~
(import json)
(import requests)
(require [hy.contrib.walk [let]])

(import [cache [fetch-result-dbpedia save-query-results-dbpedia]])

(setv wikidata-endpoint "https://query.wikidata.org/bigdata/namespace/wdq/sparql")
(setv dbpedia-endpoint "https://dbpedia.org/sparql")

(defn do-query-helper [endpoint query]
  ;; check cache:
  (setv cached-results (fetch-result-dbpedia query))
  (if (> (len cached-results) 0)
      (let ()
        (print "Using cached query results")
        (eval cached-results))
      (let ()
        ;; Construct a request
        (setv params { "query" query "format" "json"})
        
        ;; Call the API
        (setv response (requests.get endpoint :params params))
        
        (setv json-data (response.json))
        
        (setv vars (get (get json-data "head") "vars"))
        
        (setv results (get json-data "results"))
        
        (if (in "bindings" results)
            (let [bindings (get results "bindings")
                  qr
                  (lfor binding bindings
                        (lfor var vars
                              [var (get (get binding var) "value")]))]
              (save-query-results-dbpedia query qr)
              qr)
            []))))

(defn wikidata-sparql [query]
  (do-query-helper wikidata-endpoint query))

(defn dbpedia-sparql [query]
  (do-query-helper dbpedia-endpoint query))
~~~~~~~~
                      
This caching layer greatly speeds up my own personal use of KGN. Without caching, queries that contain many entity references simply take too long to run. The UI for the KGN application has a menu option for clearing the local cache but I almost never use this option because growing a large cache that is tailored for the types of information I search for makes the entire system much more responsive.

## Utilities to Colorize SPARQL and Generated Output

When I first had the basic functionality of KGN working, I was disappointed by how the application looked as normal text. Every editor and IDE I use colorizes text in an appropriate way so I used standard ANSI terminal escape sequences to implement color hilting SPARQL queries.

The code in the following listing is in the file **colorize.hy**.

{lang="hylang",linenos=on}
~~~~~~~~
(require [hy.contrib.walk [let]])
(import [io [StringIO]])

;; Utilities to add ANSI terminal escape sequences to colorize text.
;; note: the following 5 functions return string values that then need to
;;       be printed.

(defn blue [s] (.format "{}{}{}" "\033[94m" s "\033[0m"))
(defn red [s] (.format "{}{}{}" "\033[91m" s "\033[0m"))
(defn green [s] (.format "{}{}{}" "\033[92m" s "\033[0m"))
(defn pink [s] (.format "{}{}{}" "\033[95m" s "\033[0m"))
(defn bold [s] (.format "{}{}{}" "\033[1m" s "\033[0m"))

(defn tokenize-keep-uris [s]
  (.split s))

(defn colorize-sparql [s]
  (let [tokens
        (tokenize-keep-uris
          (.replace (.replace (.replace s "{" " { ") "}" " } ") "." " . "))
        ret (StringIO)] ;; ret is an output stream for a string buffer
    (for [token tokens]
      (if (> (len token) 0)
          (if (= (get token 0) "?")
              (.write ret (red token))
              (if (in
                    token
                    ["where" "select" "distinct" "option" "filter"
                     "FILTER" "OPTION" "DISTINCT" "SELECT" "WHERE"])
                  (.write ret (blue token))
                  (if (= (get token 0) "<")
                      (.write ret (bold token))
                      (.write ret token)))))
      (if (not (= token "?"))
          (.write ret " ")))
    (.seek ret 0)
    (.read ret)))
~~~~~~~~


## Text Utilities for Queries and Results

The application low level utility functions are in the file **kgn-utils.hy**.

TBD

{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import [sparql [dbpedia-sparql]])
(import [colorize [colorize-sparql]])

(import [pprint [pprint]])
(require [hy.contrib.walk [let]])

(defn dbpedia-get-entities-by-name [name dbpedia-type]
  (let [sparql
        (.format "select distinct ?s ?comment {{ ?s ?p \"{}\"@en . ?s <http://www.w3.org/2000/01/rdf-schema#comment>  ?comment  . FILTER  (lang(?comment) = 'en') . ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> {} . }} limit 15" name dbpedia-type)]
    (print "Generated SPARQL to get DBPedia entity URIs from a name:")
    (print (colorize-sparql sparql))
    (dbpedia-sparql sparql)))

;;(pprint (dbpedia-get-entities-by-name "Bill Gates" "<http://dbpedia.org/ontology/Person>"))
~~~~~~~~

Here is an example:

{width=70%}
![Getting entities by name with colorized SPARL query script](images/kgnutils.png)

## Finishing the Main Function for KGN

We already looked at the NLP code near the beginning of the file **kgn.hy**. Let's look at the remainder of the implementation.

{lang="hylang",linenos=on}
~~~~~~~~
(import spacy)

(setv nlp-model (spacy.load "en"))

(defn entities-in-text [s]
  (setv doc (nlp-model s))
  (setv ret {})
  (for
    [[ename etype] (lfor entity doc.ents [entity.text entity.label_])]
    
    (if (in etype ret)
        (setv (get ret etype) (+ (get ret etype) [ename]))
        (assoc ret etype [ename])))
  ret)
        

;;(print (entities-in-text "Bill Clinton, Canada, IBM, San Diego, Florida, Great Lakes, Bill Gates, Pepsi, John Smith, Google"))

(setv entity-type-to-type-uri
      {"PERSON" "<http://dbpedia.org/ontology/Person>"
       "GPE" "<http://dbpedia.org/ontology/Place>"
       "ORG" "<http://dbpedia.org/ontology/Organisation>"
       })
~~~~~~~~
   
When we get entity results from DBPedia, the comments describing entities can be a few paragraphs of text. We want to shorten the comments so they fit in a single line of the entity selection list that we have seen earlier. The following code defines a comment shortening function and also a global variable that we will use to store the entity URIs for each shortened comment:

{lang="hylang",linenos=on}
~~~~~~~~
(setv short-comment-to-uri {})

(defn shorten-comment [comment uri]
  (setv sc (+ (cut comment 0 70) "..."))
  (assoc short-comment-to-uri sc uri)
  sc)
~~~~~~~~
  
Finally, let's look at the main application loop:

{lang="hylang",linenos=on}
~~~~~~~~
(defn kgn []
  (while
    True
    (let [query (get-query)
          emap {}]
      (if (or (= query "quit") (= query "q"))
          (break))
      (setv elist (entities-in-text query))
      (setv people-found-on-dbpedia [])
      (setv places-found-on-dbpedia [])
      (setv organizations-found-on-dbpedia [])
      (global short-comment-to-uri)
      (setv short-comment-to-uri {})
      (for [key elist]
        (setv type-uri (get entity-type-to-type-uri key))
        (for [name (get elist key)]
          (setv dbp (dbpedia-get-entities-by-name name type-uri))
          (for [d dbp]
            (setv short-comment (shorten-comment (second (second d)) (second (first d))))
            (if (= key "PERSON")
                (.extend people-found-on-dbpedia [(+ name  " || " short-comment)]))
            (if (= key "GPE")
                (.extend places-found-on-dbpedia [(+ name  " || " short-comment)]))
            (if (= key "ORG")
                (.extend organizations-found-on-dbpedia [(+ name  " || " short-comment)])))))
      (setv user-selected-entities
            (select-entities
              people-found-on-dbpedia
              places-found-on-dbpedia
              organizations-found-on-dbpedia))
      (setv uri-list [])
      (for [entity (get user-selected-entities "entities")]
        (setv short-comment (cut entity (+ 4 (.index entity " || "))))
        (.extend uri-list [(get short-comment-to-uri short-comment)]))
      (setv relation-data (entity-results->relationship-links uri-list))
      (print "\nDiscovered relationship links:")
      (pprint relation-data))))
~~~~~~~~
  
## Wrap-up

If you enjoy running and experimenting with this example and want to modify it for your own projects then I hope that I provided a sufficient road map for you to do so.

I got the idea for the KGN application because I was spending quite a bit of time manually setting up SPARQL queries for DBPedia (and other public sources like WikiData) and I wanted to experiment with partially automating this process.