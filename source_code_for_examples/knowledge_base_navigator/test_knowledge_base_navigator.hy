;; Tests for knowledge_base_navigator.hy  --  run with:  uv run pytest
;;
;; The Gemini client is replaced with a fake, so no API key or network access
;; is needed. conftest.py sets a placeholder GOOGLE_API_KEY because
;; genai.Client() is created at import time.

(import builtins)
(import types [SimpleNamespace])
(import knowledge-base-navigator :as kbn)


;; ---------- helpers ----------

(defn install-fake-client [monkeypatch replies]
  "Replace kbn.client; each call pops the next reply. Returns the call log."
  (setv calls [])
  (defn generate-content [#** kwargs]
    (.append calls kwargs)
    (SimpleNamespace :text (.pop replies 0)))
  (monkeypatch.setattr kbn "client"
    (SimpleNamespace :models (SimpleNamespace :generate-content generate-content)))
  calls)

(defn fake-input [answers]
  (fn [[prompt ""]] (.pop answers 0)))


;; ---------- parse-selections ----------

(defn test-parse-selections-spaces-and-commas []
  (assert (= (kbn.parse-selections "1, 3 4,5") [1 3 4 5])))

(defn test-parse-selections-ignores-non-numbers []
  (assert (= (kbn.parse-selections "2 abc 7 x9") [2 7])))

(defn test-parse-selections-empty []
  (assert (= (kbn.parse-selections "") []))
  (assert (= (kbn.parse-selections " , ,") [])))


;; ---------- Gemini calls ----------

(defn test-get-gemini-response-uses-search-tool [monkeypatch]
  (setv calls (install-fake-client monkeypatch ["answer"]))
  (assert (= (kbn.get-gemini-response "hello") "answer"))
  (setv call (get calls 0))
  (assert (= (get call "model") "gemini-2.5-flash"))
  (assert (= (get call "contents") "hello"))
  (assert (= (get call "config") {"tools" [{"google_search" {}}]})))

(defn test-get-gemini-response-merges-config [monkeypatch]
  (setv calls (install-fake-client monkeypatch ["ok"]))
  (kbn.get-gemini-response "hi" :temperature 0.2)
  (assert (= (get calls 0 "config")
             {"tools" [{"google_search" {}}] "temperature" 0.2})))

(defn test-extract-entities-prompt [monkeypatch]
  (setv calls (install-fake-client monkeypatch ["1. Bill Gates"]))
  (assert (= (kbn.extract-entities "Bill Gates and Microsoft") "1. Bill Gates"))
  (setv prompt (get calls 0 "contents"))
  (assert (in "\"Bill Gates and Microsoft\"" prompt))
  (assert (in "numbered list" prompt)))

(defn test-get-entity-details-prompt [monkeypatch]
  (setv calls (install-fake-client monkeypatch ["details"]))
  (assert (= (kbn.get-entity-details "1. A\n2. B\n3. C" [1 3]) "details"))
  (setv prompt (get calls 0 "contents"))
  (assert (in "1. A\n2. B\n3. C" prompt))
  (assert (in "entity numbers from the list: 1, 3." prompt)))


;; ---------- interactive loop ----------

(defn test-kbn-ui-full-round-trip [monkeypatch capsys]
  (setv calls (install-fake-client monkeypatch ["1. Paris\n2. France" "Paris is the capital."]))
  (monkeypatch.setattr builtins "input" (fake-input ["Paris, France" "1 2" "quit"]))
  (kbn.kbn-ui)
  (setv out (. (capsys.readouterr) out))
  (assert (= (len calls) 2))
  (assert (in "1. Paris" out))
  (assert (in "Paris is the capital." out))
  (assert (in "Goodbye!" out)))

(defn test-kbn-ui-no-valid-selection [monkeypatch capsys]
  (setv calls (install-fake-client monkeypatch ["1. Paris"]))
  (monkeypatch.setattr builtins "input" (fake-input ["Paris" "none" "q"]))
  (kbn.kbn-ui)
  (assert (= (len calls) 1))
  (assert (in "No valid selections" (. (capsys.readouterr) out))))
