(import psycopg2 [connect])

(defn connection-and-cursor [dbname username]
  "Establish a PostgreSQL connection and return both the connection and a cursor.
   
   Args:
     dbname (str): The name of the database to connect to.
     username (str): The database user.
     
   Returns:
     list: [connection, cursor]"
  (setv conn (connect :dbname dbname :user username))
  (setv cursor (conn.cursor))
  [conn cursor])

(defn query [cursor sql [variable-bindings None]]
  "Execute a SQL query using the provided cursor, optionally with variable bindings.
   
   Args:
     cursor: The database cursor to use.
     sql (str): The SQL statement to execute.
     variable-bindings (optional): A collection of values to bind to the SQL query."
  (if variable-bindings
      (cursor.execute sql variable-bindings)
      (cursor.execute sql)))
