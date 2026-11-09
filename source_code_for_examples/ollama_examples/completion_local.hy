(import ollama)

(defn completion [prompt]
  ;; Initiate chat with the model
  (setv response
        (ollama.chat
          :model "nemotron-3-nano:4b"
          :messages [{"role" "user" "content" prompt}]))
  (print response)
  (return response.message.content))

;;;; Test code:

;; User prompt
(setv
  user-prompt
  "Sally is 77, Bill is 32, and Alex is 44 years old. Pairwise, what are their age differences? Be concise."
  )

(when (= __name__ "__main__")
  (print
   (completion user-prompt)))
