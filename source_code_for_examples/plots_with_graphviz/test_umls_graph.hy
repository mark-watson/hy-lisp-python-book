;; Tests for UMLS_graph.hy  --  run with:  uv run pytest
;;
;; These tests check parsing and graph construction. They inspect the
;; generated DOT source, so the Graphviz `dot` program is not required.

(import sys)
(import UMLS-graph :as ug)


;; ---------- helpers ----------

(defn write-triples [tmp-path text]
  (setv path (/ tmp-path "sample.triples"))
  (.write-text path text)
  (str path))

(setv sample-text
  (+ "steroid\teicosanoid\tinteracts_with\n"
     "neoplastic_process\tdisease_or_syndrome\tisa\n"
     "malformed line\n"
     "\n"
     "carbohydrate\tmolecular_function\taffects\n"))


;; ---------- get-predicate-color ----------

(defn test-known-predicate-color []
  (assert (= (ug.get-predicate-color "isa") "#FF6B6B")))

(defn test-unknown-predicate-color-is-gray []
  (assert (= (ug.get-predicate-color "no_such_predicate") "#CCCCCC")))


;; ---------- parse-triples ----------

(defn test-parse-triples-skips-malformed-lines [tmp-path]
  (setv triples (ug.parse-triples (write-triples tmp-path sample-text) None None))
  (assert (= triples [#("steroid" "eicosanoid" "interacts_with")
                      #("neoplastic_process" "disease_or_syndrome" "isa")
                      #("carbohydrate" "molecular_function" "affects")])))

(defn test-parse-triples-limit [tmp-path]
  (setv triples (ug.parse-triples (write-triples tmp-path sample-text) 2 None))
  (assert (= (len triples) 2)))

(defn test-parse-triples-filter [tmp-path]
  (setv triples (ug.parse-triples (write-triples tmp-path sample-text) None "isa"))
  (assert (= triples [#("neoplastic_process" "disease_or_syndrome" "isa")])))

(defn test-parse-included-sample-file []
  (setv triples (ug.parse-triples "test.triples" None None))
  (assert (> (len triples) 0))
  (assert (all (gfor t triples (= (len t) 3)))))


;; ---------- build-graph ----------

(defn test-build-graph-source [tmp-path]
  (setv triples (ug.parse-triples (write-triples tmp-path sample-text) None None))
  (setv g (ug.build-graph triples "neato"))
  (assert (= g.engine "neato"))
  (assert (= g.format "pdf"))
  (setv src g.source)
  (assert (in "steroid -> eicosanoid" src))
  (assert (in "label=interacts_with" src))
  (assert (in "#4ECDC4" src))          ; interacts_with edge color
  (assert (in "cluster_legend" src))
  ;; every predicate in the palette appears in the legend
  (for [pred ug.PREDICATE-COLORS]
    (assert (in (+ "legend_" pred) src))))


;; ---------- parse-args ----------

(defn test-parse-args-defaults [monkeypatch]
  (monkeypatch.setattr sys "argv" ["UMLS_graph.hy"])
  (setv args (ug.parse-args))
  (assert (= args.input_file "test.triples"))
  (assert (= args.output "umls_graph"))
  (assert (= args.engine "dot"))
  (assert (not args.view))
  (assert (is args.limit None)))

(defn test-parse-args-options [monkeypatch]
  (monkeypatch.setattr sys "argv"
    ["UMLS_graph.hy" "-l" "5" "-f" "isa" "-e" "circo" "-o" "out" "in.triples"])
  (setv args (ug.parse-args))
  (assert (= [args.limit args.filter args.engine args.output args.input_file]
             [5 "isa" "circo" "out" "in.triples"])))
