# Running Local LLMs Using Ollama

We saw in previus chapters how to use LLMs from commercial providers, for example GPT-5 from OpenAI and Gemini-2.5-flash from Google. Here we run smaller models on our own laptops or servers. You need to install Ollama: [https://ollama.com](https://ollama.com).

Install Ollama and then download a model we will experiment with:

```
$ ollama pull llama3.2:latest
$ ollama serve
```

The first line is run one time to download a model. The second line is run whenever you want to call the local Ollama service.

## Completions

Here we look at a "hello world" type simple example: we pass a text prompt to a local Ollama server instance. This is similar to previous examples for GPT-5 and Gemini-2.5.

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

In the context of this book using tools means that we define functions in the Hy language and configure a Large Language Model to use these tools.

Integrating tool use with Ollama represents a pivotal step in the evolution of local AI, bridging the gap between offline language models and interactive, real-world applications. This capability, often referred to as function calling, allows LLMs running on your own hardware to execute external code and query APIs, breaking the confines of their static training data. By equipping a local model with tools, developers can empower applications using LLMs to, for example, fetch live weather data, search a database, or control other software services. This transforms the LLM from a simple text-generation engine into a dynamic agent capable of performing complex, multi-step tasks and interacting directly with its environment, all while maintaining the privacy and control inherent to the Ollama ecosystem.

Use of Python docstrings at runtime: the Ollama Python SDK leverages docstrings as a crucial part of its runtime function calling mechanism. When defining functions that will be called by the LLM, the docstrings serve as structured metadata that gets parsed and converted into a JSON schema format. This schema describes the function's parameters, their types, and expected behavior, which is then used by the model to understand how to properly invoke the function. The docstrings follow a specific format that includes parameter descriptions, type hints, and return value specifications, allowing the SDK to automatically generate the necessary function signatures that the LLM can understand and work with.

During runtime execution, when the LLM determines it needs to call a function, it first reads these docstring-derived schemas to understand the function's interface. The SDK parses these docstrings using Python's introspection capabilities (through the inspect module) and matches the LLM's intended function call with the appropriate implementation. This system allows for a clean separation between the function's implementation and its interface description, while maintaining human-readable documentation that serves as both API documentation and runtime function calling specifications. The docstring parsing is done lazily at runtime when the function is first accessed, and the resulting schema is typically cached to improve performance in subsequent calls.

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

In the next example we will configure a LLM to call the tools (or functions) defined in the last code listing.

Example in **ollama_tools_examples.hy**:


{lang="hylang",linenos=off}
~~~~~~~~
(import ollama)

(import tools  [list-directory])
(import tools  [read-file-contents])
(import tools  [uri-to-markdown])

; (print (list-directory))
; (print (read-file-contents "requirements.txt"))
; (print (uri-to-markdown "https://markwatson.com"))

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


This Hy script demonstrates how to integrate a large language model with external tools using the Ollama library. It begins by importing three functions: **list-directory**, **read-file-contents**, and **uri-to-markdown** from the local file **tools.hy** that we saw earlier. These functions are then mapped by their string names to the actual function objects in a dictionary called **available-functions**. This mapping serves as a registry, allowing the program to dynamically call a function based on a name provided by the language model. A user prompt is defined, asking the model to perform a task that requires one of the available tools.

The core of the script involves sending the prompt and the list of available tools to the Llama 3.2 model via the **chat** function. The model analyzes the request and, instead of generating a text-only reply, it returns a response object containing a "tool call" instruction. The script then iterates through any tool calls in the response. For each call, it retrieves the function name and arguments, looks up the corresponding function in the available-functions dictionary, and executes it with the provided arguments. The final result from the tool is then printed to the console, completing the request.

## Wrap Up for Running Local LLMs Using Ollama

I spend most of my development time working with smaller LLMs running on Ollama (LM Studio is another good choice for running locally).

There are obvious privacy and security advantages running LLMs locally and very interesting and useful engineering problems can sometimes be solved with smaller models.