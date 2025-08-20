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

