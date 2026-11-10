;; hy_eval/models.hy -- Model abstraction with FakeModel and OllamaModel.

(import dataclasses [dataclass field])
(import json)
(import time)
(import urllib.request)


(defn estimate-tokens [#^ str text]
  "Estimate token count from whitespace-delimited words and punctuation."
  (if (not text)
    0
    (max 1 (int (* (len (.split text)) 1.3)))))


(defclass [(dataclass :frozen True)] ToolCall []
  "A structured tool call emitted by a model or agent."
  #^ str name
  #^ dict arguments)


(defclass [dataclass] ModelResponse []
  "Standardized model response with token, latency, cost, and tool telemetry."
  #^ str text
  #^ str model
  (setv #^ int prompt-tokens 0
        #^ int completion-tokens 0
        #^ float latency-ms 0.0
        #^ float cost-usd 0.0
        #^ bool cached False
        #^ list tool-calls (field :default-factory list)))


(defclass FakeModel []
  "Deterministic, offline model for tests and reproducible evaluations.

  `responses` maps a prompt substring to one of:
    - a plain string reply
    - a dict with keys 'text', optional 'tool_calls', optional 'latency_ms'
    - a list of replies consumed in order (useful for testing retries)
    - a callable (fn [prompt system] ...) returning a string or dict"

  (defn __init__ [self
                  [name "fake-qwen3:1.7b"]
                  [responses None]
                  [default-response "The provided context does not contain enough information."]
                  [cost-per-1k-tokens 0.0005]
                  [simulated-latency-ms 4.2]]
    (setv self.name name
          self.responses (if (is responses None) {} (dict responses))
          self.default-response default-response
          self.cost-per-1k-tokens cost-per-1k-tokens
          self.simulated-latency-ms simulated-latency-ms
          self.history []
          self._cursors {}))

  (defn _resolve-entry [self key entry prompt system]
    (cond
      (isinstance entry list)
      (do
        (setv idx (.get self._cursors key 0))
        (setv chosen (get entry (min idx (- (len entry) 1))))
        (setv (get self._cursors key) (+ idx 1))
        chosen)

      (callable entry)
      (entry prompt system)

      True
      entry))

  (defn generate [self #^ str prompt [system ""] [temperature 0.0]]
    (.append self.history {"prompt" prompt "system" system "temperature" temperature})
    (setv combined (+ system "\n" prompt)
          matched None)
    (for [[pattern entry] (.items self.responses)]
      (when (and (is matched None) (in pattern combined))
        (setv matched (self._resolve-entry pattern entry prompt system))))
    (when (is matched None)
      (setv matched self.default-response))

    (setv text ""
          tool-calls []
          latency self.simulated-latency-ms)
    (if (isinstance matched dict)
      (do
        (setv text (.get matched "text" "")
              latency (float (.get matched "latency_ms" self.simulated-latency-ms)))
        (for [tc (.get matched "tool_calls" [])]
          (.append tool-calls
            (if (isinstance tc ToolCall)
              tc
              (ToolCall :name (get tc "name")
                        :arguments (.get tc "arguments" {}))))))
      (setv text (str matched)))

    (setv p-tokens (estimate-tokens combined)
          c-tokens (estimate-tokens text)
          cost (round (* (/ (+ p-tokens c-tokens) 1000.0) self.cost-per-1k-tokens) 8))
    (ModelResponse
      :text text
      :model self.name
      :prompt-tokens p-tokens
      :completion-tokens c-tokens
      :latency-ms latency
      :cost-usd cost
      :cached False
      :tool-calls tool-calls)))


(defclass OllamaModel []
  "Local Ollama model client using standard-library urllib with graceful fallback."

  (defn __init__ [self
                  [model "qwen3:1.7b"]
                  [base-url "http://localhost:11434"]
                  [timeout 5.0]
                  [fallback None]]
    (setv self.name model
          self.base-url (.rstrip base-url "/")
          self.timeout timeout
          self.fallback fallback
          self._warned False))

  (defn is-available [self]
    "Return True if the local Ollama server responds to /api/tags."
    (try
      (setv req (urllib.request.Request f"{self.base-url}/api/tags"))
      (with [res (urllib.request.urlopen req :timeout 1.5)]
        (= res.status 200))
      (except [Exception]
        False)))

  (defn generate [self #^ str prompt [system ""] [temperature 0.0]]
    (setv start (time.perf-counter)
          messages [])
    (when system
      (.append messages {"role" "system" "content" system}))
    (.append messages {"role" "user" "content" prompt})
    (setv payload
      (.encode
        (json.dumps
          {"model" self.name
           "stream" False
           "options" {"temperature" temperature}
           "messages" messages})
        "utf-8"))
    (setv req
      (urllib.request.Request
        f"{self.base-url}/api/chat"
        :data payload
        :headers {"Content-Type" "application/json"}))
    (try
      (with [res (urllib.request.urlopen req :timeout self.timeout)]
        (setv body (json.loads (.decode (.read res) "utf-8"))
              elapsed (* (- (time.perf-counter) start) 1000.0)
              content (get (get body "message") "content")
              p-tokens (int (.get body "prompt_eval_count" (estimate-tokens (+ system " " prompt))))
              c-tokens (int (.get body "eval_count" (estimate-tokens content))))
        (ModelResponse
          :text content
          :model self.name
          :prompt-tokens p-tokens
          :completion-tokens c-tokens
          :latency-ms (round elapsed 2)
          :cost-usd 0.0
          :cached False))
      (except [e Exception]
        (when (not (is self.fallback None))
          (when (not self._warned)
            (print f"[hy-eval] Ollama ({self.name}) unavailable ({e}); using fallback model.")
            (setv self._warned True))
          (return (.generate self.fallback prompt :system system :temperature temperature)))
        (raise (RuntimeError f"Ollama call failed and no fallback configured: {e}"))))))
