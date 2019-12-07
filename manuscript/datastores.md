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

## Wrap Up

TBD

In the next chapter we will look at another way to organize data using the Resource Description Framework (RDF).