(import tool-file-dir  [list-directory])
;;(import [read-file-contents] :from tool-file-contents)
;;(import [uri-to-markdown] :from tool-web-search)

; (print (list-directory))
; (print (read-file-contents "requirements.txt"))
; (print (uri-to-markdown "https://markwatson.com"))

(import ollama)

; Map function names to function objects
(setv available-functions {
  "list_directory" list-directory
  ;;"read_file_contents" read-file-contents
  ;;"uri_to_markdown" uri-to-markdown
})

; User prompt
(setv
  user-prompt
  "Please list the contents of the current directory, read the 'requirements.txt' file, and convert 'https://markwatson.com' to markdown.")

; Initiate chat with the model
(setv response (ollama.chat
  :model "llama3.2:latest"
  :messages [{"role" "user" "content" user-prompt}]
  :tools [list-directory] ;;  read-file-contents uri-to-markdown]
))

(print response)

;;(print (get response.message.tool_calls 0).name)

; Process the model's response
(for [tool-call (or response.message.tool_calls {"name" "none"})]
  (print tool-call)
  (print tool-call.function)
  (setv function-to-call (.get available-functions tool-call.function.name))
  (setv arguments tool-call.function.arguments)
  (print arguments)
  (print function-to-call)
  (if function-to-call
    (do
      (setv result (function-to-call)) ;;  **tool-call.function.arguments))
      (print f"\n\n** Output of {tool-call.function.name}: {result}")
    )
    (print f"\n\n** Function {(.name tool-call.function)} not found.")
  )
)
