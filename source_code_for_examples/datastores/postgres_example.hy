#!/usr/bin/env hy

(import postgres-lib [connection-and-cursor query])

(defn test-postgres-lib []
  "A demonstration of using postgres_lib to perform CRUD operations on a PostgreSQL database."
  
  ;; Establish connection and create a cursor
  ;; Note: Update "hybook" and "markw" to your local database and user
  (setv [conn cursor] (connection-and-cursor "hybook" "markw"))

  ;; Create a fresh table
  (query cursor "CREATE TABLE people (name TEXT, email TEXT);")
  (conn.commit)

  ;; Insert sample data
  (query cursor "INSERT INTO people VALUES ('Mark',  'mark@markwatson.com')")
  (query cursor "INSERT INTO people VALUES ('Kiddo', 'kiddo@markwatson.com')")
  (conn.commit)

  ;; Select and display all records
  (query cursor "SELECT * FROM people")
  (print "Initial records:" (cursor.fetchall))

  ;; Update a record using variable bindings for safety
  (query cursor "UPDATE people SET name = %s WHERE email = %s"
         ["Mark Watson" "mark@markwatson.com"])
  (conn.commit)

  ;; Verify the update
  (query cursor "SELECT * FROM people")
  (print "After update:" (cursor.fetchall))

  ;; Delete a record
  (query cursor "DELETE FROM people WHERE name = %s" ["Kiddo"])
  (conn.commit)

  ;; Verify the deletion
  (query cursor "SELECT * FROM people")
  (print "After delete:" (cursor.fetchall))

  ;; Cleanup: Drop the table and close connection
  (query cursor "DROP TABLE people;")
  (conn.commit)
  (conn.close))

(when (= __name__ "__main__")
  (test-postgres-lib))
