(import ollama)

(defn completion [prompt]
  ; Initiate chat with the model
  (setv response
        (ollama.chat
          :model "llama3.2:latest"
          :messages [{"role" "user" "content" user-prompt}]))
  (print response)
  (return response.message.content))

;;;; Test code:

; User prompt
(setv
  user-prompt
  "Sally is 77, Bill is 32, and Alex is 44 years old. Pairwise, what are their age differences? Be concise."
  )

(print
 (completion user-prompt))
