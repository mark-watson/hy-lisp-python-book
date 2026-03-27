#!/usr/bin/env hy

;; sqlite_example.hy
;; Demonstrates common SQLite operations using the sqlite-lib wrapper.
;; The database is kept in memory (":memory:") so no file is created on disk.

(import sqlite-lib [create-db connection query])

(defn test_sqlite-lib []

  ;; --- Setup -----------------------------------------------------------
  ;; Open an in-memory SQLite database. Replace ":memory:" with a file
  ;; path like "people.db" to persist the data between runs.
  (setv conn (connection ":memory:"))

  ;; Create a table to hold people records.
  (query conn "CREATE TABLE people (name TEXT, email TEXT);")

  ;; --- Inserts ---------------------------------------------------------
  ;; Insert individual rows. INSERT returns an empty list because there
  ;; are no rows to fetch back.
  (print "Insert Mark:"
    (query conn "INSERT INTO people VALUES ('Mark', 'mark@markwatson.com')"))
  (print "Insert Kiddo:"
    (query conn "INSERT INTO people VALUES ('Kiddo', 'kiddo@markwatson.com')"))
  (print "Insert Alice:"
    (query conn "INSERT INTO people VALUES ('Alice', 'alice@example.com')"))
  (print "Insert Bob:"
    (query conn "INSERT INTO people VALUES ('Bob', 'bob@example.com')"))

  ;; --- Select all rows -------------------------------------------------
  (print "\nAll people after inserts:")
  (for [row (query conn "SELECT * FROM people")]
    (print " " row))

  ;; --- Parameterised query (WHERE with binding) ------------------------
  ;; Using ? placeholders with a binding list prevents SQL injection.
  (print "\nLookup by email:")
  (print
    (query conn "SELECT * FROM people WHERE email = ?"
      ["mark@markwatson.com"]))

  ;; --- Update ----------------------------------------------------------
  (print "\nUpdate Mark's name to 'Mark Watson':")
  (print
    (query conn "UPDATE people SET name = ? WHERE email = ?"
      ["Mark Watson" "mark@markwatson.com"]))

  ;; --- Select with ORDER BY --------------------------------------------
  (print "\nAll people ordered by name:")
  (for [row (query conn "SELECT * FROM people ORDER BY name ASC")]
    (print " " row))

  ;; --- Delete ----------------------------------------------------------
  (print "\nDelete Kiddo:")
  (print
    (query conn "DELETE FROM people WHERE name = ?" ["Kiddo"]))

  ;; --- Final state ------------------------------------------------------
  (print "\nAll people after delete:")
  (for [row (query conn "SELECT * FROM people ORDER BY name ASC")]
    (print " " row))

  ;; --- Aggregate query -------------------------------------------------
  ;; COUNT(*) returns a list with a single tuple containing the count.
  (setv [count-row] (query conn "SELECT COUNT(*) FROM people"))
  (print "\nTotal rows remaining:" (get count-row 0))

  ;; --- Close the connection --------------------------------------------
  (conn.close)
  (print "\nConnection closed."))

(test_sqlite-lib)
