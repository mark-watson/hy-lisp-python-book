; Ensure OLLAMA_API_KEY is set in ENV

(import os)
(import ollama [Client])

(import tools  [list-directory])
(import tools  [read-file-contents])
(import tools  [uri-to-markdown])
(import tools  [write-file-contents])
(import tools  [get-current-datetime])
(import tools  [get-weather])
(import tools  [search-wikipedia])
(import tools  [get-npr-news])

; Create client for local Ollama instance (which routes to cloud)
(setv api-key (.get os.environ "OLLAMA_API_KEY"))
(setv client (Client :host "http://127.0.0.1:11434"))

; Map function names to function objects
(setv available-functions {
  "list_directory" list-directory
  "read_file_contents" read-file-contents
  "uri_to_markdown" uri-to-markdown
  "write_file_contents" write-file-contents
  "get_current_datetime" get-current-datetime
  "get_weather" get-weather
  "search_wikipedia" search-wikipedia
  "get_npr_news" get-npr-news
})

(setv prompts [
  "List the files in the current directory."
  "Read the content of 'requirements.txt'."
  "Convert 'https://en.wikipedia.org/wiki/Hy_(programming_language)' to markdown."
  "Write 'Hello from Ollama tools!' to a file named 'test_output.txt'."
  "What is the current date and time?"
  "What is the weather in London?"
  "Search Wikipedia for 'Lisp (programming language)' and give me a summary."
  "What are the latest news headlines from NPR?"
])

(defn get-available-models []
  (try
    (do
      (setv response (client.list))
      (setv model-names (lfor r response.models r.model))
      (if api-key
          model-names
          (lfor m model-names :if (not (or (.endswith m ":cloud") (.endswith m "-cloud"))) m)))
    (except [e Exception]
      (print "Error fetching models:" e)
      [])))

(while True
  (setv models (get-available-models))
  (when (not models)
      (print "No models found or error fetching models. Check your API key and connection.")
      (break))

  (print "\n--- Available Models ---")
  (for [[i m] (enumerate models)]
    (print f"{ (+ i 1) }. { m }"))
  (print f"{ (+ (len models) 1) }. Exit")

  (try
    (do
      (setv m-choice (input "\nSelect a model (number): "))
      (if (= m-choice (str (+ (len models) 1)))
          (break)
          (do
            (setv m-idx (- (int m-choice) 1))
            (when (or (< m-idx 0) (>= m-idx (len models)))
                (print "Invalid model choice.")
                (continue))
            (setv selected-model (get models m-idx))

            (while True
              (print f"\n--- Ollama Tools Test Menu (Model: {selected-model}) ---")
              (for [[i p] (enumerate prompts)]
                (print f"{ (+ i 1) }. { p }"))
              (print f"{ (+ (len prompts) 1) }. Back to Model Selection")

              (setv choice (input "\nSelect a prompt (number): "))
              
              (when (= choice (str (+ (len prompts) 1)))
                  (break))

              (setv idx (- (int choice) 1))
              (when (or (< idx 0) (>= idx (len prompts)))
                  (print "Invalid choice. Please select a number from the menu.")
                  (continue))
              
              (setv user-prompt (get prompts idx))
              (print f"\n>>> Executing prompt: {user-prompt}\n")

              ; Initiate chat with the model using Ollama Cloud API
              (setv response (client.chat
                selected-model
                :messages [{"role" "user" "content" user-prompt}]
                :tools [list-directory 
                        read-file-contents 
                        uri-to-markdown 
                        write-file-contents 
                        get-current-datetime 
                        get-weather 
                        search-wikipedia 
                        get-npr-news]
              ))

              ; Process the model's response
              (if response.message.tool_calls
                  (for [tool-call response.message.tool_calls]
                    (print f"Tool Call: {tool-call.function.name}")
                    (setv function-to-call (.get available-functions tool-call.function.name))
                    (if function-to-call
                      (do
                        (setv result (function-to-call #** tool-call.function.arguments))
                        (print f"\n** Output of {tool-call.function.name}: {result}"))
                      (print f"\n** Function {tool-call.function.name} not found.")))
                  (print f"Model Response: {response.message.content}"))))))

    (except [e ValueError]
      (print "Please enter a valid number."))
    (except [e Exception]
      (print f"\nError during execution: {e}"))))
