(import sys)
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

(defn main []
  (print "=== Modern Hy 1.3.1 Tour ===")
  (print "Python:" (get (.split sys.version) 0))
  (print "Counters:" (reset-counters))
  (print "First non-empty:" (first-non-empty ["   " "\n" "  hello hy 1.3  " "later"]))

  (setv acc (make-accumulator 10))
  (print "Accumulator steps:" (acc 5) (acc 7))

  (setv t #("aspirin" "headache" "treats"))
  (print "Endpoints:" (endpoints t))

  (for [ev [(QueryEvent "lookup" "isa")
            (QueryEvent "limit" 25)
            '(edge aspirin headache treats)
            ["cell" "nucleus" "has_part"]]]
    (print "Match:" (describe-event ev)))

  (print "Safe query:" (render-safe-query "isa" 10))
  (print "Flattened batches:" (flatten-batches [["a" "b"] ["c"] ["d" "e"]]))

  (setv sample-lines
    ["# comment line"
     "aspirin headache treats"
     "ibuprofen inflammation treats"
     "migraine headache isa"
     "aspirin stomach affects"])
  (setv triples (parse-triple-lines sample-lines))
  (setv summary (summarize-triples triples))
  (print "UMLS summary:" summary)
  (print "Color for 'isa':" (predicate-color "isa")))

(when (= __name__ "__main__")
  (main))
