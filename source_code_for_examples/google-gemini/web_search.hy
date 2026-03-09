(import sys)
(import google [genai])

;; Set environment variable: "GOOGLE_API_KEY"

(setv client (genai.Client))

(defn web-search [query]
  "Calls the Gemini API using the google_search tool with a user query"

  (setv response
    (client.models.generate_content
      :model "gemini-2.5-flash"
      :contents query
      :config {"tools" [{"google_search" {}}]}))

  (return response.text))

(when (= __name__ "__main__")
  (when (< (len sys.argv) 2)
    (print "Usage: hy web_search.hy \"your query here\"")
    (sys.exit 1))

  (setv query (get sys.argv 1))
  (print (web-search query)))
