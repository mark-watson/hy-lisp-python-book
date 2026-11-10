#!/usr/bin/env hy
"Streaming LLM responses in Hy: NDJSON (Ollama /api/chat) and SSE (OpenAI style)
parsing over httpx.AsyncClient.stream and aiter_lines, with an offline fake
transport and an optional live Ollama helper."

(import asyncio)
(import json)
(import time)
(import httpx)


(defn parse-ndjson-line [line]
  "Parse one NDJSON line from an Ollama /api/chat stream.
  Return #(token is-done) or #(None False) for blank lines."
  (setv stripped (.strip line))
  (when (not stripped)
    (return #(None False)))
  (setv payload (json.loads stripped)
        msg (.get payload "message" {})
        token (.get msg "content" "")
        done (bool (.get payload "done" False)))
  #(token done))


(defn parse-sse-line [line]
  "Parse one Server-Sent Events line ('data: ...').
  Return #(token is-done) or #(None False) for comments/non-data lines."
  (setv stripped (.strip line))
  (when (or (not stripped) (not (.startswith stripped "data:")))
    (return #(None False)))
  (setv data-str (.strip (cut stripped 5 None)))
  (when (= data-str "[DONE]")
    (return #("" True)))
  (setv payload (json.loads data-str)
        choices (.get payload "choices" [])
        delta (if choices (.get (get choices 0) "delta" {}) {})
        token (.get delta "content" ""))
  #(token False))


(defn :async stream-ollama-chat [client prompt
                                 [model "qwen3.5:4b"]
                                 [url "http://127.0.0.1:11434/api/chat"]]
  "Async generator yielding text chunks from an Ollama /api/chat NDJSON stream."
  (setv body {"model" model
              "messages" [{"role" "user" "content" prompt}]
              "stream" True})
  (with [:async response (.stream client "POST" url :json body)]
    (.raise-for-status response)
    (for [:async line (.aiter-lines response)]
      (setv [token done] (parse-ndjson-line line))
      (when token
        (yield token))
      (when done
        (break)))))


(defn :async collect-chat-stream [client prompt
                                  [model "qwen3.5:4b"]
                                  [url "http://127.0.0.1:11434/api/chat"]]
  "Consume stream-ollama-chat and record tokens, full text, and latency stats."
  (setv start (time.perf-counter)
        first-token-time None
        chunks [])
  (for [:async token (stream-ollama-chat client prompt :model model :url url)]
    (when (is first-token-time None)
      (setv first-token-time (- (time.perf-counter) start)))
    (.append chunks token))
  (setv elapsed (- (time.perf-counter) start))
  {"text" (.join "" chunks)
   "chunks" chunks
   "chunk_count" (len chunks)
   "ttft_seconds" (or first-token-time elapsed)
   "total_seconds" elapsed})


(defclass FakeNDJSONByteStream [httpx.AsyncByteStream]
  "Stream pre-encoded NDJSON lines with an optional delay between chunks."

  (defn __init__ [self lines [chunk-delay 0.005]]
    (setv self.lines lines
          self.chunk-delay chunk-delay))

  (defn :async __aiter__ [self]
    (for [line self.lines]
      (when (> self.chunk-delay 0)
        (await (asyncio.sleep self.chunk-delay)))
      (yield (.encode (+ line "\n") "utf-8")))))


(defn make-fake-ollama-transport [tokens [chunk-delay 0.005]]
  "Create an httpx.MockTransport that streams tokens in Ollama NDJSON format."
  (setv lines (lfor tok tokens
                    (json.dumps {"model" "qwen3.5:4b"
                                 "message" {"role" "assistant" "content" tok}
                                 "done" False})))
  (.append lines (json.dumps {"model" "qwen3.5:4b"
                              "message" {"role" "assistant" "content" ""}
                              "done" True}))

  (defn :async handler [request]
    (httpx.Response 200
                    :headers {"content-type" "application/x-ndjson"}
                    :stream (FakeNDJSONByteStream lines :chunk-delay chunk-delay)))

  (httpx.MockTransport handler))


(defn :async try-live-ollama [prompt
                              [model "qwen3.5:4b"]
                              [timeout 1.5]
                              [url "http://127.0.0.1:11434/api/chat"]]
  "Try streaming from a local Ollama server; fall back cleanly if unavailable."
  (try
    (with [:async client (httpx.AsyncClient :timeout timeout)]
      (setv result (await (collect-chat-stream client prompt :model model :url url)))
      {"live" True #** result})
    (except [exc Exception]
      (setv exc-name (. (type exc) __name__))
      {"live" False
       "note" f"Ollama not reachable ({exc-name}); used MockTransport stream."})))
