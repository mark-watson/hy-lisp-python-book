(import sys)
(import subprocess)
(import pytest)
(import modern-features [
  reset-counters
  first-non-empty
  make-accumulator
  endpoints
  QueryEvent
  describe-event
  CYPHER-SAMPLE
  render-safe-query
  flatten-batches])
(import umls-modern [
  predicate-color
  parse-triple-lines
  summarize-triples])

(defn test-chained-setv-and-setx []
  (assert (= (reset-counters) {"hits" 0 "misses" 0 "errors" 0}))
  (assert (= (first-non-empty ["" "  " " alpha " "beta"]) "alpha"))
  (assert (= (first-non-empty ["   "]) "")))

(defn test-let-and-nonlocal []
  (setv acc (make-accumulator 10))
  (assert (= (acc 3) 13))
  (assert (= (acc -5) 8)))

(defn test-endpoints-and-match []
  (assert (= (endpoints #("s" "o" "p")) #("s" "o")))
  (assert (= (describe-event (QueryEvent "lookup" "isa"))
             "hierarchy lookup on isa"))
  (assert (= (describe-event (QueryEvent "lookup" "treats"))
             "lookup on treats"))
  (assert (= (describe-event (QueryEvent "limit" 5))
             "limit to 5 triples"))
  (assert (= (describe-event '(edge a b isa))
             "model edge: a -isa-> b"))
  (assert (= (describe-event ["a" "b" "isa"])
             "tuple edge: a -isa-> b")))

(defn test-bracket-and-template-strings []
  (assert (in "MATCH (s:Concept)" CYPHER-SAMPLE))
  (setv [sql params] (render-safe-query "isa" 50))
  (assert (= sql "SELECT subj, obj FROM triples WHERE pred = ? LIMIT ?"))
  (assert (= params #("isa" 50))))

(defn test-pep798-unpacking []
  (assert (= (flatten-batches [["x" "y"] [] ["z"]]) ["x" "y" "z"])))

(defn test-umls-modern-refactor []
  (setv lines
    ["# header"
     "a b isa"
     "b c part_of"
     "a c treats"
     "bad_line"])
  (setv all-triples (parse-triple-lines lines))
  (assert (= (len all-triples) 3))
  (setv isa-only (parse-triple-lines lines :filter-pred "isa"))
  (assert (= isa-only [#("a" "b" "isa")]))
  (setv summary (summarize-triples all-triples))
  (assert (= summary.triple-count 3))
  (assert (= summary.node-count 3))
  (assert (= (get summary.predicate-counts "isa") 1))
  (assert (= (predicate-color "isa") "#FF6B6B"))
  (assert (= (predicate-color "unknown") "#CCCCCC")))

(defn test-hy2py-translation []
  (setv res (subprocess.run ["uv" "run" "hy2py" "umls_modern.hy"]
                            :capture-output True :text True :check True))
  (assert (in "def parse_triple_lines" res.stdout))
  (assert (in "match pred:" res.stdout)))
