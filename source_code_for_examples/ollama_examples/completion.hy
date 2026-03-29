; Ensure OLLAMA_API_KEY is set in ENV

(import os)
(import ollama [Client])

; Create client for Ollama Cloud API
(setv client
  (Client
    :host "https://ollama.com"
    :headers {"Authorization" (.get os.environ "OLLAMA_API_KEY")}))

(defn completion [prompt]
  "Generate a completion using the Ollama Cloud API"
  (setv response
        (client.chat
          "gpt-oss:20b"
          :messages [{"role" "user" "content" prompt}]
          :stream False))
  (get (get response "message") "content"))

;;;; Test code:

; User prompt
(setv
  user-prompt
  "Sally is 77, Bill is 32, and Alex is 44 years old. Pairwise, what are their age differences? Be concise."
  )

(print
 (completion user-prompt))
