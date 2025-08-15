# Running Local LLMs Using Ollama

TBD

## Completions

Here we look at a "hello world" type simple example: we pass a text prompt to a local Ollama server instance.

The example code is in the file **completion.hy**:

{lang="hylang",linenos=off}
~~~~~~~~
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
~~~~~~~~

The output looks like:


{linenos=off}
~~~~~~~~
$ uv run hy completion.hy
model='llama3.2:latest' created_at='2025-08-15T22:35:33.82621Z' done=True done_reason='stop' total_duration=1099944375 load_duration=81426584 prompt_eval_count=56 prompt_eval_duration=98267500 eval_count=54 eval_duration=919762917 message=Message(role='assistant', content='Here are the pairwise age differences:\n\n- Sally and Bill: 77 - 32 = 45\n- Sally and Alex: 77 - 44 = 33\n- Bill and Alex: 32 - 44 = -12 (Bill is younger)', thinking=None, images=None, tool_name=None, tool_calls=None)
Here are the pairwise age differences:

- Sally and Bill: 77 - 32 = 45
- Sally and Alex: 77 - 44 = 33
- Bill and Alex: 32 - 44 = -12 (Bill is younger)
~~~~~~~~



## Tool Use

TBD

Here is the sample tools library defined in **tools.hy**:

{lang="hylang",linenos=off}
~~~~~~~~
(import os)
(import httpx)
(import markdownify [markdownify])

(defn list-directory []
  "Lists files and directories in the current working directory"
  ; Args:
  ;   None
  ; Returns:
  ;   string containing the current directory name, followed by list of files in the directory
  (setv current-dir (os.path.realpath "."))
  (setv files (.listdir os))

  (return f"Contents of current directory {current-dir} is: {files}"))

(defn read-file-contents [file-path]
  "Reads the contents of a file, given an input file-path"
  ; Args:
  ;   file-path: The path to the file
  ; Returns:
  ;   The contents of the file as a string
  (with [f (open file-path "r")]
    (.read f)))

(defn uri-to-markdown [uri]
  "Fetches HTML from a URI and converts it to markdown."
  (setv response (httpx.get uri))
  (.raise-for-status response)
  ; Convert the HTML text to Markdown
  (setv md (markdownify response.text))
  (return f"# Content from {uri}\n\n{md}"))
~~~~~~~~


Example in **ollama_tools_examples.hy**:


{lang="hylang",linenos=off}
~~~~~~~~
(import tools  [list-directory])
(import tools  [read-file-contents])
(import tools  [uri-to-markdown])

; (print (list-directory))
; (print (read-file-contents "requirements.txt"))
(print (uri-to-markdown "https://markwatson.com"))

(exit 0)

(import ollama)

; Map function names to function objects
(setv available-functions {
  "list_directory" list-directory
  "read_file_contents" read-file-contents
  "uri_to_markdown" uri-to-markdown
})

; User prompt
(setv
  user-prompt 
;;  "read the 'requirements.txt' file"
  "convert 'https://markwatson.com' to markdown.")
;;  "Please list the contents of the current directory, read the 'requirements.txt' file, and convert 'https://markwatson.com' to markdown.")

; Initiate chat with the model
(setv response (ollama.chat
  :model "llama3.2:latest"
  :messages [{"role" "user" "content" user-prompt}]
  :tools [list-directory read-file-contents uri-to-markdown]
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
      (setv result (function-to-call #** tool-call.function.arguments))
      (print f"\n\n** Output of {tool-call.function.name}: {result}")
    )
    (print f"\n\n** Function {(.name tool-call.function)} not found.")
  )
)
~~~~~~~~


TBD








{lang="hylang",linenos=off}
~~~~~~~~

~~~~~~~~








{lang="hylang",linenos=off}
~~~~~~~~

~~~~~~~~

