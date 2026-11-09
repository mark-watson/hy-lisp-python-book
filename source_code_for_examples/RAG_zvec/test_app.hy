;; Tests for app.hy  --  run with:  uv run pytest

(import io)
(import json)
(import pytest)
(import app)


;; ---------- helpers ----------

(defclass FakeResponse []
  "Minimal stand-in for the object returned by urllib.request.urlopen."
  (defn __init__ [self payload]
    (setv self.body (.encode (json.dumps payload) "utf-8")))
  (defn read [self] self.body)
  (defn __enter__ [self] self)
  (defn __exit__ [self #* args] False))

(defn fake-urlopen [payload [captured None]]
  "Return a urlopen replacement that records requests and returns payload."
  (fn [req]
    (when (is-not captured None)
      (.append captured req))
    (FakeResponse payload)))


;; ---------- chunk-text ----------

(defn test-chunk-text-short-text-is-one-chunk []
  (assert (= (app.chunk-text "hello") ["hello"])))

(defn test-chunk-text-empty-text []
  (assert (= (app.chunk-text "") [])))

(defn test-chunk-text-overlap []
  (setv text (.join "" (map str (range 10))))   ; "0123456789"
  (setv chunks (app.chunk-text text :chunk-size 4 :overlap 1))
  (assert (= chunks ["0123" "3456" "6789" "9"]))
  ;; consecutive chunks share `overlap` characters
  (for [[a b] (zip chunks (cut chunks 1 None))]
    (assert (= (cut a -1 None) (cut b 0 1)))))

(defn test-chunk-text-covers-all-text []
  (setv text (* "abcdefghij" 120))
  (setv chunks (app.chunk-text text))
  (assert (all (gfor c chunks (<= (len c) 500))))
  (assert (.endswith text (get chunks -1))))


;; ---------- get-embedding ----------

(defn test-get-embedding-success [monkeypatch]
  (setv captured [])
  (monkeypatch.setattr app.urllib.request "urlopen"
    (fake-urlopen {"embedding" [0.1 0.2 0.3]} captured))
  (assert (= (app.get-embedding "some text") [0.1 0.2 0.3]))
  (setv req (get captured 0))
  (assert (.endswith (.get-full-url req) "/api/embeddings"))
  (setv sent (json.loads req.data))
  (assert (= (get sent "prompt") "some text"))
  (assert (= (get sent "model") (get app.config "embedding_model"))))

(defn test-get-embedding-error-returns-zero-vector [monkeypatch]
  (defn boom [req] (raise (OSError "connection refused")))
  (monkeypatch.setattr app.urllib.request "urlopen" boom)
  (setv emb (app.get-embedding "x"))
  (assert (= (len emb) 768))
  (assert (all (gfor v emb (= v 0.0)))))


;; ---------- ask-ollama ----------

(defn test-ask-ollama-success [monkeypatch]
  (setv captured [])
  (monkeypatch.setattr app.urllib.request "urlopen"
    (fake-urlopen {"message" {"role" "assistant" "content" "42"}} captured))
  (assert (= (app.ask-ollama "What is it?" ["chunk one" "chunk two"]) "42"))
  (setv sent (json.loads (. (get captured 0) data)))
  (assert (= (get sent "stream") False))
  (setv [system user] (get sent "messages"))
  (assert (in "chunk one" (get system "content")))
  (assert (in "chunk two" (get system "content")))
  (assert (= (get user "content") "What is it?")))

(defn test-ask-ollama-error-message [monkeypatch]
  (defn boom [req] (raise (OSError "down")))
  (monkeypatch.setattr app.urllib.request "urlopen" boom)
  (assert (.startswith (app.ask-ollama "q" ["c"]) "Error calling Ollama chat")))


;; ---------- search (with a fake collection) ----------

(defclass FakeResult []
  (defn __init__ [self fields] (setv self.fields fields)))

(defclass FakeCollection []
  (defn __init__ [self results] (setv self.results results  self.calls []))
  (defn query [self q #** kwargs]
    (.append self.calls kwargs)
    self.results))

(defn test-search-filters-empty-results [monkeypatch]
  (monkeypatch.setattr app "get_embedding" (fn [text] [0.0]))
  (setv coll (FakeCollection [(FakeResult {"text" "alpha"})
                              (FakeResult None)
                              (FakeResult {"text" ""})
                              (FakeResult {"text" "beta"})]))
  (assert (= (app.search coll "query" :topk 3) ["alpha" "beta"]))
  (assert (= (get coll.calls 0 "topk") 3)))


;; ---------- build-index + search against a real zvec collection ----------

(defn fake-embedding [text]
  "Deterministic 768-dim embedding: one-hot on a keyword."
  (setv v (* [0.0] 768))
  (setv (get v (if (in "football" (.lower text)) 0 1)) 1.0)
  v)

(defn test-build-index-and-search [tmp-path monkeypatch]
  (setv data-dir (/ tmp-path "data"))
  (.mkdir data-dir)
  (.write-text (/ data-dir "sports.txt") "Football is played with a ball.")
  (.write-text (/ data-dir "chem.txt") "Water is H2O.")
  (.write-text (/ data-dir "ignored.md") "Not indexed.")
  (monkeypatch.chdir tmp-path)              ; zvec db written under tmp-path
  (monkeypatch.setitem app.config "data_dir" (str data-dir))
  (monkeypatch.setattr app "get_embedding" fake-embedding)

  (setv collection (app.build-index))
  (setv results (app.search collection "tell me about football" :topk 1))
  (assert (= results ["Football is played with a ball."])))
