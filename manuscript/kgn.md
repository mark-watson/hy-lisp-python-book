# Knowledge Graph Navigator {#kgn}

TBD: COPIED FROM COMMN LISP BOOK, FIX:

The Knowledge Graph Navigator (which I will often refer to as KGN) is a tool for processing a set of entity names and automatically exploring the public Knowledge Graph [DBPedia](http://dbpedia.org) using SPARQL queries. I started to write KGN for my own use, to automate some things I used to do manually when exploring Knowledge Graphs, and later thought that KGN might be useful also for educational purposes. KGN shows the user the auto-generated SPARQL queries so hopefully the user will learn by seeing examples. KGN uses NLP code developed in earlier chapters and we will reuse that code with a short review of using the APIs.

Please note that the example is a slightly simplified version that I first wrote in Common Lisp and is also an example in my book [Loving Common Lisp, or the Savvy Programmer's Secret Weapon](https://leanpub.com/lovinglisp) that you can read for free online.

After looking at generated SPARQL for an example query use of the application, we will start a process of bottom up development, first writing low level functions to automate SPARQL queries, writing utilities we will need for a text (console) based UI.

TBD: remove colorization stuff, if we aren't going to implement that

Some of the problems we will need to solve along the way will be colorizing the output the user sees in the UI and implementing a progress bar so the application user does not think the application is "hanging" while generating and making SPARQL queries to DBPedia.

Since the DBPedia queries are time consuming, we will also implement a caching layer using SQLite that will make the app more responsive. The cache is especially helpful during development when the same queries are repeatedly used for testing.

The code for this application is in the directory **kgn**. KGN is a long example application for a book and we will not go over all of the code. Rather, I hope to provide you with a roadmap overview of the code, diving in on code that you might want to reuse for your own projects and some representative code for generating SPARQL queries.

## Example Output

Before we get started studying the implementation, let's look at sample output in order to help give meaning to the code we will look at later. Consider a query that a user might type into the top query field in the KGN app:

        Steve Jobs lived near San Francisco and was
        a founder of \<http://dbpedia.org/resource/Apple_Inc.\>

The system will try to recognize entities in a query. If you know the DBPedia URI of an entity, like the company Apple in this example, you can use that directly. Note that in the SPARQL  URIs are surrounded with angle bracket characters.

The application prints out automatically generated SPARQL queries. For the above listed example query the following output will be generated (some editing to fit page width):

{linenos=off}
~~~~~~~~
~~~~~~~~

{lang="sparql",linenos=off}
~~~~~~~~

~~~~~~~~

{linenos=off}
~~~~~~~~
~~~~~~~~
{lang="sparql",linenos=off}
~~~~~~~~

~~~~~~~~
{linenos=off}
~~~~~~~~
~~~~~~~~
{lang="sparql",linenos=off}
~~~~~~~~

{linenos=off}
~~~~~~~~
DISCOVERED RELATIONSHIP LINKS:
~~~~~~~~

{lang="sparql",linenos=off}
~~~~~~~~
~~~~~~~~

After listing the generated SPARQL for finding information for the entities in the query, KGN searches for relationships between these entities. These discovered relationships can be seen at the end of the last listing. Please note that this step makes SPARQL queries on **O(n^2)** where **n** is the number of entities. Local caching of SPARQL queries to DBPedia helps make processing several entities possible.

In addition to showing generated SPARQL and discovered relationships in the middle text pane of the application, KGN also generates formatted results that are also displayed in the bottom text pane:

{linenos=off}
~~~~~~~~
~~~~~~~~

Hopefully after reading through sample output and seeing the screen shot of the application, you now have a better idea what this example application does. Now we will look at project configuration and then implementation.

When the KGN application starts a sample query is randomly chosen. Queries with many entities can take a while to process, especially when you first start using this application. Every time KGN makes a web service call to DBPedia the query and response are cached in a SQLite database in **kgn_hy_cache.db** which can greatly speed up the program, especially in development mode when testing a set of queries. This caching also takes some load off of the public DBPedia endpoint, which is a polite thing to do.

## Review of NLP Utilities Used in Application


TBD: update the following:

Here is a quick review of NLP utilities we saw earlier:

- kbnlp:make-text-object
- kbnlp::text-human-names
- kbnlp::text-place-name
- entity-uris:find-entities-in-text
- entity-uris:pp-entities

The following code snippets show example calls to the relevant NLP functions and the generated output:

{lang="hyping",linenos=off}
~~~~~~~~
~~~~~~~~

## Developing Low-Level Caching SPARQL Utilities

TBD

### Implementing the Caching Layer

While developing KGN and also using it as an end user, many SPARQL queries to DBPedia contain repeated entity names so it makes sense to write a caching layer.  We use a SQLite database "kgn_hy_cache.db" to store queries and responses.

The caching layer is implemented in the file **cache.hy**:

{lang="hyping",linenos=on}
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
(import os)
(import sys)
(import [pprint [pprint]])
(import requests)
(import pickle)
(require [hy.contrib.walk [let]])

(import [cache [fetch-result-dbpedia save-query-results-dbpedia]])

;;(setv query (get sys.argv 1)) ;; "select ?s ?p ?o { ?s ?p ?o } limit 2"

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

When I first had the basic functionality of KGN working, I was disappointed by how the application looked as normal text. Every editor and IDE I use colorizes text in an appropriate way so I took advantage of the function **capi::write-string-with-properties** to (fairly) easily implement color hilting SPARQL queries.

The code in the following listing is in the file **colorize.hy**.

TBD:


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

Here is an example call to function **colorize-sparql**:

{lang="hylang",linenos=off}
~~~~~~~~
~~~~~~~~


## Text Utilities for Queries and Results

The application low level utility functions are in the file **kgn-utils.hy**.

TBD

{lang="hylang",linenos=on}
~~~~~~~~
~~~~~~~~


## Wrap-up

This is a long example application for a book so I did not discuss all of the code in the project. If you enjoy running and experimenting with this example and want to modify it for your own projects then I hope that I provided a sufficient road map for you to do so.

I got the idea for the KGN application because I was spending quite a bit of time manually setting up SPARQL queries for DBPedia (and other public sources like WikiData) and I wanted to experiment with partially automating this process. I wrote the CAPI user interface for fun since this example application could have had similar functionality as a command line tool. In fact, my first cut implementation was a command line tool with the user interface in the file **ui-text** that we looked at earlier. I decided to remove the command line interface and replace it using CAPI.

Most of the Common Lisp development I do has no user interface or implements a web application. When I do need to write an application with a user interface, the LispWorks CAPI library makes writing user interfaces fairly easy to do.

If you are using an open source Common Lisp like SBCL or CCL and you want to add a user interface then you might want to also try [LTK](http://www.peter-herth.de/ltk/) and [McClim](https://www.cliki.net/McCLIM). McClim works well on Linux and also works on macOS with XQuartz but with fuzzy fonts. I also like [Radiance](https://github.com/Shirakumo/radiance) that spawns a web browser so you can package web applications as desktop applications.

If you are using CCL (Clojure Common Lisp) on macOS you can try the supported **COCOA-APPLICATION** package. This is only recommended if you already know the Cocoa APIs, otherwise this route has a very steep learning curve.
