;; Tests for the nsk package  --  run with:  uv run pytest
;;
;; No Ollama daemon is needed: the one function that calls the model,
;; nsk.neural.chat-json, is replaced with a fake.

(import json)
(import threading)
(import urllib.request)
(import pytest)
(import nsk [Graph Var Neural use-graph show unify resolve to-keyword
             to-term to-pattern run-query])
(import nsk.neural)
(import nsk.repl [run-text make-namespace repl])
(import nsk.server [handle make-server])
(require nsk [ask rule])


;; ---------- helpers ----------

(defn authors-graph []
  (setv g (Graph))
  (g.add-all [[:mark :wrote :nsk] [:jane :wrote :nsk] [:mark :codes-in :lisp]])
  g)

(defn fake-model [monkeypatch replies]
  "Replace the model. replies maps a substring of the prompt to a reply dict.
  Returns the list of prompts received."
  (setv prompts [])
  (defn fake-chat-json [system prompt schema]
    (.append prompts prompt)
    (for [[fragment reply] (.items replies)]
      (when (in fragment prompt)
        (return reply)))
    {"result" None})
  (monkeypatch.setattr nsk.neural "chat_json" fake-chat-json)
  prompts)

(defn [(pytest.fixture :autouse True)] fresh-neural-state [monkeypatch]
  "Each test starts with an empty memo and no remembered outage."
  (monkeypatch.setattr nsk.neural "memo" {})
  (monkeypatch.setattr nsk.neural "_down_until" 0)
  (monkeypatch.setitem nsk.neural.config "enabled" True)
  (monkeypatch.setitem nsk.neural.config "cache" True))


;; ---------- terms and unification ----------

(defn test-unify-constants []
  (assert (is (unify ':a ':b) None))
  (assert (= (unify ':a ':a) {})))

(defn test-unify-binds-a-variable []
  (setv x (Var "x"))
  (assert (= (unify x ':mark) {x :mark}))
  (assert (= (unify ':mark x) {x :mark})))

(defn test-bound-variable-does-not-rebind []
  (setv x (Var "x"))
  (assert (is (unify x ':jane (unify x ':mark)) None)))

(defn test-unify-propagates-failure []
  (assert (is (unify ':a ':a None) None)))

(defn test-unify-patterns-and-resolve []
  (setv env (unify #((Var "s") :wrote (Var "o")) #(:mark :wrote :nsk)))
  (assert (= (resolve #((Var "o") (Var "s") (Var "free")) env)
             #(:nsk :mark (Var "free")))))

(defn test-unify-follows-variable-chains []
  (setv env (unify (Var "y") ':mark (unify (Var "x") (Var "y"))))
  (assert (= (resolve (Var "x") env) :mark)))

(defn test-unify-does-not-mutate-the-environment []
  (setv env {})
  (unify (Var "x") ':mark env)
  (assert (= env {})))

(defn test-to-keyword []
  (assert (= (to-keyword "  Common Lisp. ") :common-lisp))
  (assert (= (to-keyword "C++") :c++))
  (assert (is (to-keyword " ... ") None)))

(defn test-reader-forms-become-terms []
  (setv pattern (to-pattern (hy.read "[?person ~:wrote \"a b\"]")))
  (assert (= pattern #((Var "person") (Neural ':wrote) "a b")))
  (assert (is (type (get pattern 2)) str))
  (assert (= (show pattern) "[?person ~:wrote \"a b\"]")))

(defn test-bare-symbol-is-rejected-with-a-hint []
  (with [e (pytest.raises ValueError)]
    (to-term (hy.read "mark")))
  (assert (in ":mark" (str e.value))))


;; ---------- store ----------

(defn test-duplicates-are-ignored []
  (setv g (authors-graph))
  (assert (is (g.add [:mark :wrote :nsk]) False))
  (assert (= (len g) 3)))

(defn test-indices-and-insertion-order []
  (setv g (authors-graph))
  (assert (= (len (get g.spo :mark)) 2))
  (assert (= (len (get g.pos :wrote)) 2))
  (assert (= (len (get g.osp :lisp)) 1))
  (assert (= (get (g.facts) 0) #(#(:mark :wrote :nsk) "fact"))))

(defn test-remove-clears-every-index []
  (setv g (authors-graph))
  (assert (g.remove [:mark :codes-in :lisp]))
  (assert (not (g.remove [:mark :codes-in :lisp])))
  (assert (= (len g) 2))
  (assert (not-in :lisp g.osp))
  (assert (not-in :codes-in g.pos))
  (assert (= (len (get g.spo :mark)) 1)))

(defn test-candidates-use-the-smallest-bucket []
  (setv g (authors-graph))
  (assert (= (g.candidates #((Var "s") :wrote :nsk))
             [#(:mark :wrote :nsk) #(:jane :wrote :nsk)]))
  (assert (= (g.candidates #(:mark :codes-in (Var "o"))) [#(:mark :codes-in :lisp)]))
  (assert (= (g.candidates #(:nobody (Var "p") (Var "o"))) []))
  (assert (= (len (g.candidates #((Var "s") (Var "p") (Var "o")))) 3)))

(defn test-add-rejects-variables-and-wrong-lengths []
  (setv g (Graph))
  (with [(pytest.raises ValueError)] (g.add [:a :b (Var "x")]))
  (with [(pytest.raises ValueError)] (g.add [:a :b])))

(defn test-a-fact-outranks-a-guess []
  (setv g (Graph))
  (g.add [:mark :codes-in :lisp] "neural")
  (assert (is (g.add [:mark :codes-in :lisp] "neural") False))
  (assert (g.add [:mark :codes-in :lisp]))
  (assert (= (g.facts) [#(#(:mark :codes-in :lisp) "fact")]))
  (assert (is (g.add [:mark :codes-in :lisp] "neural") False))
  (assert (= (g.forget) 0)))


;; ---------- persistence ----------

(defn test-replay-rebuilds-the-graph [tmp-path]
  (setv path (/ tmp-path "g.log"))
  (with [g (Graph path)]
    (g.add [:a :b :c])
    (g.add [:d :e "two words"])
    (g.add [:n :is 42])
    (g.add [:x :guess :y] "neural")
    (g.remove [:a :b :c])
    (g.add-rule #((Var "o") :rev (Var "s")) [#((Var "s") :e (Var "o"))]))
  (assert (= (.splitlines (.read-text path))
             ["(:add :a :b :c)"
              "(:add :d :e \"two words\")"
              "(:add :n :is 42)"
              "(:infer :x :guess :y)"
              "(:del :a :b :c)"
              "(:rule [?o :rev ?s] [?s :e ?o])"]))
  (with [g (Graph path)]
    (assert (= (g.facts) [#(#(:d :e "two words") "fact")
                          #(#(:n :is 42) "fact")
                          #(#(:x :guess :y) "neural")]))
    (assert (not-in [:a :b :c] g))
    (assert (= (len g.rules) 1))
    (assert (= (. (run-query [#("two words" :rev (Var "s"))] :graph g) rows)
               [{"s" :d}]))))

(defn test-replay-never-evaluates-the-log [tmp-path]
  (setv path (/ tmp-path "g.log"))
  (.write-text path "(:add :a :b (print \"pwned\"))\n")
  (with [(pytest.raises ValueError)]
    (Graph path)))

(defn test-torn-final-entry-is-dropped-and-repaired [tmp-path capsys]
  (setv path (/ tmp-path "g.log"))
  (.write-text path "(:add :a :b :c)\n(:add :d :e")
  (with [g (Graph path)]
    (assert (= (len g) 1))
    (g.add [:x :y :z]))
  (assert (in "incomplete" (. (capsys.readouterr) err)))
  (assert (= (.splitlines (.read-text path)) ["(:add :a :b :c)" "(:add :x :y :z)"])))

(defn test-compact-keeps-only-live-state [tmp-path]
  (setv path (/ tmp-path "g.log"))
  (with [g (Graph path)]
    (for [n (range 10)]
      (g.add [:counter :is n])
      (g.remove [:counter :is n]))
    (g.add [:a :b :c])
    (assert (= (g.compact) 1))
    (g.add [:d :e :f]))
  (assert (= (.splitlines (.read-text path)) ["(:add :a :b :c)" "(:add :d :e :f)"])))


;; ---------- queries ----------

(defn test-single-pattern []
  (setv result (run-query [#((Var "who") :wrote :nsk)] :graph (authors-graph)))
  (assert (= (.column result "who") [:mark :jane]))
  (assert (= (str result) "who=:mark\nwho=:jane")))

(defn test-ask-joins-patterns []
  (use-graph (authors-graph))
  (setv result (ask [?a] [?a :wrote :nsk] [?a :codes-in :lisp]))
  (assert (= result.rows [{"a" :mark}])))

(defn test-ask-evaluates-ordinary-hy-in-patterns []
  (use-graph (authors-graph))
  (setv who ':jane)
  (assert (= (. (ask [?what] [who :wrote ?what]) rows) [{"what" :nsk}]))
  (assert (= (str (ask [] [who :wrote :nsk])) "yes"))
  (assert (= (str (ask [] [who :codes-in :lisp])) "no")))

(defn test-ask-options []
  (setv g (authors-graph))
  (use-graph (Graph))
  (assert (= (len (ask [?who] [?who :wrote :nsk])) 0))
  (assert (= (len (ask [?who] [?who :wrote :nsk] :graph g)) 2))
  (assert (= (len (ask [?who] [?who :wrote :nsk] :graph g :limit 1)) 1)))

(defn test-solutions-are-distinct []
  (setv g (authors-graph))
  (g.add [:mark :wrote :a-book])
  (assert (= (. (run-query [#((Var "a") :wrote (Var "b"))] [(Var "a")] :graph g) rows)
             [{"a" :mark} {"a" :jane}])))

(defn test-variable-in-predicate-position []
  (setv result (run-query [#(:mark (Var "p") (Var "o"))] :graph (authors-graph)))
  (assert (= result.rows [{"p" :wrote  "o" :nsk} {"p" :codes-in  "o" :lisp}])))


;; ---------- rules ----------

(defn family-graph []
  (setv g (use-graph (Graph)))
  (g.add-all [[:ann :parent :bob] [:bob :parent :cy] [:cy :parent :di]])
  (rule [?x :ancestor ?y]  [?x :parent ?y])
  (rule [?x :ancestor ?z]  [?x :parent ?y] [?y :ancestor ?z])
  g)

(defn test-recursive-rule-reaches-a-fixed-point []
  (family-graph)
  (setv result (ask [?d] [:ann :ancestor ?d]))
  (assert (= (set (.column result "d")) #{:bob :cy :di}))
  (assert (= (get result.support 0) #(#(#(:ann :ancestor :bob) "rule")))))

(defn test-derived-triples-follow-the-facts []
  (setv g (family-graph))
  (g.remove [:bob :parent :cy])
  (assert (= (.column (ask [?d] [:ann :ancestor ?d]) "d") [:bob]))
  (g.add [:bob :parent :cy])
  (assert (= (len (ask [?d] [:ann :ancestor ?d])) 3)))

(defn test-derived-triples-are-not-logged [tmp-path]
  (setv path (/ tmp-path "g.log"))
  (with [g (Graph path)]
    (g.add [:ann :parent :bob])
    (rule [?x :child ?y]  [?y :parent ?x] :graph g)
    (assert (= (len (ask [?c] [?c :child :ann] :graph g)) 1)))
  (assert (not-in ":bob :child" (.read-text path)))
  (with [g (Graph path)]
    (assert (= (len (ask [?c] [?c :child :ann] :graph g)) 1))))

(defn test-removing-a-rule-withdraws-its-conclusions []
  (setv g (family-graph))
  (g.remove-rule 1)
  (assert (= (.column (ask [?d] [:ann :ancestor ?d]) "d") [:bob])))

(defn test-rule-head-must-be-built-from-its-body []
  (with [(pytest.raises ValueError)]
    (.add-rule (Graph) #((Var "x") :knows (Var "stranger")) [#((Var "x") :is :here)])))


;; ---------- neural layer (fake model) ----------

(defn test-neural-predicate-prefers-stored-facts [monkeypatch]
  (setv prompts (fake-model monkeypatch {}))
  (use-graph (authors-graph))
  (setv result (ask [?l] [:mark ~:codes-in ?l]))
  (assert (= result.rows [{"l" :lisp}]))
  (assert (= result.support [#()]))
  (assert (= prompts [])))

(defn test-neural-fallback-infers-and-records-provenance [monkeypatch]
  (setv prompts (fake-model monkeypatch {"jane codes-in ???" {"result" "Python 3"}}))
  (setv g (use-graph (authors-graph)))
  (setv result (ask [?l] [:jane ~:codes-in ?l]))
  (assert (= result.rows [{"l" :python-3}]))
  (assert (= result.support [#(#(#(:jane :codes-in :python-3) "neural"))]))
  (assert (= (str result) "l=:python-3    ; neural: [:jane :codes-in :python-3]"))
  ;; the graph's own facts about jane were sent as context
  (assert (in "jane wrote nsk" (get prompts 0)))
  ;; the answer is stored, marked as inferred, and not asked for again
  (assert (= (g.facts "neural") [#(#(:jane :codes-in :python-3) "neural")]))
  (ask [?l] [:jane ~:codes-in ?l])
  (ask [?l] [:jane :codes-in ?l])
  (assert (= (len prompts) 1)))

(defn test-neural-fallback-can-supply-the-subject [monkeypatch]
  (fake-model monkeypatch {"??? capital-of france" {"result" "Paris"}})
  (use-graph (Graph))
  (assert (= (. (ask [?c] [?c ~:capital-of :france]) rows) [{"c" :paris}])))

(defn test-neural-fallback-inside-a-join [monkeypatch]
  (setv prompts (fake-model monkeypatch {"jane codes-in" {"result" "python"}}))
  (use-graph (authors-graph))
  (setv result (ask [?a ?l] [?a :wrote :nsk] [?a ~:codes-in ?l]))
  (assert (= result.rows [{"a" :mark  "l" :lisp} {"a" :jane  "l" :python}]))
  (assert (= (len prompts) 1)))

(defn test-model-may-decline-to-answer [monkeypatch]
  (setv prompts (fake-model monkeypatch {"jane" {"result" "Unknown"}}))
  (setv g (use-graph (authors-graph)))
  (assert (= (str (ask [?l] [:jane ~:codes-in ?l])) "no"))
  (assert (= (str (ask [?l] [:jane ~:codes-in ?l])) "no"))
  (assert (= (len prompts) 1))
  (assert (= (len g) 3)))

(defn test-neural-can-be-switched-off-per-query [monkeypatch]
  (setv prompts (fake-model monkeypatch {"jane" {"result" "python"}}))
  (use-graph (authors-graph))
  (assert (= (len (ask [?l] [:jane ~:codes-in ?l] :neural False)) 0))
  (assert (= prompts [])))

(defn test-cache-off-leaves-the-graph-alone [monkeypatch]
  (fake-model monkeypatch {"jane" {"result" "python"}})
  (monkeypatch.setitem nsk.neural.config "cache" False)
  (setv g (use-graph (authors-graph)))
  (assert (= (len (ask [?l] [:jane ~:codes-in ?l])) 1))
  (assert (= (len g) 3)))

(defn test-forget-removes-inferred-triples [monkeypatch]
  (fake-model monkeypatch {"jane" {"result" "python"}})
  (setv g (use-graph (authors-graph)))
  (ask [?l] [:jane ~:codes-in ?l])
  (assert (= (g.forget) 1))
  (assert (= (len g) 3)))

(defn test-query-fails-cleanly-when-the-model-is-unreachable [monkeypatch capsys]
  (setv calls [])
  (defn broken [system prompt schema]
    (.append calls prompt)
    (raise (ConnectionError "connection refused")))
  (monkeypatch.setattr nsk.neural "chat_json" broken)
  (use-graph (authors-graph))
  (assert (= (str (ask [?l] [:jane ~:codes-in ?l])) "no"))
  (assert (in "neural layer unavailable" (. (capsys.readouterr) err)))
  ;; a second query right away does not hammer the dead daemon
  (ask [?l] [:mark ~:lives-in ?l])
  (assert (= (len calls) 1)))

(defn test-extract-json-tolerates-wrapping []
  (assert (= (nsk.neural.extract-json "Sure!\n```json\n{\"result\": \"a {b}\"}\n```")
             {"result" "a {b}"}))
  (assert (is (nsk.neural.extract-json "no json here") None))
  (assert (is (nsk.neural.extract-json "{broken") None)))

(defn test-ingest-text [monkeypatch]
  (fake-model monkeypatch
    {"Mark" {"triples" [{"subject" "Mark"  "predicate" "wrote"  "object" "NSK"}
                        {"subject" "Mark"  "predicate" "codes in"  "object" "Common Lisp"}
                        {"subject" "Mark"  "predicate" "wrote"  "object" "nsk"}
                        {"subject" "Mark"  "predicate" "likes"}
                        "junk"]}})
  (setv g (Graph))
  (assert (= (nsk.neural.ingest "Mark wrote NSK in Common Lisp." g)
             [#(:mark :wrote :nsk) #(:mark :codes-in :common-lisp)]))
  (assert (= (len g) 2)))


;; ---------- REPL ----------

(defn run-repl [text [graph None]]
  (setv graph (if (is graph None) (Graph) graph))
  (setv [outputs done] (run-text text graph (make-namespace (use-graph graph))))
  #(graph outputs done))

(defn test-repl-commands-and-queries []
  (setv [g outputs done]
    (run-repl "(:add :mark :wrote :nsk)
               (:add :mark :codes-in :lisp)
               (:add :mark :wrote :nsk)
               [?who :wrote :nsk]
               (ask [?a] [?a :wrote :nsk] [?a :codes-in :lisp])
               :count
               (:del :mark :codes-in :lisp)
               :count"))
  (assert (= outputs ["added [:mark :wrote :nsk]"
                      "added [:mark :codes-in :lisp]"
                      "already known"
                      "who=:mark"
                      "a=:mark"
                      "2 triples"
                      "removed [:mark :codes-in :lisp]"
                      "1 triple"]))
  (assert (not done)))

(defn test-repl-joins-patterns-on-one-line []
  (setv [g outputs done]
    (run-repl "[?a :wrote :nsk] [?a :codes-in ?l]" (authors-graph)))
  (assert (= outputs ["a=:mark, l=:lisp"])))

(defn test-repl-rules-and-facts-listing []
  (setv [g outputs done]
    (run-repl "(:add :ann :parent :bob)
               (:rule [?c :child ?p] [?p :parent ?c])
               :rules
               :facts
               (:unrule 0)
               [?c :child ?p]"))
  (assert (= (cut outputs 1 None)
             ["rule added: [?c :child ?p] <- [?p :parent ?c]"
              "  0: [?c :child ?p] <- [?p :parent ?c]\n(1 rule)"
              "  [:ann :parent :bob]\n  [:bob :child :ann]    ; rule\n(2 triples)"
              "rule removed: [?c :child ?p] <- [?p :parent ?c]"
              "no"])))

(defn test-repl-evaluates-ordinary-hy []
  (setv [g outputs done]
    (run-repl "(setv n (len graph)) (+ n 40) (graph.add [:a :b :c]) :count"
              (authors-graph)))
  (assert (= outputs ["=> 43" "=> True" "4 triples"])))

(defn test-repl-reports-errors-and-keeps-going []
  (setv [g outputs done]
    (run-repl "(:add mark :wrote :nsk) (/ 1 0) :count :quit :count"))
  (assert (in "did you mean :mark" (get outputs 0)))
  (assert (in "division by zero" (get outputs 1)))
  (assert (= (cut outputs 2 None) ["0 triples"]))
  (assert done))

(defn test-repl-loop-reads-multi-line-forms [capsys]
  (setv lines (iter ["(:add :mark :wrote :nsk)" "(ask [?who]" "  [?who :wrote :nsk])" ":quit"])
        prompts [])
  (defn read-line [prompt]
    (.append prompts prompt)
    (next lines))
  (repl (Graph) read-line)
  (setv out (. (capsys.readouterr) out))
  (assert (in "who=:mark" out))
  (assert (.endswith out "Bye.\n"))
  (assert (= prompts ["nsk> " "nsk> " "...> " "nsk> "])))

(defn test-repl-loop-ends-at-end-of-input [capsys]
  (defn read-line [prompt]
    (raise (EOFError)))
  (repl (Graph) read-line)
  (assert (in "Bye." (. (capsys.readouterr) out))))


;; ---------- REST server ----------

(defn test-server-query-and-health []
  (setv g (authors-graph))
  (assert (= (handle g "POST" "/query" {"subject" None  "predicate" "wrote"  "object" "nsk"})
             #(200 {"count" 2
                    "results" [{"subject" "mark"} {"subject" "jane"}]
                    "provenance" []})))
  (assert (= (handle g "POST" "/query" {"subject" "?who"  "predicate" "Codes In"  "object" "?l"})
             #(200 {"count" 1  "results" [{"who" "mark"  "l" "lisp"}]  "provenance" []})))
  (setv [status payload] (handle g "GET" "/health" {}))
  (assert (= #(status (get payload "triples")) #(200 3))))

(defn test-server-ask-add-and-delete [monkeypatch]
  (fake-model monkeypatch {"jane codes-in" {"result" "python"}})
  (setv g (authors-graph))
  (assert (= (get (handle g "POST" "/triples"
                          {"subject" "jane"  "predicate" "wrote"  "object" "A Book"}) 1)
             {"added" True  "triples" 4}))
  (assert (in [:jane :wrote :a-book] g))
  (setv [status payload]
    (handle g "POST" "/ask" {"select" ["?a" "?l"]
                             "where" [["?a" "wrote" "nsk"] ["?a" "~codes-in" "?l"]]}))
  (assert (= (get payload "results") [{"a" "mark"  "l" "lisp"} {"a" "jane"  "l" "python"}]))
  (assert (= (get payload "provenance")
             [{"triple" ["jane" "codes-in" "python"]  "source" "neural"}]))
  (assert (= (get (handle g "DELETE" "/triples"
                          {"subject" "jane"  "predicate" "wrote"  "object" "a-book"}) 1)
             {"removed" True  "triples" 4}))
  (assert (= (get (handle g "GET" "/nowhere" {}) 0) 404)))

(defn test-server-over-http []
  (setv server (make-server (authors-graph) :port 0)
        url f"http://127.0.0.1:{(get server.server-address 1)}")
  (.start (threading.Thread :target server.serve-forever :daemon True))
  (defn call [path [body None]]
    (setv request (urllib.request.Request
                    (+ url path)
                    :data (if (is body None) None (.encode body "utf-8"))))
    (try
      (with [response (urllib.request.urlopen request :timeout 5)]
        #(response.status (json.loads (.read response))))
      (except [e urllib.error.HTTPError]
        #(e.code (json.loads (.read e))))))
  (try
    (assert (= (get (call "/health") 0) 200))
    (assert (= (get (get (call "/query" "{\"predicate\": \"wrote\", \"object\": \"nsk\"}") 1) "count") 2))
    (assert (= (get (call "/query" "not json") 0) 400))
    (assert (= (get (call "/query" "[1, 2]") 0) 400))
    (finally
      (server.shutdown)
      (server.server-close))))
