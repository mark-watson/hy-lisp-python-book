;; Tests for kgcreator.hy and kgcreator_uri.hy  --  run with:  uv run pytest
;;
;; These tests need the spaCy model:  uv run python -m spacy download en_core_web_sm
;; If the model is not installed the tests are skipped.

(import io [StringIO])
(import shutil)
(import pathlib [Path])
(import pytest)

(pytest.importorskip "en_core_web_sm"
  :reason "spaCy model en_core_web_sm is not installed")

(import kgcreator)
(import kgcreator-uri)

(setv test-data-dir (/ (. (Path __file__) parent) "test_data"))


(defn rdf-lines [module meta entities]
  (setv out (StringIO))
  (module.data2Rdf meta entities out)
  (.splitlines (.getvalue out)))


;; ---------- data2Rdf ----------

(defn test-data2rdf-literal-objects []
  (assert (= (rdf-lines kgcreator "https://ex.com/a" [["IBM" "ORG"] ["Paris" "GPE"]])
             ["<https://ex.com/a>\t<https://schema.org/Organization>\t\"IBM\" ."
              "<https://ex.com/a>\t<https://schema.org/location>\t\"Paris\" ."])))

(defn test-data2rdf-skips-unknown-entity-types []
  (assert (= (rdf-lines kgcreator "m" [["Monday" "DATE"] ["42" "CARDINAL"]]) [])))

(defn test-data2rdf-uri-version-maps-known-values-to-dbpedia []
  (assert (= (rdf-lines kgcreator-uri "https://ex.com/a" [["IBM" "ORG"] ["Acme" "ORG"]])
             ["<https://ex.com/a>\t<https://schema.org/Organization>\t<http://dbpedia.org/page/IBM> ."
              "<https://ex.com/a>\t<https://schema.org/Organization>\t\"Acme\" ."])))


;; ---------- find-entities-in-text ----------

(defn test-find-entities-in-text []
  (setv entities (list (kgcreator.find-entities-in-text
                         "Stock prices of IBM and Microsoft rose.\nBill Clinton spoke in Canada.")))
  (assert (in ["IBM" "ORG"] entities))
  (assert (in ["Bill Clinton" "PERSON"] entities))
  (assert (in ["Canada" "GPE"] entities)))

(defn test-find-entities-cleans-newlines []
  (setv entities (list (kgcreator.find-entities-in-text "He met Bill\nClinton yesterday.")))
  (assert (all (gfor [text _] entities (not-in "\n" text)))))


;; ---------- process-directory ----------

(defn test-process-directory-on-sample-data [tmp-path]
  (setv out (/ tmp-path "output.rdf"))
  (kgcreator.process-directory (str test-data-dir) (str out))
  (setv text (.read-text out))
  (assert (in "<https://localnews.com/june/z902.html>\t<https://schema.org/Organization>\t\"IBM\" ." text))
  (assert (in "<https://localnews.com/june/z902.html>\t<https://schema.org/Person>\t\"Bill Clinton\" ." text)))

(defn test-process-directory-uri-version [tmp-path]
  (setv out (/ tmp-path "output.rdf"))
  (kgcreator-uri.process-directory (str test-data-dir) (str out))
  (assert (in "<http://dbpedia.org/page/Microsoft>" (.read-text out))))

(defn test-process-directory-warns-about-missing-meta [tmp-path capsys]
  (setv data (/ tmp-path "data"))
  (.mkdir data)
  (.write-text (/ data "orphan.txt") "IBM is a company.")
  (setv out (/ tmp-path "output.rdf"))
  (kgcreator.process-directory (str data) (str out))
  (assert (in "Warning: no .meta file" (. (capsys.readouterr) out)))
  (assert (= (.read-text out) "")))
