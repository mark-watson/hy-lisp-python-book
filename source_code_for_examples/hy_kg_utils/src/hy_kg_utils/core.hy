"Core runtime classes and functions for hy_kg_utils."

(import os)
(import pathlib [Path])

(deftype Triple (get tuple #(str str str)))
(deftype Row (get dict #(str str)))
(deftype MaybeStr (| str None))


(defn #^ str _clean-term [#^ str value #^ str field-name]
  "Strip whitespace and reject empty triple terms."
  (setv cleaned (.strip value))
  (when (= cleaned "")
    (raise (ValueError f"{field-name} must be a non-empty string")))
  cleaned)


(defclass GraphClient []
  "A small in-memory triple store with TSV import/export."

  (defn #^ None __init__ [self #^ MaybeStr [name None]]
    (setv default-name (os.environ.get "HY_KG_DEFAULT_GRAPH" "default"))
    (setv #^ str self.name (if (is name None) default-name name))
    (setv #^ (get list Triple) self._triples [])
    (setv #^ bool self.closed False))

  (defn #^ None _check-open [self]
    (when self.closed
      (raise (RuntimeError f"GraphClient '{self.name}' is closed"))))

  (defn #^ bool add [self #^ str s #^ str p #^ str o]
    "Add (s, p, o) if not already present. Return True when added."
    (._check-open self)
    (setv triple #((_clean-term s "subject")
                   (_clean-term p "predicate")
                   (_clean-term o "object")))
    (if (in triple self._triples)
        False
        (do
          (.append self._triples triple)
          True)))

  (defn #^ int add-many [self #^ (get list Triple) triples]
    "Add multiple triples and return the number of newly inserted triples."
    (._check-open self)
    (setv added 0)
    (for [[s p o] triples]
      (when (.add self s p o)
        (+= added 1)))
    added)

  (defn #^ int count [self]
    "Return the total number of stored triples."
    (len self._triples))

  (defn #^ (get list Triple) match [self
                                    #^ MaybeStr [s None]
                                    #^ MaybeStr [p None]
                                    #^ MaybeStr [o None]]
    "Return all triples matching the non-None subject, predicate, and object filters."
    (._check-open self)
    (lfor [ts tp to] self._triples
          :if (and (or (is s None) (= ts s))
                   (or (is p None) (= tp p))
                   (or (is o None) (= to o)))
          #(ts tp to)))

  (defn #^ (get list str) predicates [self]
    "Return sorted distinct predicate names."
    (._check-open self)
    (sorted (sfor [_ tp _] self._triples tp)))

  (defn #^ int save-tsv [self #^ Path path]
    "Write triples to a tab-separated file and return the row count."
    (._check-open self)
    (setv lines (lfor [s p o] self._triples f"{s}\t{p}\t{o}\n"))
    (.write-text (Path path) (.join "" lines) :encoding "utf-8")
    (len lines))

  (defn #^ int load-tsv [self #^ Path path]
    "Load triples from a tab-separated file and return the count of new triples."
    (._check-open self)
    (setv text (.read-text (Path path) :encoding "utf-8"))
    (setv added 0)
    (for [raw-line (.splitlines text)]
      (setv line (.strip raw-line))
      (when (and line (not (.startswith line "#")))
        (setv parts (.split line "\t"))
        (when (!= (len parts) 3)
          (raise (ValueError f"Expected 3 tab-separated columns, got: {raw-line}")))
        (when (.add self (get parts 0) (get parts 1) (get parts 2))
          (+= added 1))))
    added)

  (defn #^ None close [self]
    "Mark the client closed."
    (setv self.closed True)))


(defn #^ (get list Row) query->rows [#^ GraphClient client
                                     #^ MaybeStr [s None]
                                     #^ MaybeStr [p None]
                                     #^ MaybeStr [o None]]
  "Query client and return sorted dictionary rows with subject/predicate/object keys."
  (setv matches (sorted (.match client :s s :p p :o o)))
  (lfor [ts tp to] matches
        {"subject" ts
         "predicate" tp
         "object" to}))


(setv query-to-rows query->rows)


(export
  :objects [Triple Row MaybeStr GraphClient query->rows query-to-rows])
