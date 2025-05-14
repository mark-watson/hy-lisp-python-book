# Using Google Gemini API

As I write this chapter in May 2025, I primarily Google Gemini when I use commercial LLM APIs (most of my work involves running local LLM models using Ollama).

Overall, the Google Gemini APIs provide a powerful and easy-to-use tool for developers to integrate advanced language processing capabilities into their applications, and can be a game changer for developers looking to add natural language processing capabilities to their projects.

Google Gemini offers two features that set it apart from other commercial APIs:

- Supports a one million token context size.
- Very low cost.

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
$ venv/bin/hy completion.hy                     
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

## Wrap Up for Using the Gemini APIs

There are many good commercial LLM APIs (and I have used all of them) but I currently most frequently use Gemini for two reasons: supports a one million token context size and very low cost.

I discuss Gemini in more detail in another book that you can read online: [https://leanpub.com/solo-ai/read](https://leanpub.com/solo-ai/read).