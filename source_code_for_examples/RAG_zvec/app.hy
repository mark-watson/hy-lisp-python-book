(import os)
(import json)
(import urllib.request)
(import pathlib [Path])
(import zvec)

;; Configuration
(setv config
  {"data_dir"        (os.getenv "DATA_DIR" "../data")
   "extensions"      #(".txt")
   "embedding_model" (os.getenv "EMBEDDING_MODEL" "embeddinggemma")
   "chat_model"      (os.getenv "CHAT_MODEL" "qwen3:1.7b")})

(setv OLLAMA-BASE "http://localhost:11434")


(defn get-embedding [text]
  "Get embedding from local Ollama instance."
  (setv url f"{OLLAMA-BASE}/api/embeddings")
  (setv data
    (.encode
      (json.dumps {"model"  (get config "embedding_model")
                   "prompt" text})
      "utf-8"))
  (setv req
    (urllib.request.Request url :data data
      :headers {"Content-Type" "application/json"}))
  (try
    (with [res (urllib.request.urlopen req)]
      (get (json.loads (.decode (.read res) "utf-8")) "embedding"))
    (except [e Exception]
      (print f"Error calling Ollama embeddings: {e}")
      (* [0.0] 768))))


(defn chunk-text [text [chunk-size 500] [overlap 50]]
  "Split text into overlapping chunks."
  (setv chunks [])
  (setv start 0)
  (while (< start (len text))
    (setv end (+ start chunk-size))
    (.append chunks (cut text start end))
    (setv start (- end overlap)))
  chunks)


(defn build-index []
  "Index all text files from the data directory into zvec."
  ;; Define collection schema (embeddinggemma: 768 dimensions)
  (setv schema
    (zvec.CollectionSchema
      :name    "example"
      :vectors (zvec.VectorSchema "embedding" zvec.DataType.VECTOR-FP32 768)
      :fields  (zvec.FieldSchema  "text"      zvec.DataType.STRING)))

  (setv db-path "./zvec_example")
  (when (os.path.exists db-path)
    (import shutil)
    (shutil.rmtree db-path))

  (setv collection (zvec.create-and-open :path db-path :schema schema))

  (setv docs [])
  (setv doc-count 0)
  (for [[root _ files] (os.walk (get config "data_dir"))]
    (for [file files]
      (when (.endswith (.lower file) (get config "extensions"))
        (try
          (setv file-path (/ (Path root) file))
          (with [f (open file-path "r" :encoding "utf-8")]
            (setv content (.read f)))
          (setv chunks (chunk-text content))
          (for [[i chunk] (enumerate chunks)]
            (setv embedding (get-embedding chunk))
            (.append docs
              (zvec.Doc
                :id      f"{file}_{i}"
                :vectors {"embedding" embedding}
                :fields  {"text" chunk})))
          (+= doc-count (len chunks))
          (except [e Exception]
            None)))))

  (when docs
    (.insert collection docs))
  (print (.format "Indexed {} chunks from {}" 
                doc-count 
                (get config "data_dir")))
  collection)


(defn search [collection query [topk 5]]
  "Search the zvec collection for chunks relevant to the query."
  (setv query-vector (get-embedding query))
  (setv results
    (.query collection
      (zvec.VectorQuery "embedding" :vector query-vector)
      :topk topk))
  (setv chunks [])
  (for [res results]
    (setv text
      (if res.fields
        (.get res.fields "text" "")
        ""))
    (when text
      (.append chunks text)))
  chunks)


(defn ask-ollama [question context-chunks]
  "Send retrieved chunks + user question to the Ollama chat model."
  (setv context (.join "\n\n---\n\n" context-chunks))
  (setv system-prompt
    (.join ""
      ["You are a helpful assistant. Answer the user's question using ONLY "
       "the context provided below. If the context does not contain enough "
       "information, say so. Be concise and accurate.\n\n"
       f"Context:\n{context}"]))
  (setv url f"{OLLAMA-BASE}/api/chat")
  (setv payload
    (.encode
      (json.dumps
        {"model"   (get config "chat_model")
         "stream"  False
         "messages"
           [{"role" "system" "content" system-prompt}
            {"role" "user"   "content" question}]})
      "utf-8"))
  (setv req
    (urllib.request.Request url :data payload
      :headers {"Content-Type" "application/json"}))
  (try
    (with [res (urllib.request.urlopen req)]
      (setv body (json.loads (.decode (.read res) "utf-8")))
      (get (get body "message") "content"))
    (except [e Exception]
      f"Error calling Ollama chat: {e}")))


(defn main []
  (print "Building zvec index from text files …")
  (setv collection (build-index))
  (print (.format "\nRAG chat ready  (model:  {}" (get config "chat_model")))
  (print "Type your question, or 'quit' to exit.\n")

  (while True
    (try
      (setv question (.strip (input "You> ")))
      (except [[EOFError KeyboardInterrupt]]
        (print "\nGoodbye!")
        (break)))
    (when (or (not question) (in (.lower question) ["quit" "exit" "q"]))
      (print "Goodbye!")
      (break))

    (setv chunks (search collection question))
    (if (not chunks)
      (print "No relevant chunks found in the index.\n")
      (do
        (setv answer (ask-ollama question chunks))
        (print f"\nAssistant> {answer}\n")))))


(when (= __name__ "__main__")
  (main))
