;; Tests for the Knowledge Graph Navigator  --  run with:  uv run pytest
;;
;; DBpedia/Wikidata HTTP calls and keyboard input are replaced with fakes, so
;; no network access is needed. Tests of kgn.hy itself need the spaCy model
;; (uv run python -m spacy download en_core_web_sm) and are skipped without it.

(import builtins)
(import hy)
(import importlib)
(import pytest)
(import colorize)
(import sparql)
(import textui)
(import kgnutils)
(import relationships)


;; ---------- helpers ----------

(defclass FakeResponse []
  (defn __init__ [self payload] (setv self.payload payload))
  (defn json [self] self.payload))

(defn sparql-payload [vars rows]
  "Build a SPARQL JSON result; rows are lists of values in `vars` order."
  {"head" {"vars" vars}
   "results" {"bindings" (lfor row rows
                           (dfor [v val] (zip vars row) v {"type" "uri" "value" val}))}})

(defn fake-input [answers]
  (fn [[prompt ""]] (.pop answers 0)))


;; ---------- colorize.hy ----------

(defn test-color-wrappers []
  (assert (= (colorize.red "x") "\033[91mx\033[0m"))
  (assert (= (colorize.blue "x") "\033[94mx\033[0m"))
  (assert (= (colorize.bold "x") "\033[1mx\033[0m")))

(defn test-colorize-sparql []
  (setv out (colorize.colorize-sparql "select ?s {?s ?p <http://ex.com/T>}"))
  (assert (in (colorize.blue "select") out))
  (assert (in (colorize.red "?s") out))
  (assert (in (colorize.red "?p") out))
  (assert (in (colorize.bold "<http://ex.com/T>") out))
  (assert (in " { " out)))


;; ---------- sparql.hy ----------

(defn test-dbpedia-sparql-parses-bindings [monkeypatch]
  (setv captured {})
  (defn fake-get [url #** kwargs]
    (setv (get captured "url") url)
    (.update captured kwargs)
    (FakeResponse (sparql-payload ["s" "desc"] [["http://dbpedia.org/resource/X" "An X"]])))
  (monkeypatch.setattr sparql.requests "get" fake-get)
  (assert (= (sparql.dbpedia-sparql "select ?s ?desc {}")
             [[["s" "http://dbpedia.org/resource/X"] ["desc" "An X"]]]))
  (assert (= (get captured "url") "https://dbpedia.org/sparql"))
  (assert (= (get captured "params") {"query" "select ?s ?desc {}" "format" "json"})))

(defn test-wikidata-sparql-endpoint [monkeypatch]
  (setv urls [])
  (monkeypatch.setattr sparql.requests "get"
    (fn [url #** kw] (.append urls url) (FakeResponse (sparql-payload ["x"] []))))
  (assert (= (sparql.wikidata-sparql "q") []))
  (assert (= urls [sparql.wikidata-endpoint])))

(defn test-sparql-missing-bindings [monkeypatch]
  (monkeypatch.setattr sparql.requests "get"
    (fn [url #** kw] (FakeResponse {"head" {"vars" []} "results" {}})))
  (assert (= (sparql.dbpedia-sparql "q") [])))


;; ---------- kgnutils.hy ----------

(defn test-first-and-second []
  (assert (= (kgnutils.first [1 2 3]) 1))
  (assert (= (kgnutils.second [1 2 3]) 2)))

(defn test-dbpedia-get-entities-by-name-query [monkeypatch]
  (setv queries [])
  (monkeypatch.setattr kgnutils "dbpedia_sparql"
    (fn [q] (.append queries q) ["result"]))
  (assert (= (kgnutils.dbpedia-get-entities-by-name
               "Bill Gates" "<http://dbpedia.org/ontology/Person>")
             ["result"]))
  (setv q (get queries 0))
  (assert (in "?s ?p \"Bill Gates\"@en" q))
  (assert (in "<http://dbpedia.org/ontology/Person>" q))
  (assert (in "limit 15" q)))


;; ---------- textui.hy ----------

(defn test-select-entities [monkeypatch]
  (monkeypatch.setattr builtins "input" (fake-input ["1, 3, 9"]))
  (assert (= (textui.select-entities ["Bill Gates"] ["Seattle"] ["Microsoft"])
             ["Bill Gates" "Microsoft"])))   ; 9 is out of range and ignored

(defn test-select-entities-empty-input [monkeypatch]
  (monkeypatch.setattr builtins "input" (fake-input [""]))
  (assert (= (textui.select-entities ["a"] [] []) [])))

(defn test-get-query [monkeypatch]
  (monkeypatch.setattr builtins "input" (fake-input ["Bill Gates"]))
  (assert (= (textui.get-query) "Bill Gates")))


;; ---------- relationships.hy ----------

(defn test-dbpedia-get-relationships [monkeypatch]
  (setv queries [])
  (monkeypatch.setattr relationships "dbpedia_sparql"
    (fn [q] (.append queries q) [[["p" "http://dbpedia.org/ontology/founder"]]]))
  (setv rels (relationships.dbpedia-get-relationships "<http://a>" "<http://b>"))
  (assert (= rels [[["p" "http://dbpedia.org/ontology/founder"]]]))
  (assert (in "<http://a> ?p <http://b>" (get queries 0))))

(defn test-entity-results->relationship-links [monkeypatch]
  ;; only Gates -> Microsoft has a relationship
  (defn fake-rels [s o]
    (if (and (in "Gates" s) (in "Microsoft" o)) ["founder"] []))
  (monkeypatch.setattr relationships "dbpedia_get_relationships" fake-rels)
  (setv links (relationships.entity-results->relationship-links
                ["http://dbpedia.org/resource/Bill_Gates"
                 "http://dbpedia.org/resource/Microsoft"]))
  (assert (= links
             [["<http://dbpedia.org/resource/Bill_Gates>"
               "<http://dbpedia.org/resource/Microsoft>" "founder"]
              ;; the reverse query result is recorded from e1's point of view
              ["<http://dbpedia.org/resource/Microsoft>"
               "<http://dbpedia.org/resource/Bill_Gates>" "founder"]])))


;; ---------- kgn.hy (needs the spaCy model) ----------

(defn [pytest.fixture] kgn []
  (pytest.importorskip "en_core_web_sm"
    :reason "spaCy model en_core_web_sm is not installed")
  (importlib.import-module "kgn"))

(defn test-entities-in-text [kgn]
  (setv ents (kgn.entities-in-text "Bill Gates founded Microsoft in Seattle"))
  (assert (in "Bill Gates" (.get ents "PERSON" [])))
  (assert (in "Microsoft" (.get ents "ORG" [])))
  (assert (in "Seattle" (.get ents "GPE" []))))

(defn test-shorten-comment [kgn monkeypatch]
  (monkeypatch.setattr kgn "short_comment_to_uri" {})
  (setv sc (kgn.shorten-comment (* "a" 100) "http://dbpedia.org/resource/A"))
  (assert (= sc (+ (* "a" 70) "...")))
  (assert (= (get kgn.short-comment-to-uri sc) "http://dbpedia.org/resource/A")))

(defn test-kgn-loop [kgn monkeypatch capsys]
  (setv gates-uri "http://dbpedia.org/resource/Bill_Gates")
  (monkeypatch.setattr kgn "get_query" (fake-input ["Bill Gates" "quit"]))
  (monkeypatch.setattr kgn "dbpedia_get_entities_by_name"
    (fn [name type-uri]
      [[["s" gates-uri] ["desc" "American businessman and philanthropist"]]]))
  (monkeypatch.setattr kgn "select_entities"
    (fn [people places orgs] people))
  (setv seen-uris [])
  (monkeypatch.setattr kgn (hy.mangle "entity-results->relationship-links")
    (fn [uris] (.extend seen-uris uris) []))
  (kgn.kgn)
  (assert (= seen-uris [gates-uri]))
  (assert (in "Discovered relationship links" (. (capsys.readouterr) out))))
