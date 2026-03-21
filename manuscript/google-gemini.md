# Using Google Gemini API

I primarily choose Google Gemini when I use commercial LLM APIs (most of my work involves running local LLM models using Ollama).

**Note: I updated this chapter in March 2026 adding a section at the end of this chapter on the new experimental Gemini Interactions APIs.**

Overall, the Google Gemini APIs provide a powerful and easy-to-use tool for developers to integrate advanced language processing capabilities into their applications, and can be a game changer for developers looking to add natural language processing capabilities to their projects.

Google Gemini offers two features that set it apart from other commercial APIs:

- Supports a one million token context size.
- Very low cost.

We will look at two ways to access Gemini and we will look at examples for each technique:

- Use the Python **requests** library to use Gemini's REST style interface.
- Use Google's Python **google-genai** package (and we will look at tool use in the same example).

## REST Interface

The following example calls the Gemini completion API and stores user chat in a persistent context.

Here is a listing or the source file **google-gemini/chat.hy**:


```hy
(import os)
(import requests)
(import json) ;; Explicitly import json for dumps

;; Get API key from environment variable (standard practice)
(setv api-key (os.getenv "GOOGLE_API_KEY"))

;; Gemini API endpoint
(setv api-url f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={api-key}")

;; Initialize the chat history (Note: Gemini uses 'user' and 'model')
(setv chat-history [])

(defn call-gemini [chat-history user-input]
  "Calls the Gemini API with the chat history and user input using requests."

  (setv headers {"Content-Type" "application/json"})

  ;; Build the contents list, correctly alternating roles.
  (setv contents [])
  (for [message chat-history]
    (.append contents message))
  (.append contents {"role" "user" "parts" [{"text" user-input}]})

  (setv data {
              "contents" contents
              "generationConfig" {
                                  "maxOutputTokens" 200
                                  "temperature" 1.2
                                  }})

  ;; Use json.dumps to convert the Python/Hy dict to a JSON string
  (setv response (requests.post api-url :headers headers :data (json.dumps data)))

  ;; Raise HTTPError for bad responses (4xx or 5xx)
  (. response raise_for-status)

  ;; Return the JSON response as a Hy dictionary/list
  (response.json))

;; --- Main Chat Loop ---
(while True
  ;; Get user input from the console
  (setv user-input (input "You: "))


  ;; Call the Gemini API
  (setv response-data (call-gemini chat-history user-input))

  ;; Debug print (optional)
  ;; (print "Raw response data:" response-data)

  ;; Extract and print the assistant's message
  ;; Using sequential gets for clarity, assumes expected structure
  (setv candidates (get response-data "candidates"))
  (setv first-candidate (get candidates 0))
  (setv content (get first-candidate "content"))
  
  (setv parts (get content "parts"))

  (setv assistant-message (get (get parts 0) "text"))
  (print "Assistant:" assistant-message)

  ;; Append BOTH user and assistant messages to chat history (important for context)
  (.append chat-history {"role" "user" "parts" [{"text" user-input}]})
  (.append chat-history {"role" "model" "parts" [{"text" assistant-message}]}))
```
This example differs from the OpenAI API example in the previous chapter in two ways:

- It implements a chat (multiple user input conversation) interface.
- It uses the low level Python **requests** library since the Google Gemini library has some incompatibilities with the Hy language system.

Here is a sample output showing how the user chat complex is used:

```text
$ uv sync
$ uv run hy chat.hy                    
You: set the value of the variable X to 1 + 7
Assistant: python
X = 1 + 7


This code will:

1. **Calculate:**  1 + 7, which results in 8.
2. **Assign:** Assign the value 8 to the variable named `X`.

You: print the value of X + 3
Assistant: python
X = 1 + 7  # Make sure X is defined as 8
print(X + 3)


This code will:

1. **Calculate:** Take the current value of X (which is 8) and add 3 to it, resulting in 11.
2. **Print:** Display the result (11) on the console.

You: print the value of X + 3
Assistant: python
X = 1 + 7  # Make sure X is defined as 8
print(X + 3)

This code will:

1. **Calculate:** Take the current value of `X` (which is 8) and add 3 to it, resulting in 11.
2. **Print:** Display the result (11) on the console.

You: 

```

## Using Google's Python Package to Access Gemini

We use the package **google-genai** in the example **context_url.hy**:

```hy
(import os)
(import google [genai])
(import pprint [pprint])

;; Set enviroment variable: "GOOGLE_API_KEY"

(setv client (genai.Client))
      
(defn context_qa [prompt]
  "Calls the Gemini API using url_context tool with a prompt containing both a URI and user question"

  (setv
    response
    (client.models.generate_content
      :model "gemini-2.5-flash"
      :contents prompt
      :config {"tools" [{"url_context" {}}]}))

  (return response.text))

(when (= __name__ "__main__")
  (print
    (context_qa
      "https://markwatson.com What musical instruments does Mark Watson play?")))
```

The tool **url_context** is called automatically when a URI is present in a user prompt. A prompt can also contain multiple URIs and they are all used in generating text from the input prompt.

The output for this example is:

```
$ uv run hy context_url.hy                                    
Mark Watson plays the guitar, didgeridoo, and American Indian flute.
```

If you want to reuse this example without using tools, just remove the option **:config {"tools" [{"url_context" {}}]}**.

The GitHub repository for the this Google package also contains useful examples and documentation links: [https://github.com/googleapis/python-genai](https://github.com/googleapis/python-genai).

## New Experimental Gemini Interactions APIs

This code listing demonstrates the powerful synergy between Google's latest generative AI capabilities and the expressive, Lisp-like syntax of the Hy language. By leveraging the `google.genai` library, the script orchestrates a new experimental "Interaction" that bridges the gap between real-world web data and private, localized business logic. It begins by initializing a Gemini client and defining a structured schema for a custom tool, `check_inventory`, which simulates an internal database lookup. The core of the program lies in the `client.interactions.create` call, where a natural language prompt triggers a multi-step workflow: first, utilizing the built-in Google Search tool to identify current market trends, and subsequently, preparing to invoke the local inventory function for those specific items. This approach highlights how modern LLMs have evolved from simple text generators into central reasoning engines capable of coordinating complex tool-calling sequences across disparate data environments.

```hy
(import google [genai])

;; Set environment variable: "GOOGLE_API_KEY"
;; More info:
;; https://blog.google/innovation-and-ai/technology/developers-tools/gemini-api-tooling-updates/
;; https://ai.google.dev/gemini-api/docs/interactions?ua=chat

(setv client (genai.Client))

;; Define a custom function tool that checks an internal inventory database
(setv check-inventory
  {"type" "function"
   "name" "check_inventory"
   "description" "Checks the internal inventory database for a specific product model."
   "parameters"
     {"type" "object"
      "properties"
        {"product_name"
           {"type" "string"
            "description" "The name or model of the product to check"}}
      "required" ["product_name"]}})

;; Create an interaction that combines a built-in Google Search tool with
;; the custom check_inventory function tool
(setv interaction
  (client.interactions.create
    :model "gemini-3-flash-preview"
    :input (+ "Search the web for the top 3 trending noise-canceling headphones today, "
              "and then check if we have those specific models in our internal inventory.")
    :tools [{"type" "google_search"}   ; built-in tool
            check-inventory]))         ; custom function tool

;; Process each output from the interaction
(for [output interaction.outputs]
  (cond
    (= output.type "function_call")
      (do
        (print f"Tool ID: {output.id}")
        (print f"Calling: {output.name} with args: {output.arguments}"))
    (= output.type "text")
      (print output.text)))
```

The implementation uses Hy’s seamless interoperability with Python, allowing developers to define complex JSON-like tool schemas using native Hy dictionaries. This example was originally written in Python for the [Gemini online documentation](https://ai.google.dev/gemini-api/docs/interactions?ua=chat). By combining the Google Search built-in tool with the user defined `check_inventory` function, the code creates a unified execution context. The Gemini model intelligently determines when to use the live web versus when to request data from the local environment, returning a structured interaction object that contains both the model's reasoning and the specific tool calls required to fulfill the request.

Processing the results is handled a **for loop** that iterates over the interaction's outputs, using a `cond` macro to differentiate between raw text responses and pending function calls. This pattern is useful for production workflows because it allows an application to capture the specific arguments such as product names discovered via search and pass them into actual database queries or call local functions. This example effectively illustrates the "agentic" workflow where the AI doesn't just provide an answer, but generates the necessary "Tool ID" and argument set to drive further programmatic action.

Here is example output:

```
$ uv run hy gemini_interactions_api.hy 
UserWarning: Interactions usage is experimental and may change in future versions.
  (client.interactions.create
Tool ID: 4uu76c87
Calling: check_inventory with args: {'product_name': 'Sony WH-1000XM6'}
Tool ID: wk8lh5fn
Calling: check_inventory with args: {'product_name': 'Bose QuietComfort Ultra Headphones (2nd Gen)'}
Tool ID: 3gkrxgyc
Calling: check_inventory with args: {'product_name': 'Apple AirPods Pro 3'}
```

Dear reader, note that these APIs may change. Please check out the documentation [https://ai.google.dev/gemini-api/docs/interactions?ua=chat](https://ai.google.dev/gemini-api/docs/interactions?ua=chat) for more use cases of the Interactions APIs.


## Wrap Up for Using the Gemini APIs

There are many good commercial LLM APIs (and I have most of them) but I currently most frequently use Gemini for two reasons: supports a one million token context size and is very low cost.

I discuss Gemini in more detail in another book that you can read online: [https://leanpub.com/solo-ai/read](https://leanpub.com/solo-ai/read).
