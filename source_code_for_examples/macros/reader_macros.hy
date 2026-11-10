;; reader_macros.hy -- Reader macros (#env, #sql, #json) using defreader.

(import dataclasses [dataclass])
(import json)
(import re)
(import sqlite3)
(import hy.models [Dict List String])


(defclass [(dataclass :frozen True)] SqlQuery []
  "A parameterized SQL query checked at read time."
  #^ str sql
  #^ tuple params)


(defn normalize-sql [raw-sql]
  "Collapse internal whitespace and strip leading/trailing spaces."
  (setv cleaned (.strip (re.sub r"\s+" " " (str raw-sql))))
  (when (not cleaned)
    (raise (SyntaxError "#sql query string cannot be empty")))
  cleaned)


(defn compile-sql-form [form]
  "Validate a #sql form at read time and return code constructing SqlQuery."
  (cond
    (isinstance form String)
      (do
        (setv sql-text (normalize-sql form)
              placeholders (.count sql-text "?"))
        (when (!= placeholders 0)
          (raise (SyntaxError
                   f"#sql string has {placeholders} '?' placeholders but no params list")))
        `(hy.I.reader_macros.SqlQuery ~sql-text #()))
    (and (isinstance form List) (>= (len form) 1) (isinstance (get form 0) String))
      (do
        (setv sql-text (normalize-sql (get form 0))
              params (list (cut form 1 None))
              placeholders (.count sql-text "?"))
        (when (!= placeholders (len params))
          (raise (SyntaxError
                   f"#sql has {placeholders} '?' placeholders but {(len params)} params")))
        `(hy.I.reader_macros.SqlQuery ~sql-text #(~@params)))
    True
      (raise (SyntaxError
               "#sql expects a string literal or [\"SQL ...\" param1 param2 ...]"))))


(defreader sql
  (setv form (.parse-one-form &reader))
  (hy.I.reader_macros.compile-sql-form form))


(defn compile-env-form [form]
  "Expand #env \"VAR\" or #env [\"VAR\" \"default\"] into os.environ.get."
  (cond
    (isinstance form String)
      `(hy.I.os.environ.get ~(str form))
    (and (isinstance form List) (= (len form) 2) (isinstance (get form 0) String))
      `(hy.I.os.environ.get ~(str (get form 0)) ~(get form 1))
    True
      (raise (SyntaxError
               "#env expects \"VAR\" or [\"VAR\" default-expr]"))))


(defreader env
  (setv form (.parse-one-form &reader))
  (hy.I.reader_macros.compile-env-form form))


(defn json-to-model [val]
  "Convert parsed JSON values into Hy models for zero-cost runtime literals."
  (cond
    (isinstance val dict)
      (do
        (setv pairs [])
        (for [[k v] (.items val)]
          (.extend pairs [(String k) (json-to-model v)]))
        (Dict pairs))
    (isinstance val list)
      (List (gfor item val (json-to-model item)))
    (isinstance val str)
      (String val)
    True val))


(defn compile-json-form [form]
  "Parse a JSON string literal at read time and emit a Hy data literal."
  (when (not (isinstance form String))
    (raise (SyntaxError "#json expects a string literal")))
  (try
    (setv parsed (json.loads (str form)))
    (except [err json.JSONDecodeError]
      (raise (SyntaxError f"Invalid #json literal: {err.msg}"))))
  (json-to-model parsed))


(defreader json
  (setv form (.parse-one-form &reader))
  (hy.I.reader_macros.compile-json-form form))


(defn execute-sql [conn query]
  "Execute a SqlQuery against a sqlite3 connection and return rows as dicts."
  (when (not (isinstance query SqlQuery))
    (raise (TypeError "execute-sql expects a SqlQuery value")))
  (setv cursor (.execute conn query.sql query.params)
        columns (if cursor.description
                    (lfor col cursor.description (get col 0))
                    []))
  (lfor row (.fetchall cursor)
    (dict (zip columns row))))
