;; Tests for p2t.hy  --  run with:  uv run pytest

(import pathlib [Path])
(import p2t [pdf2text])

(setv sample-pdf
  (/ (. (Path __file__) parent)
     "Sales force - Multi-Hop Knowledge Graph Reasoning with Reward Shaping.pdf"))


(defn test-pdf2text-returns-text []
  (setv text (pdf2text (str sample-pdf)))
  (assert (isinstance text str))
  (assert (> (len text) 1000)))

(defn test-pdf2text-finds-title-words []
  (setv text (.lower (pdf2text (str sample-pdf))))
  (assert (in "knowledge graph" text))
  (assert (in "reward shaping" text)))
