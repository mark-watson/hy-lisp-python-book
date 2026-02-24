# RAG Using zvec Vector Datastore and Local Model

The **zvec** library implements a lightweight, lightning-fast, in-process vector database. Allibaba released **zvec** in February 2026. We will see how to use **zvec** and then build a high performance RAG system. We will use the tiny model **qwen3:1.7b** running localling using Ollama as part of the application.

Note: The source code for this example can be found in **hy-lisp-python-book/source_code_for_examples/RAG_zvec/app.hy**. Not all the code in this file is listed here.

Note: This chapter was derived from a chapter with the same name from my Python book [Ollama in Action](https://leanpub.com/ollama).

## Introduction and Architecture

Building a Retrieval-Augmented Generation (RAG) pipeline entirely locally ensures absolute data privacy, eliminates API latency costs, and provides full control over the embedding and generation models. In this chapter, we construct a fully offline RAG system utilizing Ollama for both embeddings (embeddinggemma) and inference (qwen3:1.7b), paired with zvec, a lightweight, high-performance local vector database.

The architecture follows a classic two-phase RAG pattern, adding an additional third step to improve the user experience:

- Ingestion: Parse local text files, chunk the content, generate embeddings via Ollama, and index them into zvec.
- Retrieval & Generation: Embed the user query, perform a similarity search in zvec, and save the retrieved top-k chunks for processing by a local Ollama chat model.
- Use a small LLM model (qwen3:1.7b) to process the retrieved chunks and  taking into account the user’s original query and then format a subset of the text in the returned chunks for the user to read.

## Design Analysis: Dependency Minimization

A notable design choice in our implementation is the reliance on Python's standard library for network calls. By utilizing **urllib.request** instead of third-party libraries like **requests** or the official **ollama-python** client library, the dependency footprint is minimized exclusively to **zvec**. This reduces virtual environment overhead and potential version conflicts, prioritizing a lean deployment.

## Implementation Walkthrough

Here we look at some of the code in the source file **app.hy**.

### Embedding and Chunking Strategy
The ingestion phase relies on a fixed-size overlapping window strategy. Here is an implementation of a chunking strategy:

```hy
(defn chunk-text [text [chunk-size 500] [overlap 50]]
  "Split text into overlapping chunks."
  (setv chunks [])
  (setv start 0)
  (while (< start (len text))
    (setv end (+ start chunk-size))
    (.append chunks (cut text start end))
    (setv start (- end overlap)))
  chunks)
```

Analysis of code:

- Chunk Size (500 chars): This relatively small chunk size yields high-granularity embeddings. It reduces the risk of retrieving "diluted" context where a single chunk contains multiple disparate concepts.
- Overlap (50 chars): Crucial for preventing context loss at the boundaries of chunks. It ensures that a semantic concept bisected by a hard character limit is still captured cohesively in at least one chunk.
- Embedding Model: The system uses embeddinggemma. The Ollama API endpoint (/api/embeddings) is called directly. If the server fails to respond, a fallback zero-vector [0.0] * 768 is returned to prevent pipeline crashes, though logging or raising an exception might be preferred in production.

### Vector Storage with zvec
The **zvec** integration demonstrates a strictly typed, schema-driven approach to local vector storage.

Design notes for code:

- Dimensionality Matching: The vector schema is hardcoded to 768 dimensions (FP32), which strictly matches the output tensor of the embeddinggemma model. Any change to the embedding model in the configuration must be accompanied by a corresponding update to this schema.
- Storage Path: The database is initialized locally at ./zvec_example. The implementation includes a defensive teardown (shutil.rmtree) of existing databases on startup. This is excellent for testing and iterative development, though destructive in a persistent production environment.

The following function builds the index using an embedding model for the local Ollama server:

```hy
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
```

This function **build_index** initializes a local vector database and populates it with document embeddings. Specifically, it executes four main operations:

- Schema & Storage Initialization: Defines a strict schema for zvec (768-dimensional FP32 vectors and a string metadata field) and destructively recreates the local database directory (./zvec_example).
- File Traversal: Recursively walks a configured target directory (config["data_dir"]) to locate specific file types.
- Transformation & Embedding: Reads each file, splits it into overlapping chunks, and retrieves the vector embedding for each chunk via an external call (get_embedding).
- Batch Insertion: Accumulates all processed chunks and their embeddings into a single memory list (docs), then performs a bulk insert into the zvec collection.

### Retrieval and LLM Synthesis

The synthesis phase bridges the vector database and the Generative LLM. Function **search** identifies matching text chunks in the vector database:

```hy
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
```

Function **search** performs a Top-K retrieval. The default topk=5 retrieves roughly 2,500 characters of context. This easily fits within the context window of modern small models like qwen3:1.7b without causing attention dilution ("lost in the middle" syndrome).

### System Prompt Engineering and Using a Small LLM to Prepare Output for a User

The **ask_ollama** function utilizes strict prompt constraints: "Answer the user's question using ONLY the context provided below. If the context does not contain enough information, say so." This significantly mitigates hallucination by forcing the model to ground its response exclusively in the retrieved data.

```hy
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
```

Function **ask_ollama** uses stateless execution: The /api/chat call sets "stream": False and does not maintain a conversation history array across loop iterations. This makes it a pure Q&A interface rather than a continuous chat, ensuring each answer is cleanly tied to a fresh zvec retrieval.

## Example Run

To run the pipeline, ensure the Ollama daemon is running locally on port 11434 and that both models (embeddinggemma and qwen3:1.7b) have been pulled. Place your .txt files in the **../data** directory and execute the script. The system will build the index and immediately drop you into a REPL loop for interactive querying.

Here is an example run:

```bash
 $ uv run hy app.hy 
Building zvec index from text files
Indexed 9 chunks from ../data

RAG chat ready  (model: qwen3:1.7b)
Type your question, or 'quit' to exit.

You> who says economics is bullshit?

Assistant> The context mentions Pauli Blendergast, an economist at the University of Krampton Ohio, who is noted for stating that "economics is bullshit." No other individuals are explicitly cited in the provided text.

You> what procedures are performed in chemistry labs?

Assistant> The provided context does not contain information about procedures performed in chemistry labs. It focuses on economic concepts, microeconomics, macroeconomics, and related topics, but does not mention chemistry or laboratory procedures.

You> how do microeconomics and macroeconomics differ?

Assistant> Microeconomics focuses on individual agents (e.g., households, firms) and specific markets, analyzing decisions like pricing, resource allocation, and consumer behavior. Macroeconomics examines the entire economy, addressing broader issues such as unemployment, inflation, growth, and fiscal/money policy. While microeconomics deals with "how" resources are used, macroeconomics focuses on "what" the economy produces and "how collectively" it functions.

You> quit
Goodbye!
```

Dear reader, notice that there was no information in the indexed text to answer the second example query and this program correctly refused to hallucinate (or make up) an answer.

## Wrap Up for RAG Using zvec Vector Datastore and Local Model

In this chapter, we built a completely offline, privacy-preserving RAG architecture by bridging Alibaba’s recently released in-process vector database, zvec, with local Ollama inference. By intentionally minimizing external dependencies and utilizing a strictly typed, schema-driven datastore, we eliminated the network overhead and deployment bloat typical of client-server vector databases. The fixed-size overlapping chunking strategy, combined with the 768-dimensional embeddinggemma model, ensures high-fidelity semantic retrieval. Simultaneously, the compact qwen3:1.7b model demonstrates that a heavily constrained, prompt-engineered generation phase can effectively synthesize retrieved context without hallucination.

The resulting pipeline serves as a robust, lightweight foundation for edge-deployable AI applications. Because the entire storage and inference stack executes locally within the same process, the pattern is exceptionally portable, fast, and secure. Moving forward, this baseline implementation can be extended to handle more complex retrieval requirements, such as integrating dynamic semantic chunking, implementing Reciprocal Rank Fusion (RRF) for hybrid multi-vector queries, or introducing multi-turn conversational memory. Ultimately, combining embedded vector storage with small-parameter LLMs proves that high-performance, domain-specific RAG does not require massive cloud infrastructure.
