;; hy_eval/tracing.hy -- Structured JSONL tracing with PII and secret redaction.

(import contextlib [contextmanager])
(import dataclasses [dataclass field asdict])
(import functools [wraps])
(import json)
(import pathlib [Path])
(import re)
(import time)
(import uuid)
(import hy_eval.models [estimate-tokens])


(setv _REDACTION_PATTERNS
  [#("API_KEY"
     (re.compile r"(?:sk-[A-Za-z0-9_-]{12,}|Bearer\s+[A-Za-z0-9._-]{12,}|(?:OPENAI|ANTHROPIC|GEMINI)_API_KEY\s*=\s*\S+)"))
   #("EMAIL"
     (re.compile r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"))
   #("SSN"
     (re.compile r"\b\d{3}-\d{2}-\d{4}\b"))
   #("PHONE"
     (re.compile r"(?<!\d)(?:\+1[-.\s]?)?\(?\d{3}\)?[-.\s]\d{3}[-.\s]\d{4}(?!\d)"))])


(defn redact-with-stats [#^ str text]
  "Replace secrets and PII tokens in `text`. Return #(redacted_text count)."
  (when (not text)
    (return #("" 0)))
  (setv out text
        total-count 0)
  (for [[label pattern] _REDACTION_PATTERNS]
    (setv [out n] (.subn pattern f"[REDACTED_{label}]" out))
    (+= total-count n))
  #(out total-count))


(defn redact-pii [#^ str text]
  "Return `text` with API keys, emails, SSNs, and phone numbers redacted."
  (get (redact-with-stats text) 0))


(defclass [dataclass] SpanRecord []
  "A single traced LLM or tool operation with redacted prompt and response."
  #^ str trace-id
  #^ str span-name
  #^ str model
  #^ str prompt
  #^ str response
  #^ int prompt-tokens
  #^ int completion-tokens
  #^ float latency-ms
  #^ float cost-usd
  (setv #^ bool cached False
        #^ int redactions 0
        #^ str status "ok"
        #^ dict tags (field :default-factory dict))

  (defn to-dict [self]
    (asdict self)))


(defclass Tracer []
  "Records redacted LLM spans in memory and optionally appends them to a JSONL file."

  (defn __init__ [self [jsonl-path None] [trace-id None]]
    (setv self.jsonl-path (if (is jsonl-path None) None (Path jsonl-path))
          self.trace-id (or trace-id (cut (. (uuid.uuid4) hex) 0 8))
          self.spans [])
    (when (not (is self.jsonl-path None))
      (.mkdir self.jsonl-path.parent :parents True :exist-ok True)))

  (defn record-response [self #^ str span-name #^ str prompt response [tags None] [status "ok"]]
    "Record a ModelResponse (or string) with automatic PII/secret redaction."
    (setv [clean-prompt p-red] (redact-with-stats prompt)
          raw-text (if (hasattr response "text") response.text (str response))
          [clean-resp r-red] (redact-with-stats raw-text)
          model-name (if (hasattr response "model") response.model "unknown")
          p-tok (if (hasattr response "prompt_tokens")
                  response.prompt-tokens
                  (estimate-tokens prompt))
          c-tok (if (hasattr response "completion_tokens")
                  response.completion-tokens
                  (estimate-tokens raw-text))
          lat (if (hasattr response "latency_ms") response.latency-ms 0.0)
          cost (if (hasattr response "cost_usd") response.cost-usd 0.0)
          cached (if (hasattr response "cached") (bool response.cached) False)
          rec (SpanRecord
                :trace-id self.trace-id
                :span-name span-name
                :model model-name
                :prompt clean-prompt
                :response clean-resp
                :prompt-tokens p-tok
                :completion-tokens c-tok
                :latency-ms (round (float lat) 2)
                :cost-usd (round (float cost) 8)
                :cached cached
                :redactions (+ p-red r-red)
                :status status
                :tags (if (is tags None) {} (dict tags))))
    (.append self.spans rec)
    (when (not (is self.jsonl-path None))
      (with [f (open self.jsonl-path "a" :encoding "utf-8")]
        (.write f (+ (json.dumps (.to-dict rec)) "\n"))))
    rec)

  (defn [contextmanager] trace-span [self #^ str span-name [prompt ""] [model "custom"] [tags None]]
    "Context manager that times a block and logs a SpanRecord on exit."
    (setv start (time.perf-counter)
          box {"response" "" "status" "ok" "model" model})
    (try
      (yield box)
      (except [e Exception]
        (setv (get box "status") "error"
              (get box "response") (str e))
        (raise))
      (finally
        (setv elapsed (* (- (time.perf-counter) start) 1000.0)
              resp-val (get box "response"))
        (if (hasattr resp-val "text")
          (self.record-response span-name prompt resp-val :tags tags :status (get box "status"))
          (do
            (setv [clean-prompt p-red] (redact-with-stats prompt)
                  [clean-resp r-red] (redact-with-stats (str resp-val))
                  rec (SpanRecord
                        :trace-id self.trace-id
                        :span-name span-name
                        :model (str (get box "model"))
                        :prompt clean-prompt
                        :response clean-resp
                        :prompt-tokens (estimate-tokens prompt)
                        :completion-tokens (estimate-tokens (str resp-val))
                        :latency-ms (round elapsed 2)
                        :cost-usd 0.0
                        :cached False
                        :redactions (+ p-red r-red)
                        :status (get box "status")
                        :tags (if (is tags None) {} (dict tags))))
            (.append self.spans rec)
            (when (not (is self.jsonl-path None))
              (with [f (open self.jsonl-path "a" :encoding "utf-8")]
                (.write f (+ (json.dumps (.to-dict rec)) "\n")))))))))

  (defn traced [self [span-name None]]
    "Decorator that traces calls to a function accepting a prompt as its first argument."
    (defn decorator [func]
      (setv name (or span-name func.__name__))
      (defn [(wraps func)] wrapper [#* args #** kwargs]
        (setv prompt-str (if args (str (get args 0)) (str (.get kwargs "prompt" ""))))
        (with [box (self.trace-span name :prompt prompt-str)]
          (setv res (func #* args #** kwargs))
          (setv (get box "response") res)
          res))
      wrapper)
    decorator)

  (defn summary [self]
    "Aggregate telemetry across all recorded spans."
    (setv total (len self.spans)
          p-tokens (sum (gfor s self.spans s.prompt-tokens))
          c-tokens (sum (gfor s self.spans s.completion-tokens))
          cost (round (sum (gfor s self.spans s.cost-usd)) 8)
          cache-hits (sum (gfor s self.spans (if s.cached 1 0)))
          redactions (sum (gfor s self.spans s.redactions))
          errors (sum (gfor s self.spans (if (= s.status "error") 1 0)))
          mean-lat (if (= total 0)
                     0.0
                     (round (/ (sum (gfor s self.spans s.latency-ms)) total) 2)))
    {"trace_id" self.trace-id
     "total_spans" total
     "prompt_tokens" p-tokens
     "completion_tokens" c-tokens
     "total_tokens" (+ p-tokens c-tokens)
     "total_cost_usd" cost
     "cache_hits" cache-hits
     "total_redactions" redactions
     "errors" errors
     "mean_latency_ms" mean-lat}))
