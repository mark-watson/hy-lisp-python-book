# Datastores

TBD



## Sqlite

TBD


Listing of **sqlite_lib.hy**:


{lang="hylang",linenos=on}
~~~~~~~~
(import [sqlite3 [connect version Error ]])

(defn create-db [db-file-path] ;; db-file-path can also be ":memory:"
  (setv conn (connect db-file-path))
  (print version)
  (conn.close))

(defn connection [db-file-path] ;; db-file-path can also be ":memory:"
  (connect db-file-path))

(defn query [conn sql &optional variable-bindings]
  (setv cur (conn.cursor))
  (if variable-bindings
    (cur.execute sql variable-bindings)
    (cur.execute sql))
  (cur.fetchall))
~~~~~~~~

Listing of **sqlite_example.hy**:


{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import [sqlite-lib [create-db connection query]])

(defn test_sqlite-lib []
  (setv dbpath ":memory:")
  (create-db dbpath)
  (setv conn (connection ":memory:"))
  (query conn "CREATE TABLE people (name TEXT, email TEXT);")
  (print
    (query conn "INSERT INTO people VALUES ('Mark', 'mark@markwatson.com')"))
  (print
    (query conn "INSERT INTO people VALUES ('Kiddo', 'kiddo@markwatson.com')"))
  (print
    (query conn "SELECT * FROM people"))
  (print
    (query conn "UPDATE people SET name = ? WHERE email = ?"
      ["Mark Watson" "mark@markwatson.com"]))
  (print
    (query conn "SELECT * FROM people"))
  (print
    (query conn "DELETE FROM people  WHERE name=?" ["Kiddo"]))
    (print
    (query conn "SELECT * FROM people"))
  (conn.close))

(test_sqlite-lib)
~~~~~~~~


Running te example program:


{lang="bash",linenos=on}
~~~~~~~~
Marks-MacBook:database $ ./sqlite_example.hy
2.6.0
[]
[]
[]
[('Mark Watson', 'mark@markwatson.com'), ('Kiddo', 'kiddo@markwatson.com')]
[]
[('Mark Watson', 'mark@markwatson.com')]
Marks-MacBook:database $ ./sqlite_example.hy
2.6.0
[]
[]
[('Mark', 'mark@markwatson.com'), ('Kiddo', 'kiddo@markwatson.com')]
[]
[('Mark Watson', 'mark@markwatson.com'), ('Kiddo', 'kiddo@markwatson.com')]
[]
[('Mark Watson', 'mark@markwatson.com')]
~~~~~~~~

In the next section we will see how PostgreSQL treats JSON data as a native data type. For sqlite, you can store JSON data as a "dumped" string value but you can't query by key/value pairs in the data. You can encode JSON as a string and then decode it back to JSON (or as a dictionary) using:

{lang="hylang",linenos=on}
~~~~~~~~
(import [json [dumps loads]])

(setv json-data .....)
(setv s-data (json.dumps json-data))
(setv restored-json-data (json.loads s-data))
~~~~~~~~



## PostgreSQL

TBD

We will use the [psycopg](http://initd.org/psycopg/) PostgreSQL adapter that is compatible with CPython and can be installed using:

        pip install psycopg2

### Notes for Using PostgreSQL and Setting Up an Example Database "hybook"

For macOS we use the PostgreSQL application and we will start by using the *postgres** command line utility to create a new database and table in this database. Using **postgres** account, create a new database **hybook**:

{lang="sql",linenos=on}
~~~~~~~~
Marks-MacBook:database $ psql -d "postgres"
psql (9.6.3)
Type "help" for help.

postgres=# \d
No relations found.
postgres=# CREATE DATABASE hybook;
CREATE DATABASE
postgres=# \q
Marks-MacBook:database $ 
~~~~~~~~


Create a table **news** in database **hybook**:

{lang="sql",linenos=on}
~~~~~~~~
markw $ psql -d "hybook"
psql (9.6.3)
Type "help" for help.

hybook=# CREATE TABLE news (uri VARCHAR(50) not null, title VARCHAR(50), articletext VARCHAR(500), nlpdata VARCHAR(50)); 
CREATE TABLE
hybook=# 
~~~~~~~~

For **Ubuntu** **Linux** first install PostgreSQL and then use **sudo** to use the account **postgres**:

To start a local server:

{lang="bash",linenos=on}
~~~~~~~~
sudo su - postgres
/usr/lib/postgresql/10/bin/pg_ctl -D /var/lib/postgresql/10/main -l logfile start
~~~~~~~~

and to stop the server:

{lang="bash",linenos=on}
~~~~~~~~
sudo su - postgres
/usr/lib/postgresql/10/bin/pg_ctl -D /var/lib/postgresql/10/main -l logfile stop
~~~~~~~~

When the PostgreSQL server is running we can use the **psql** command line program:

{lang="bash",linenos=on}
~~~~~~~~
sudo su - postgres
psql

postgres@pop-os:~$ psql -d "hybook"
psql (10.7 (Ubuntu 10.7-0ubuntu0.18.10.1))
Type "help" for help.

hybook=# CREATE TABLE news (uri VARCHAR(50) not null, title VARCHAR(50), articletext VARCHAR(500), nlpdata VARCHAR(50));
CREATE TABLE
hybook=# \d
        List of relations
 Schema | Name | Type  |  Owner   
--------+------+-------+----------
 public | news | table | postgres
(1 row)
~~~~~~~~

### Using Hy with PostgreSQL

When using Hy (or any other Lisp language and also for Haskell), I almost always start both coding and experimenting with new libraries and APIs in a REPL. Let's do that here to see from a high level how we can use psycopg on tabel **news** in the database **hybook** that we created in the last section:

{lang="hy",linenos=on}
~~~~~~~~
Marks-MacBook:database $ hy
hy 0.17.0+108.g919a77e using CPython(default) 3.7.3 on Darwin
=> (import json psycopg2)
=> (setv conn (psycopg2.connect :dbname "hybook" :user "markw"))
=> (setv cur (conn.cursor))
=> (cur.execute "INSERT INTO news VALUES (%s, %s, %s, %s)" ["http://knowledgebooks.com/schema" "test schema" "text in article" (json.dumps {"type" "news"})])
=> (conn.commit)
=> (cur.execute "SELECT * FROM news")
=> (for [record cur]
... (print record))
('http://knowledgebooks.com/schema', 'test schema', 'text in article', '{"type": "news"}')
=> (cur.execute "SELECT nlpdata FROM news")
=> (for [record cur]
... (print record))
('{"type": "news"}',)
=> (cur.execute "SELECT nlpdata FROM news")
=> (for [record cur]
... (print (json.loads (first record))))
{'type': 'news'}
=> 
~~~~~~~~

Listing of **postgres_lib.hy**:

{lang="hy",linenos=on}
~~~~~~~~
(import [psycopg2 [connect]])

(defn connection-and-cursor [dbname username]
  (setv conn (connect :dbname dbname :user username))
  (setv cursor (conn.cursor))
  [conn cursor])

(defn query [cursor sql &optional variable-bindings]
  (if variable-bindings
    (cursor.execute sql variable-bindings)
    (cursor.execute sql)))
~~~~~~~~


{lang="hy",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import [postgres-lib [connection-and-cursor query]])

(defn test-postgres-lib []
  (setv [conn cursor] (connection-and-cursor "hybook" "markw"))
  (query cursor "CREATE TABLE people (name TEXT, email TEXT);")
  (conn.commit)
  (query cursor "INSERT INTO people VALUES ('Mark', 'mark@markwatson.com')")
  (query cursor "INSERT INTO people VALUES ('Kiddo', 'kiddo@markwatson.com')")
  (conn.commit)
  (query cursor "SELECT * FROM people")
  (print (cursor.fetchall))
  (query cursor "UPDATE people SET name = %s WHERE email = %s"
      ["Mark Watson" "mark@markwatson.com"])
  (query cursor "SELECT * FROM people")
  (print (cursor.fetchall))
  (query cursor "DELETE FROM people  WHERE name = %s" ["Kiddo"])
  (query cursor "SELECT * FROM people")
  (print (cursor.fetchall))
  (query cursor "DROP TABLE people;")
  (conn.commit)
  (conn.close))

(test-postgres-lib)
~~~~~~~~


{lang="bash",linenos=on}
~~~~~~~~
Marks-MacBook:database $ ./postgres_example.hy
[('Mark', 'mark@markwatson.com'), ('Kiddo', 'kiddo@markwatson.com')]
[('Kiddo', 'kiddo@markwatson.com'), ('Mark Watson', 'mark@markwatson.com')]
[('Mark Watson', 'mark@markwatson.com')]
~~~~~~~~


## Neo4j Graph Database

TBD

## RDF Data Using the "rdflib" Library

TBD

TBD discuss how we only cover RDF, not RDF + OWL (recommend https://bitbucket.org/jibalamy/owlready2/src/default/ for OWL)

TBD reference next chapter on linked data

We will go into some detail on using semantic web and linked data resources in the next chapter. Here we will study the use of library **rdflib** as a data store, reading RDF data from disk and from web resources, adding RDF statements (which are triples containing a subject, predicate, and object) and for serializing an in memory graph to a file in one of the standard RDF XML, turtle, or NT formats.

The following REPL session shows importing the *rdflib** library, fetching RDF (in XML format) from my personal web wite, print out the triples i the graph in NT format, and showing how the graph can be queried. I added most of this RDF to my web site in 2005, with a few updates since then. The following REPL session is split up into several listings (with some long output removed) so I can explain how the **rdflib** is being used. In the first REPL listing I load an RDF file in XML format from my web site and print it in NT format. NT format can either have subject/predicate/object all on one line separated by spaces and terminated by a period, or, as shown below the subject is on one line with predicate and objects printed indented on two additional lines. In both cases a period character "." is used to terminate seach RDF NT statement. The statements are displayed in arbitrary order.

{lang="hy",linenos=on}
~~~~~~~~
Marks-MacBook:database $ hy
hy 0.17.0+108.g919a77e using CPython(default) 3.7.3 on Darwin
=> (import [rdflib [Graph]])
=> (setv graph (Graph))
=> (graph.load "http://markwatson.com/index.rdf")
=> (for [[subject predicate object] graph]
... (print subject "\n  " predicate "\n  " object " ."))
http://markwatson.com/index.rdf#mark_watson_consulting_services 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#label 
   Mark Watson Consulting Services  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/2000/10/swap/pim/contact#firstName 
   Mark  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.ontoweb.org/ontology/1#name 
   Mark Watson  .
http://www.markwatson.com/ 
   http://purl.org/dc/elements/1.1/language 
   en-us  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.ontoweb.org/ontology/1#researchTopic 
   Semantic Web  .
http://www.markwatson.com/ 
   http://purl.org/dc/elements/1.1/date 
   2005-7-10  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.ontoweb.org/ontology/1#researchTopic 
   RDF and RDF Schema  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.ontoweb.org/ontology/1#researchTopic 
   ontologies  .
http://www.markwatson.com/ 
   http://purl.org/dc/elements/1.1/title 
   Mark Watson's Home Page  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/2000/10/swap/pim/contact#mailbox 
   mailto:markw@markwatson.com  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/2000/10/swap/pim/contact#homepage 
   http://www.markwatson.com/  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/2000/10/swap/pim/contact#fullName 
   Mark Watson  .
http://markwatson.com/index.rdf#mark_watson_consulting_services 
   http://www.ontoweb.org/ontology/1#name 
   Mark Watson Consulting Services  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/2000/10/swap/pim/contact#company 
   Mark Watson Consulting Services  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#type 
   http://www.w3.org/2000/10/swap/pim/contact#Person  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#value 
   Mark Watson  .
http://www.markwatson.com/ 
   http://purl.org/dc/elements/1.1/creator 
   http://markwatson.com/index.rdf#mark_watson  .
http://www.markwatson.com/ 
   http://purl.org/dc/elements/1.1/description 
   
      Mark Watson is the author of 16 published books and a consultant specializing in artificial intelligence and Java technologies.
      .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#type 
   http://www.ontoweb.org/ontology/1#Person  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/2000/10/swap/pim/contact#motherTongue 
   en  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#type 
   http://markwatson.com/index.rdf#Consultant  .
http://markwatson.com/index.rdf#mark_watson_consulting_services 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#type 
   http://www.ontoweb.org/ontology/1#Organization  .
http://markwatson.com/index.rdf#mark_watson 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#label 
   Mark Watson  .
http://markwatson.com/index.rdf#Sun_ONE 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#type 
   http://www.ontoweb.org/ontology/1#Book  .
=> 
~~~~~~~~

We will cover the SPARQL query language in more detail in the next chapter but for now, notice that SPARQL is similar to SQL queries. SPARQL queries can find triples in a graph matching simple patterns, match complex patterns, and update and delete triples in a graph. TYhe following simple query finds all triples with the predicate equal to <http://www.w3.org/2000/10/swap/pim/contact#company> and prints ot the subject and object of any matching triples:

{lang="hy",linenos=on}
~~~~~~~~
=> (for [[subject object] (graph.query "select ?s ?o where { ?s <http://www.w3.org/2000/10/swap/pim/contact#company> ?o }")]
... (print subject " contact company: " object))
http://markwatson.com/index.rdf#mark_watson  contact company:  Mark Watson Consulting Services
~~~~~~~~

We will dive deeper into the SPARQL query language in the next chapter.

As I mentioned, the RDF data on my web site has been mostly unchanged since 2005. What if I wanted to update it noting that more recently I worked as a contractor at Google and as a deep learning engineering manager at Capital One? In the following listing, continuing the same REPL session, I will add two RDF statements indicating additional jobs and show how to serialize the new updated graph in three formats: XML, turtle (my favorite RDF notation) and NT:

{lang="hy",linenos=on}
~~~~~~~~
=> **(import rdflib)**
=> **(setv mark-node (rdflib.URIRef  "http://markwatson.com/index.rdf#mark_watson"))**
=> **mark-node**
rdflib.term.URIRef('http://markwatson.com/index.rdf#mark_watson')
=> **(graph.add [mark-node company-node (rdflib.Literal "Google")])**
=> **(graph.add [mark-node company-node (rdflib.Literal "Capital One")])**
=> (for [[subject object]
...       (graph.query
...         "select ?s ?o where { ?s <http://www.w3.org/2000/10/swap/pim/contact#company> ?o }")]
... (print subject " contact company: " object))
http://markwatson.com/index.rdf#mark_watson  contact company:  Mark Watson Consulting Services
http://markwatson.com/index.rdf#mark_watson  contact company:  Google
http://markwatson.com/index.rdf#mark_watson  contact company:  Capital One
=> 
=> **(graph.serialize :format "pretty-xml")**
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF\n  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:ow="http://www.ontoweb.org/ontology/1#"
  xmlns:ns1="http://markwatson.com/index.rdf#">

    LOTS	OF STUFF NOT SHOWN

</rdf:Description>\n</rdf:RDF>
~~~~~~~~



{lang="hy",linenos=on}
~~~~~~~~
=> **(graph.serialize :format "turtle")**
@prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix ns1: <http://markwatson.com/index.rdf#> .
@prefix ow: <http://www.ontoweb.org/ontology/1#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xml: <http://www.w3.org/XML/1998/namespace> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

s1:mark_watson_consulting_services a ow:Organization ;
    ow:name "Mark Watson Consulting Services" ;
    rdf:label "Mark Watson Consulting Services" .
<http://www.markwatson.com/> 
    dc:creator ns1:mark_watson ;
    dc:date "2005-7-10" ;
    dc:description 
          "Mark Watson is the author of 16 published books and a consultant
          specializing in artificial intelligence and Java technologies." ;
     dc:format "text/html" ;
     dc:language "en-us" ;
     dc:title "Mark Watson\'s Home Page" ;
     dc:type "Consultant Homepage" .
ns1:mark_watson a ns1:Consultant,
                  ow:Person,
                  contact:Person ;
                ow:name "Mark Watson" ;
                ow:researchTopic "RDF and RDF Schema",
                                 "Semantic Web",
                                 "ontologies" ;
                rdf:label "Mark Watson" ;
                rdf:value "Mark Watson" ;
                contact:company "Capital One",
                                "Google",
                                "Mark Watson Consulting Services" ;
                contact:familyName "Watson" ;
                contact:firstName "Mark" ;
                contact:fullName "Mark Watson" ;
                contact:homepage <http://www.markwatson.com/> ;
                contact:mailbox <mailto:markw@markwatson.com> ;
                contact:motherTongue "en" .
~~~~~~~~




{lang="hy",linenos=on}
~~~~~~~~
=> **(graph.serialize :format "nt")**
<http://markwatson.com/index.rdf#Sun_ONE> <http://www.ontoweb.org/ontology/1#booktitle> "Sun ONE Services - J2EE" .
<http://www.markwatson.com/> <http://purl.org/dc/elements/1.1/language> "en-us" .
<http://markwatson.com/index.rdf#Sun_ONE> <http://www.ontoweb.org/ontology/1#author> <http://markwatson.com/index.rdf#mark_watson> .
<http://www.markwatson.com/> <http://purl.org/dc/elements/1.1/date> "2005-7-10" .
<http://markwatson.com/index.rdf#mark_watson> <http://www.ontoweb.org/ontology/1#researchTopic> "ontologies" .
<http://www.markwatson.com/> <http://purl.org/dc/elements/1.1/type> "Consultant Homepage" .
<http://markwatson.com/index.rdf#mark_watson> <http://www.w3.org/2000/10/swap/pim/contact#homepage> <http://www.markwatson.com/> .
<http://markwatson.com/index.rdf#mark_watson> <http://www.w3.org/2000/10/swap/pim/contact#company> "Google" .
<http://markwatson.com/index.rdf#mark_watson> <http://www.w3.org/2000/10/swap/pim/contact#company> "Capital One" .
<http://markwatson.com/index.rdf#mark_watson> <http://www.ontoweb.org/ontology/1#researchTopic> "Semantic Web" .
<http://markwatson.com/index.rdf#mark_watson> <http://www.ontoweb.org/ontology/1#researchTopic> "RDF and RDF Schema" .
<http://www.markwatson.com/> <http://purl.org/dc/elements/1.1/title> "Mark Watson\'s Home Page" .
<http://markwatson.com/index.rdf#mark_watson> <http://www.w3.org/2000/10/swap/pim/contact#mailbox> <mailto:markw@markwatson.com> .
<http://www.markwatson.com/> <http://purl.org/dc/elements/1.1/format> "text/html" .
<http://markwatson.com/index.rdf#mark_watson> <http://www.w3.org/2000/10/swap/pim/contact#fullName> "Mark Watson" .
<http://markwatson.com/index.rdf#mark_watson> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2000/10/swap/pim/contact#Person> .
<http://www.markwatson.com/> <http://purl.org/dc/elements/1.1/creator> <http://markwatson.com/index.rdf#mark_watson> .

      LOTS	OF STUFF NOT SHOWN
=> 
~~~~~~~~

We will go into much more detail on practical uses of RDF and SPARQL in the next chapter. I hope that you worked through the REPL examples in this section because if you understand the basics of using the **rdflib** then you will have an easier time understanding the more abstract material in the next chapter.