# Datastores

I use flat files and the PostgreSQL relational database for most data storage and processing needs in my consulting business over the last twenty years. For work on large data projects at Compass Labs and Google I used Hadoop and Big Table. I will not cover big data datastores here, rather I will concentrate on what I think of as "laptop development" requirements: a modest amount of data and optimizing speed of development and ease of infrastructure setup. We will cover three datastores:

- Sqlite single-file-based relational database
- PostgreSQL relational database
- RDF library **rdflib** that is useful for semantic web and linked data applications

For graph data we will stick with RDF because it is a fairly widely used standard. Google, Microsoft, Yahoo and Yandex support [schema.org](https://schema.org/) for defining schemas for structured data on the web. In the next chapter we will go into more details on RDF, here we look at the "plumbing" for using the **rdflib** library to manipulate and query RDF data and how to export RDF data in several formats. Then in a later chapter, we will develop tools to automatically generate RDF data from raw text as a tool for developing customized Knowledge Graphs.

In one of my previous previous books [Loving Common Lisp, or the Savvy Programmer's Secret Weapon](https://leanpub.com/lovinglisp) I also covered the general purpose graph database Neo4j which I like to use for some use cases, but for the purposes of this book we stick with RDF.

## Sqlite

We will cover two relational databases: Sqlite and PostgreSQL. Sqlite is an embedded database. There are Sqlite libraries for many programming languages and here we use the Python library.

The following examples are simple but sufficient to show you how to open a single file Sqlite database, add data, modify data, query data, and delete data. I assume that you have some familiarity with relational databases, especially concepts like data columns and rows, and SQL queries.

Let's start with putting common code for using Sqlite into a reusable library in the file **sqlite_lib.hy**:

{lang="hylang",linenos=on}
~~~~~~~~
(import sqlite3)

(defn create-db [db-file-path] ;; db-file-path can also be ":memory:"
  (setv conn (sqlite3.connect db-file-path))
  (print version)
  (conn.close))

(defn connection [db-file-path] ;; db-file-path can also be ":memory:"
  (sqlite3.connect db-file-path))

(defn query [conn sql [variable-bindings None]]
  (setv cur (conn.cursor))
  (if variable-bindings
    (cur.execute sql variable-bindings)
    (cur.execute sql))
  (cur.fetchall))
~~~~~~~~

The function **create-db** in lines 3-6 creates a database from a file path if it does not already exist. The function **connection** (lines 8-9) creates a persistent connection to a database defined by a file path to the single file used for a Sqlite database. This connection can be reused.  The function **query** (lines 11-16) requires a connection object and a SQL query represented as a string, makes a database query, and returns all matching data in nested lists.

The following listing of file **sqlite_example.hy**shows how to use this simple library:


{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import sqlite-lib [create-db connection query])

(defn test_sqlite-lib []
  (setv conn (connection ":memory:")) ;; "test.db"))
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

We opened an in-memory database in lines 7 and 8 but we could have also created a persistent database on disk using, for example, "test_database.db" instead of **:memory**. In line 9 we create a database table with just two columns, each column holding string values.

In lines 15, 20, and 24 we are using a wild card query using the asterisk character to return all column values for each matched row in the database.

Running the example program produces the following output:

{lang="bash",linenos=on}
~~~~~~~~
$ ./sqlite_example.hy
2.6.0
[]
[]
[('Mark', 'mark@markwatson.com'), ('Kiddo', 'kiddo@markwatson.com')]
[]
[('Mark Watson', 'mark@markwatson.com'), ('Kiddo', 'kiddo@markwatson.com')]
[]
[('Mark Watson', 'mark@markwatson.com')]
~~~~~~~~

Line 2 shows the version of SQlite we are using. The lists in lines 1-2, 4, and 6 are empty because the functions to create a table, insert data into a table, update a row in a table, and delete rows do not return values.

In the next section we will see how PostgreSQL treats JSON data as a native data type. For sqlite, you can store JSON data as a "dumped" string value but you can't query by key/value pairs in the data. You can encode JSON as a string and then decode it back to JSON (or as a dictionary) using:

{lang="hylang",linenos=on}
~~~~~~~~
(import [json [dumps loads]])

(setv json-data .....)
(setv s-data (json.dumps json-data))
(setv restored-json-data (json.loads s-data))
~~~~~~~~



## PostgreSQL

We just saw use cases for the Sqlite embedded database. Now we look at my favorite general purpose database, PostgreSQL. The PostgreSQL database server is available as a managed service on most cloud providers and it is easy to also run a PostgreSQL server on your laptop or on a VPS or server.

We will use the [psycopg](http://initd.org/psycopg/) PostgreSQL adapter that is compatible with CPython and can be installed using:

        pip install psycopg2

The following material is self-contained but before using PostgreSQL and psycopg in your own applications I recommend that you reference the psycopg documentation.

### Notes for Using PostgreSQL and Setting Up an Example Database "hybook" on macOS and Linux

The following two sections may help you get PostgreSQL set up on macOS and Linux.

#### macOS

For macOS we use the PostgreSQL application and we will start by using the **postgres** command line utility to create a new database and table in this database. Using **postgres** account, create a new database **hybook**:

{lang="sql",linenos=on}
~~~~~~~~
Marks-MacBook:datastores $ psql -d "postgres"
psql (9.6.3)
Type "help" for help.

postgres=# \d
No relations found.
postgres=# CREATE DATABASE hybook;
CREATE DATABASE
postgres=# \q
Marks-MacBook:datastores $ 
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

#### Linux

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

When using Hy (or any other Lisp language and also for Haskell), I usually start both coding and experimenting with new libraries and APIs in a REPL. Let's do that here to see from a high level how we can use psycopg on the table **news** in the database **hybook** that we created in the last section:

{lang="hy",linenos=on}
~~~~~~~~
Marks-MacBook:datastores $ hy
=> (import json psycopg2)
=> (setv conn (psycopg2.connect :dbname "hybook" :user "markw"))
=> (setv cur (conn.cursor))
=> (cur.execute "INSERT INTO news VALUES (%s, %s, %s, %s)"
      ["http://knowledgebooks.com/schema" "test schema"
      "text in article" (json.dumps {"type" "news"})])
=> (conn.commit)
=> (cur.execute "SELECT * FROM news")
=> (for [record cur]
... (print record))
('http://knowledgebooks.com/schema', 'test schema', 'text in article',
 '{"type": "news"}')
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

In lines 6-8 and 13-14 you notice that I am using PostgreSQL's native JSON support.

As with most of the material in this book, I hope that you have a Hy REPL open and are experimenting with the APIs and code in the book's interactive REPL examples.

The file **postgres_lib.hy** wraps commonly used functionality for accessing a database, adding, modifying, and querying data in a short reusable library:

{lang="hy",linenos=on}
~~~~~~~~
(defn connection-and-cursor [dbname username]
  (setv conn (connect :dbname dbname :user username))
  (setv cursor (conn.cursor))
  [conn cursor])

(defn query [cursor sql [variable-bindings None]]
  (if variable-bindings
    (cursor.execute sql variable-bindings)
    (cursor.execute sql)))
~~~~~~~~

The function **query** in lines 8-11 executes any SQL comands so in addition to querying a database, it can also be used with appropriate SQL commands to delete rows, update rows, and create and destroy tables.

The following file **postgres_example.hy** contains examples for using the library we just defined:

{lang="hy",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import postgres-lib [connection-and-cursor query])

(defn test-postgres-lib []
  (setv [conn cursor] (connection-and-cursor "hybook" "markw"))
  (query cursor "CREATE TABLE people (name TEXT, email TEXT);")
  (conn.commit)
  (query cursor "INSERT INTO people VALUES ('Mark',  'mark@markwatson.com')")
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

Here is the output from this example Hy script:

{lang="bash",linenos=on}
~~~~~~~~
Marks-MacBook:datastores $ ./postgres_example.hy
[('Mark', 'mark@markwatson.com'), ('Kiddo', 'kiddo@markwatson.com')]
[('Kiddo', 'kiddo@markwatson.com'), ('Mark Watson', 'mark@markwatson.com')]
[('Mark Watson', 'mark@markwatson.com')]
~~~~~~~~

I use PostgreSQL more than any other datastore and taking the time to learn how to manage PostgreSQL servers and write application software will save you time and effort when you are prototyping new ideas or developing data oriented product at work. I love using PostgreSQL and personally, I only use Sqlite for very small database tasks or applications.

## RDF Data Using the "rdflib" Library  {#rdflibintro}

While the last two sections on Sqlite and PostgreSQL provided examples that you are likely to use in your own work, we will now turn to something more esoteric but still useful, the RDF notations for using data schema and RDF triple graph data in semantic web, linked data, and Knowledge Graph applications. I used graph databases working with Google's Knowledge Graph when I worked there and I have had several consulting projects using linked data. I currently work on the Knowledge Graph team at Olive AI. You will need to understand the material in this section for the two chapters that take a deeper dive into the semantic web and linked data and also develop an example that automatically creates Knowledge Graphs.

In my work I use RDF as a notation for graph data, RDFS (RDF Schema) to define formally data types and relationship types in RDF data, and occasionally OWL (Web Ontology Language) for reasoning about RDF data and inferring new graph triple data from data explicitly defined. Here we will only cover RDF since it is the most practical linked data tool and I refer you to my other semantic web books for deeper coverage of RDF as well as RDFS and OWL.

We will go into some detail on using semantic web and linked data resources in the next chapter. Here we will study the use of library **rdflib** as a data store, reading RDF data from disk and from web resources, adding RDF statements (which are triples containing a subject, predicate, and object) and for serializing an in-memory graph to a file in one of the standard RDF XML, turtle, or NT formats.

You need to install both the **rdflib** library and the plugin for using the JSON-LD format:

    pip install rdflib
    pip install rdflib-jsonld

The following REPL session shows importing the **rdflib** library, fetching RDF (in XML format) from my personal web site, printing out the triples in the graph in NT format, and showing how the graph can be queried. I added most of this RDF to my web site in 2005, with a few updates since then. The following REPL session is split up into several listings (with some long output removed) so I can explain how the **rdflib** is being used. In the first REPL listing I load an RDF file in XML format from my web site and print it in NT format. NT format can have either subject/predicate/object all on one line separated by spaces and terminated by a period or as shown below, the subject is on one line with predicate and objects printed indented on two additional lines. In both cases a period character "." is used to terminate search RDF NT statement. The statements are displayed in arbitrary order.

{lang="hy",linenos=on}
~~~~~~~~
Marks-MacBook:datastores $ hy
=> (import rdflib [Graph])
=> (setv graph (Graph))
=> (graph.parse "https://www.w3.org/2000/10/rdf-tests/RDF-Model-Syntax_1.0/ms_4.1_1.rdf")
=> (for [[subject predicate object] graph]
... (print subject "\n  " predicate "\n  " object " ."))
<Graph identifier=N2b392c0f8bf443e6ae48dd8b7cf5e949 (<class 'rdflib.graph.Graph'>)>
=> (for [[subject predicate object] graph] (print subject "\n  " predicate "\n  " object " ."))
N0606a4fc1dce4d79843ead3a26db6c76 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#type 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement  .
N0606a4fc1dce4d79843ead3a26db6c76 
   http://description.org/schema/attributedTo 
   Ralph Swick  .
N0606a4fc1dce4d79843ead3a26db6c76 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#object 
   Ora Lassila  .
N0606a4fc1dce4d79843ead3a26db6c76 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#subject 
   http://www.w3.org/Home/Lassila  .
N0606a4fc1dce4d79843ead3a26db6c76 
   http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate 
   http://description.org/schema/Creator  .
=> 
~~~~~~~~

There are several available formats for serializing RDF data. Here we will serialize using the JSON-LD format (later we will also see examples for serializing in NT and Turtle formats):

```hy
=> (import rdflib [plugin])
=> (import rdflib.serializer [Serializer])
=> (print (graph.serialize :format "json-ld" :indent 2))
[
  {
    "@id": "_:N0606a4fc1dce4d79843ead3a26db6c76",
    "@type": [
      "http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement"
    ],
    "http://description.org/schema/attributedTo": [
      {
        "@value": "Ralph Swick"
      }
    ],
    "http://www.w3.org/1999/02/22-rdf-syntax-ns#object": [
      {
        "@value": "Ora Lassila"
      }
    ],
    "http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate": [
      {
        "@id": "http://description.org/schema/Creator"
      }
    ],
    "http://www.w3.org/1999/02/22-rdf-syntax-ns#subject": [
      {
        "@id": "http://www.w3.org/Home/Lassila"
      }
    ]
  }
]
```

JSON-LD is convenient for implementing APIs that are intended for use by developers who are not familiar with RDF technology.

We will cover the SPARQL query language in more detail in the next chapter but for now, notice that SPARQL is similar to SQL queries. SPARQL queries can find triples in a graph matching simple patterns, match complex patterns, and update and delete triples in a graph. The following simple SPARQL query finds all triples with the predicate equal to <http://www.w3.org/2000/10/swap/pim/contact#company> and prints out the subject and object of any matching triples:

{lang="hy",linenos=on, number-from=84}
~~~~~~~~
=> (for [[subject object]
... (graph.query
...  "select ?subject ?object where { ?subject <http://description.org/schema/attributedTo> ?object }")]
... (print subject "attributedTo: " object))
N0606a4fc1dce4d79843ead3a26db6c76 attributedTo:  Ralph Swick
~~~~~~~~

We will see more examples of the SPARQL query language in the next chapter. For now, notice that the general form of a **select** query statement is a list of query variables (names beginning with a question mark) and a **where** clause in curly brackets that contains matching patterns. This SPARQL query is simple, but like SQL queries, SPARQL queries can get very complex. I only lightly cover SPARQL in this book. You can get PDF copies of my two older semantic web books for free: [Practical Semantic Web and Linked Data Applications, Java, Scala, Clojure, and JRuby Edition](https://markwatson.com/opencontentdata/book_java.pdf) and [Practical Semantic Web and Linked Data Applications, Common Lisp Edition](https://markwatson.com/opencontentdata/book_lisp.pdf). There are links to relevant git repos and other information on my [book web page](https://markwatson.com/books/).


In addition to the Turtle format I also use the simpler NT format that puts URI prefixes inline and unlike Turtle does not use prefix abrieviations. Here in line 159 we serialize to NT format:

{lang="hy",linenos=on, number-from=159}
~~~~~~~~
=> (graph.serialize :format "nt")
_:N0606a4fc1dce4d79843ead3a26db6c76
  <http://www.w3.org/1999/02/22-rdf-syntax-ns#type>
  <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> .
_:N0606a4fc1dce4d79843ead3a26db6c76
  <http://description.org/schema/attributedTo>
  "Ralph Swick\" .
_:N0606a4fc1dce4d79843ead3a26db6c76
  <http://www.w3.org/1999/02/22-rdf-syntax-ns#object>
  "Ora Lassila\" .
_:N0606a4fc1dce4d79843ead3a26db6c76
  <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject>
  <http://www.w3.org/Home/Lassila> .
_:N0606a4fc1dce4d79843ead3a26db6c76
  <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <http://description.org/schema/Creator> .
=> 
~~~~~~~~

Using RDFLIB with in-memory RDF triple storage is very convenient with small or mid-size RDF data sets as long as initializing the data store by reading a local file containing RDF triples is a fast operation. If I need to use large RDF data sets I prefer to not use rdflib and instead use SPARQL to access a free or open source standalone RDF data store like [OpenLink Virtuoso](https://en.wikipedia.org/wiki/Virtuoso_Universal_Server) or [GraphDB™ Free Edition](https://www.ontotext.com/products/graphdb/graphdb-free/). I also like and recommend the commercial AllegroGraph and Stardog RDF server products.


## Wrap-up

We will go into much more detail on practical uses of RDF and SPARQL in the next chapter. I hope that you worked through the REPL examples in this section because if you understand the basics of using the **rdflib** then you will have an easier time understanding the more abstract material in the next chapter.