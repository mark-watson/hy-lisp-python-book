;; SQLite utility functions for Hy
(import sqlite3)

(defn create-db [db-file-path]
  "Create and open a database connection, then close it.
   Use ':memory:' for an in-memory database."
  (setv conn (sqlite3.connect db-file-path))
  (conn.close))

(defn connection [db-file-path]
  "Open and return a database connection.
   Use ':memory:' for an in-memory database."
  (sqlite3.connect db-file-path))

(defn query [conn sql #* args]
  "Execute SQL query with optional variable bindings.
   Returns all matching rows."
  (setv cur (conn.cursor))
  (cur.execute sql #* args)
  (cur.fetchall))

  