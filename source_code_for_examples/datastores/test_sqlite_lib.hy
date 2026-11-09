;; Tests for sqlite_lib.hy and postgres_lib.hy  --  run with:  uv run pytest
;;
;; The SQLite tests use real in-memory and on-disk databases. The PostgreSQL
;; tests use a fake psycopg2 module, so no database server is needed.

(import sqlite3)
(import sqlite-lib [create-db connection query])
(import pytest)


;; ---------- sqlite_lib ----------

(defn people-db []
  (setv conn (connection ":memory:"))
  (query conn "CREATE TABLE people (name TEXT, email TEXT);")
  (query conn "INSERT INTO people VALUES ('Mark', 'mark@markwatson.com')")
  (query conn "INSERT INTO people VALUES ('Kiddo', 'kiddo@markwatson.com')")
  conn)

(defn test-connection-returns-sqlite-connection []
  (setv conn (connection ":memory:"))
  (assert (isinstance conn sqlite3.Connection))
  (conn.close))

(defn test-create-db-creates-file [tmp-path]
  (setv db-path (/ tmp-path "test.db"))
  (create-db (str db-path))
  (assert (.exists db-path)))

(defn test-insert-returns-empty-list []
  (setv conn (connection ":memory:"))
  (query conn "CREATE TABLE t (x INTEGER);")
  (assert (= (query conn "INSERT INTO t VALUES (1)") [])))

(defn test-select-all []
  (assert (= (query (people-db) "SELECT * FROM people ORDER BY name")
             [#("Kiddo" "kiddo@markwatson.com")
              #("Mark" "mark@markwatson.com")])))

(defn test-query-with-bindings []
  (setv conn (people-db))
  (assert (= (query conn "SELECT name FROM people WHERE email = ?"
                    ["mark@markwatson.com"])
             [#("Mark")])))

(defn test-update-and-delete []
  (setv conn (people-db))
  (query conn "UPDATE people SET name = ? WHERE email = ?"
         ["Mark Watson" "mark@markwatson.com"])
  (query conn "DELETE FROM people WHERE name = ?" ["Kiddo"])
  (assert (= (query conn "SELECT name FROM people") [#("Mark Watson")]))
  (assert (= (query conn "SELECT COUNT(*) FROM people") [#(1)])))

(defn test-bad-sql-raises []
  (with [(pytest.raises sqlite3.OperationalError)]
    (query (connection ":memory:") "SELECT * FROM no_such_table")))

(defn test-sqlite-example-runs [capsys]
  (import sqlite-example)
  (sqlite-example.test_sqlite-lib)
  (setv out (. (capsys.readouterr) out))
  (assert (in "Mark Watson" out))
  (assert (in "Total rows remaining: 3" out)))


;; ---------- postgres_lib (fake psycopg2) ----------
;;
;; psycopg2 is not a dependency of this project, so a fake module is placed in
;; sys.modules before postgres_lib is imported.

(import sys types importlib)

(defclass FakeCursor []
  (defn __init__ [self] (setv self.calls []))
  (defn execute [self #* args] (.append self.calls args)))

(defclass FakeConnection []
  (defn __init__ [self #** kwargs] (setv self.kwargs kwargs))
  (defn cursor [self] (FakeCursor)))

(defn [pytest.fixture] postgres-lib [monkeypatch]
  (setv fake (types.ModuleType "psycopg2"))
  (setv fake.connect FakeConnection)
  (monkeypatch.setitem sys.modules "psycopg2" fake)
  (monkeypatch.delitem sys.modules "postgres_lib" :raising False)
  (importlib.import-module "postgres_lib"))

(defn test-postgres-connection-and-cursor [postgres-lib]
  (setv [conn cursor] (postgres-lib.connection-and-cursor "hybook" "markw"))
  (assert (= conn.kwargs {"dbname" "hybook" "user" "markw"}))
  (assert (isinstance cursor FakeCursor)))

(defn test-postgres-query-without-bindings [postgres-lib]
  (setv cur (FakeCursor))
  (postgres-lib.query cur "SELECT 1")
  (assert (= cur.calls [#("SELECT 1")])))

(defn test-postgres-query-with-bindings [postgres-lib]
  (setv cur (FakeCursor))
  (postgres-lib.query cur "SELECT %s" ["x"])
  (assert (= cur.calls [#("SELECT %s" ["x"])])))
