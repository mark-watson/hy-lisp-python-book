;; demo.hy -- A guided tour of NSK.  Run with:  uv run hy demo.hy
;;
;; Sections 1 to 4 are purely symbolic. Section 5 calls a local Ollama model
;; and is skipped with a note when no daemon is running.

(import os)
(import tempfile)
(import nsk [Graph use-graph config show])
(require nsk [ask rule])

(defn section [title]
  (print (+ "\n== " title " ==")))


(section "1. Facts and queries")

;; use-graph makes this graph the default for ask and rule.
(setv graph (use-graph (Graph)))

(graph.add-all [[:mark :wrote :nsk]
                [:jane :wrote :nsk]
                [:jane :wrote :a-book]
                [:mark :codes-in :lisp]
                [:jane :codes-in :python]])

(print "Who wrote NSK?")
(print (ask [?who] [?who :wrote :nsk]))

(print "Which NSK author codes in Lisp?")
(print (ask [?a] [?a :wrote :nsk] [?a :codes-in :lisp]))

;; A query result is a sequence of dicts, so it works with ordinary Hy code.
(setv result (ask [?who ?what] [?who :wrote ?what]))
(print "Rows:" (len result) " Authors:" (show (sorted (set (.column result "who")))))


(section "2. Hy values inside patterns")

;; Only ?variables and ~predicates are special. Everything else in a pattern
;; is evaluated, so a query can use local variables and function calls.
(for [language [:lisp :python :cobol]]
  (setv coders (ask [?who] [?who :codes-in language]))
  (print (show language) "->" (show (.column coders "who"))))


(section "3. Rules")

(graph.add-all [[:ann :parent :bob] [:bob :parent :cy] [:cy :parent :di]])

;; ancestor is the transitive closure of parent: a recursive rule.
(rule [?x :ancestor ?y]  [?x :parent ?y])
(rule [?x :ancestor ?z]  [?x :parent ?y] [?y :ancestor ?z])

(print "Ann's descendants (each answer names the derived triple behind it):")
(print (ask [?d] [:ann :ancestor ?d]))

(graph.remove [:bob :parent :cy])
(print "After removing [:bob :parent :cy]:")
(print (ask [?d] [:ann :ancestor ?d]))


(section "4. Persistence")

(with [folder (tempfile.TemporaryDirectory)]
  (setv path (os.path.join folder "demo.log"))
  (with [g (Graph path)]
    (g.add [:mark :wrote :nsk])
    (g.add [:mark :likes "hiking in Sedona"])
    (g.add [:mark :wrote :a-typo])
    (g.remove [:mark :wrote :a-typo])
    (rule [?book :author ?who]  [?who :wrote ?book] :graph g))
  (print "The log on disk:")
  (with [f (open path)]
    (print (.rstrip (.read f))))
  (with [g (Graph path)]
    (print "Reopened:" (len g) "triples," (len g.rules) "rule")
    (print (ask [?who] [:nsk :author ?who] :graph g))))


(section "5. Neural fallback (needs Ollama)")

(print f"Model: {(get config "model")}")

;; No :capital-of facts are stored, so the ~ predicates go to the model.
(graph.add-all [[:mark :visited :france] [:mark :visited :japan]])
(print "Capitals of the countries Mark visited:")
(print (ask [?country ?capital]
            [:mark :visited ?country]
            [?capital ~:capital-of ?country]))

;; Inferred triples are kept, marked as neural, so the model is asked once.
(print "What the model contributed:")
(for [[triple source] (graph.facts "neural")]
  (print " " (show triple)))

(print "The same query with the model switched off for this call:")
(print (ask [?capital] [?capital ~:capital-of :italy] :neural False))

(print f"Forgot {(graph.forget)} inferred triples.")
