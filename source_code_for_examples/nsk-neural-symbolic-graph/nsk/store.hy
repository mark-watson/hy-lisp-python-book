;; store.hy -- The triplestore: in-memory indices plus an append-only log.
;;
;; A triple is a tuple (subject predicate object). Three indices (by subject,
;; by predicate, by object) narrow every pattern to a small bucket, and each
;; bucket is a dict so that removing a triple costs O(1).
;;
;; Every triple has a source that records where it came from:
;;
;;   "fact"    you asserted it
;;   "neural"  the language model inferred it
;;   "rule"    a rule derived it (never logged; rebuilt from the rules)
;;
;; State survives restarts through a log of s-expressions, one per change:
;;
;;   (:add :mark :wrote :nsk)
;;   (:infer :mark :codes-in :lisp)
;;   (:rule [?x :grandparent ?z] [?x :parent ?y] [?y :parent ?z])
;;   (:del :mark :wrote :nsk)
;;
;; The log is read back with the Hy reader, which parses but never evaluates,
;; so a log file cannot run code.

(import os)
(import sys)
(import threading)
(import nsk.terms [Var Neural show ground? variables to-term to-pattern])

(setv RANK {"rule" 0  "neural" 1  "fact" 2})


(defn check-triple [triple]
  (setv triple (tuple triple))
  (when (or (!= (len triple) 3) (not (ground? triple)))
    (raise (ValueError f"a triple needs three ground terms: {(show triple)}")))
  triple)


(defclass Graph []
  "A knowledge graph. Pass a path to make it durable; with no path it lives
  only in memory."

  (defn __init__ [self [path None]]
    (setv self.triples {}        ; triple -> source, in insertion order
          self.spo {}            ; subject   -> {triple: None}
          self.pos {}            ; predicate -> {triple: None}
          self.osp {}            ; object    -> {triple: None}
          self.rules []          ; [(head, body) ...]
          self.stale False       ; True when rule-derived triples are out of date
          self.lock (threading.RLock)
          self.path (if path (str path) None)
          self.log None)
    (when self.path
      (setv torn (and (os.path.exists self.path) (self._replay)))
      (setv self.log (open self.path "a" :encoding "utf-8"))
      (when torn
        (self.compact)))     ; rewrite the log without the torn entry
    None)                    ; Hy returns the last form; __init__ must not

  (defn __len__ [self] (len self.triples))
  (defn __contains__ [self triple] (in (tuple triple) self.triples))
  (defn __enter__ [self] self)
  (defn __exit__ [self #* exc-info] (self.close))

  ;; ----- indexing (no logging) -----

  (defn _put [self triple source]
    (when (not-in triple self.triples)
      (for [[index key] (zip #(self.spo self.pos self.osp) triple)]
        (setv (get (.setdefault index key {}) triple) None)))
    (setv (get self.triples triple) source))

  (defn _drop [self triple]
    (del (get self.triples triple))
    (for [[index key] (zip #(self.spo self.pos self.osp) triple)]
      (setv bucket (get index key))
      (del (get bucket triple))
      (when (not bucket)
        (del (get index key)))))

  (defn candidates [self pattern]
    "Return the triples that could match pattern, using the smallest bucket
    among the positions that hold a concrete term."
    (setv buckets (lfor [index term] (zip #(self.spo self.pos self.osp) pattern)
                        :if (not (isinstance term #(Var Neural)))
                        (.get index term {})))
    (list (if buckets (min buckets :key len) self.triples)))

  ;; ----- mutation -----

  (defn add [self triple [source "fact"]]
    "Add a triple. Return True when the graph changed. Adding a triple that is
    already present only matters when the new source is stronger, as when you
    assert something the model had guessed."
    (setv triple (check-triple triple))
    (with [self.lock]
      (setv old (.get self.triples triple))
      (when (and old (>= (get RANK old) (get RANK source)))
        (return False))
      (self._put triple source)
      (when (!= source "rule")
        (setv self.stale True)
        (self._log (if (= source "neural") "infer" "add") #* triple))
      True))

  (defn add-all [self triples [source "fact"]]
    "Add several triples. Return the ones that were new."
    (lfor triple triples :if (self.add triple source) (tuple triple)))

  (defn remove [self triple]
    "Remove a triple. Return True when it was present."
    (setv triple (tuple triple))
    (with [self.lock]
      (when (not-in triple self.triples)
        (return False))
      (setv source (get self.triples triple))
      (self._drop triple)
      (when (!= source "rule")
        (setv self.stale True)
        (self._log "del" #* triple))
      True))

  (defn forget [self]
    "Remove every triple the model inferred. Return how many there were."
    (setv guesses (lfor [triple source] (list (.items self.triples))
                        :if (= source "neural") triple))
    (for [triple guesses]
      (self.remove triple))
    (len guesses))

  (defn facts [self [source None]]
    "Return [(triple, source) ...] in insertion order."
    (lfor [triple src] (.items self.triples)
          :if (or (is source None) (= src source))
          #(triple src)))

  ;; ----- rules -----

  (defn add-rule [self head body]
    "Add the rule head <- body. Each is a pattern; body is a list of them."
    (setv head (tuple head)
          body (tuple (map tuple body)))
    (when (not body)
      (raise (ValueError "a rule needs at least one body pattern")))
    (setv unbound (lfor v (variables head) :if (not-in v (variables body)) v))
    (when (or unbound (isinstance (get head 1) Neural))
      (raise (ValueError f"rule head {(show head)} must be built from its body")))
    (with [self.lock]
      (when (in #(head body) self.rules)
        (return False))
      (.append self.rules #(head body))
      (setv self.stale True)
      (self._log "rule" head #* body)
      True))

  (defn remove-rule [self index]
    "Remove the rule at index (as numbered by the REPL's :rules command)."
    (with [self.lock]
      (setv [head body] (.pop self.rules index)
            self.stale True)
      (self._log "unrule" head #* body)
      #(head body)))

  ;; ----- persistence -----

  (defn _log [self op #* terms]
    (when self.log
      (.write self.log (+ (entry op #* terms) "\n"))
      (.flush self.log)))

  (defn _apply [self form]
    (setv op (. (get form 0) name)
          args (list (cut form 1 None)))
    (cond
      (= op "add") (self._put (tuple (map to-term args)) "fact")
      (= op "infer") (self._put (tuple (map to-term args)) "neural")
      (= op "del")
        (do
          (setv triple (tuple (map to-term args)))
          (when (in triple self.triples)
            (self._drop triple)))
      (in op ["rule" "unrule"])
        (do
          (setv patterns (lfor arg args (to-pattern arg))
                rule #((get patterns 0) (tuple (cut patterns 1 None))))
          (if (= op "rule")
              (when (not-in rule self.rules) (.append self.rules rule))
              (when (in rule self.rules) (.remove self.rules rule))))
      True (raise (ValueError f"unknown log entry: {(hy.repr form)}"))))

  (defn _replay [self]
    "Rebuild the graph from the log. Return True when the log ends in a torn
    entry, which is what a crash in the middle of a write leaves behind."
    (with [f (open self.path :encoding "utf-8")]
      (setv text (.read f)))
    (setv torn False)
    (try
      (for [form (hy.read-many text)]
        (self._apply form))
      (except [hy.PrematureEndOfInput]
        (print f"; {self.path}: dropped an incomplete final entry" :file sys.stderr)
        (setv torn True)))
    (setv self.stale (bool self.rules))
    torn)

  (defn compact [self]
    "Rewrite the log so it holds only the live state. The new log replaces the
    old one in a single rename, so a crash leaves one or the other intact."
    (when (not self.path)
      (return 0))
    (with [self.lock]
      (setv lines (+ (lfor [triple source] (.items self.triples)
                           :if (!= source "rule")
                           (entry (if (= source "neural") "infer" "add") #* triple))
                     (lfor [head body] self.rules (entry "rule" head #* body)))
            temp (+ self.path ".tmp"))
      (with [f (open temp "w" :encoding "utf-8")]
        (.write f (.join "" (gfor line lines (+ line "\n")))))
      (when self.log
        (.close self.log))
      (os.replace temp self.path)
      (setv self.log (open self.path "a" :encoding "utf-8"))
      (len lines)))

  (defn save [self]
    "Force the log to disk."
    (when self.log
      (.flush self.log)
      (os.fsync (.fileno self.log))))

  (defn close [self]
    (when self.log
      (.close self.log)
      (setv self.log None))))


(defn entry [op #* terms]
  "Format one log entry, such as (:add :mark :wrote :nsk)."
  (+ "(:" op " " (.join " " (map show terms)) ")"))


;; ---------- the default graph ----------
;;
;; The ask and rule macros use this graph unless you pass :graph.

(setv _current None)

(defn current-graph []
  "Return the default graph, creating an in-memory one on first use."
  (global _current)
  (when (is _current None)
    (setv _current (Graph)))
  _current)

(defn use-graph [graph]
  "Make graph the default and return it."
  (global _current)
  (setv _current graph)
  graph)
