(import os)
(import google [genai])
(import pprint [pprint])

;; ======================================================================
;; context_url.hy - Demonstrates URL Context tool with Gemini API
;; ======================================================================
;; This script uses the url_context tool to allow Gemini to access and analyze
;; web page content directly from a URL.
;;
;; Prerequisites:
;;   - Set the GOOGLE_API_KEY environment variable
;;   - Install the Google AI SDK: pip install google-generativeai
;;
;; Usage:
;;   hy context_url.hy
;;   (or import and call context_qa() function)
;;
;; Example prompt format: "<URL> <question about the page>"
;;
;; ======================================================================

;; Set environment variable: GOOGLE_API_KEY must be set before running

(setv client (genai.Client))  ;; Initialize the Google AI client
      
(defn context_qa [prompt]
  """Calls the Gemini API using the url_context tool.
  
  The prompt should contain both a URL and a question about its content.
  
  Args:
    prompt - A string combining URL and question, e.g.,
             "https://example.com What is the main topic?"
  
  Returns:
    The text response from Gemini based on the URL content."""

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

