"Pytest suite written in Hy covering fixtures, parametrize, raises, monkeypatch, tmp_path, and macros."

(import pytest)
(import hy_kg_utils [GraphClient])
(import hy_kg_utils.core [query->rows])
(require hy_kg_utils.macros [with-graph])


(defn [(pytest.fixture)] seeded-client []
  "Provide a GraphClient preloaded with four sample triples."
  (setv client (GraphClient :name "fixture-graph"))
  (.add-many client
    [#("hy" "compiles-to" "python-ast")
     #("hy" "is-a" "lisp")
     #("uv" "manages" "packages")
     #("mypy" "checks" "types")])
  (yield client)
  (.close client))


(defn test-fixture-and-predicates [seeded-client]
  (assert (= (.count seeded-client) 4))
  (assert (= (.predicates seeded-client)
             ["checks" "compiles-to" "is-a" "manages"]))
  (assert (= (.add seeded-client "hy" "is-a" "lisp") False)))


(defn [(pytest.mark.parametrize
         "s,p,o,expected_count"
         [#("hy" None None 2)
          #(None "is-a" "lisp" 1)
          #("uv" "manages" None 1)
          #("unknown" None None 0)])]
  test-query-to-rows-parametrized [seeded-client s p o expected-count]
  (setv rows (query->rows seeded-client :s s :p p :o o))
  (assert (= (len rows) expected-count))
  (when (> expected-count 0)
    (assert (= (set (.keys (get rows 0)))
               #{"subject" "predicate" "object"}))))


(defn test-raises-on-empty-term-and-closed-client []
  (setv client (GraphClient))
  (with [(pytest.raises ValueError :match "subject must be a non-empty string")]
    (.add client "   " "is-a" "lisp"))
  (.close client)
  (with [(pytest.raises RuntimeError :match "is closed")]
    (.add client "hy" "is-a" "lisp"))
  (with [(pytest.raises RuntimeError :match "is closed")]
    (query->rows client)))


(defn test-monkeypatch-default-graph-name [monkeypatch]
  (.setenv monkeypatch "HY_KG_DEFAULT_GRAPH" "patched-kg")
  (setv client (GraphClient))
  (assert (= client.name "patched-kg")))


(defn test-tmp-path-tsv-roundtrip [seeded-client tmp-path]
  (setv tsv-file (/ tmp-path "graph.tsv"))
  (setv written (.save-tsv seeded-client tsv-file))
  (assert (= written 4))
  (assert (.exists tsv-file))

  (setv fresh (GraphClient :name "reloaded"))
  (setv loaded (.load-tsv fresh tsv-file))
  (assert (= loaded 4))
  (assert (= (query->rows fresh :s "hy")
             (query->rows seeded-client :s "hy")))

  (setv bad-file (/ tmp-path "bad.tsv"))
  (.write-text bad-file "only-two\tcolumns\n" :encoding "utf-8")
  (with [(pytest.raises ValueError :match "Expected 3 tab-separated columns")]
    (.load-tsv fresh bad-file)))


(defn test-with-graph-macro-closes-on-exit []
  (setv rows
    (with-graph [g [#("hy" "supports" "macros")
                    #("hy" "targets" "python")]]
      (.add g "pytest" "runs" "hy-tests")
      (query->rows g :s "hy")))
  (assert (= (len rows) 2))
  (assert (= (get (get rows 0) "predicate") "supports"))
  (assert (= g.closed True))

  (setv expanded (hy.repr (hy.macroexpand-1 '(with-graph [g] (.count g)))))
  (assert (in "GraphClient" expanded))
  (assert (in "finally" expanded)))
