(import dataclasses [dataclass])
(import pathlib [Path])

(defclass [(dataclass :frozen True)] DocChunk []
  "A text chunk with provenance identifiers."
  #^ str doc-id
  #^ str chunk-id
  #^ str source-uri
  #^ str text)

(defn default-data-dir []
  (/ (. (Path __file__) parent) "data"))

(defn parse-document [path]
  "Read a bundled text document and return #(doc-id source-uri lines)."
  (setv raw (.strip (.read-text (Path path) :encoding "utf-8"))
        lines (lfor ln (.splitlines raw) :if (.strip ln) (.strip ln))
        doc-id (. (Path path) stem)
        source-uri f"https://example.org/docs/{doc-id}"
        body-lines [])
  (for [ln lines]
    (cond
      (.startswith ln "Document:")
      (setv doc-id (.strip ( get (.split ln ":" 1) 1)))
      (.startswith ln "Source:")
      (setv source-uri (.strip (get (.split ln ":" 1) 1)))
      True
      (.append body-lines ln)))
  (setv stem (. (Path doc-id) stem))
  #(stem source-uri body-lines))

(defn chunk-lines [doc-id source-uri lines [sentences-per-chunk 2]]
  "Group body lines into fixed-line-count chunks with stable IDs."
  (setv chunks []
        idx 0
        i 0)
  (while (< i (len lines))
    (setv group (cut lines i (+ i sentences-per-chunk))
          short-id (get (.split doc-id "_" 1) 0)
          chunk-id f"{short-id}#chunk{idx}"
          text (.join " " group))
    (.append chunks (DocChunk :doc-id doc-id
                              :chunk-id chunk-id
                              :source-uri source-uri
                              :text text))
    (setv idx (+ idx 1)
          i (+ i sentences-per-chunk)))
  chunks)

(defn load-corpus [[data-dir None] [sentences-per-chunk 2]]
  "Load all .txt documents from data-dir into a list of DocChunk objects."
  (setv root (if (is data-dir None) (default-data-dir) (Path data-dir))
        paths (sorted (.glob root "doc*.txt"))
        all-chunks [])
  (for [p paths]
    (setv #(doc-id source-uri body-lines) (parse-document p))
    (.extend all-chunks (chunk-lines doc-id source-uri body-lines sentences-per-chunk)))
  all-chunks)
