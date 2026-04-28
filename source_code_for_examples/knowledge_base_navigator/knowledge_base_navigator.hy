;;; knowledge_base_navigator.hy
;;;
;;; An AI-powered Knowledge Base Navigator using the Gemini API.
;;; Extracts entities from natural language, then retrieves detailed
;;; encyclopedic information and discovers relationships between entities.

(import google [genai])

;; The google-genai SDK reads GOOGLE_API_KEY from the environment automatically.
(setv client (genai.Client))

(defn get-gemini-response [prompt #** kwargs]
  "Send a prompt to Gemini and return the text response.
   Accepts optional keyword arguments passed to generate_content config."
  (setv config (| {"tools" [{"google_search" {}}]} kwargs))
  (setv response
    (client.models.generate_content
      :model "gemini-2.5-flash"
      :contents prompt
      :config config))
  response.text)

(defn extract-entities [user-text]
  "Ask Gemini to identify encyclopedic entities in the user's text.
   Returns the raw numbered-list text from Gemini."
  (setv prompt
    (+ "Analyze the following user text: \"" user-text "\".\n"
       "Identify potential encyclopedic entities (people, companies, "
       "countries, cities, products, concepts, etc.) mentioned.\n"
       "Categorize them if necessary. Return them as a neatly formatted "
       "numbered list (1., 2., 3., etc.) with a short 1-sentence "
       "description for each.\n"
       "DO NOT return any other conversational text, ONLY the numbered "
       "list so the user can see their options."))
  (get-gemini-response prompt))

(defn parse-selections [selection-line]
  "Parse a string of space- or comma-separated numbers into a list of ints.
   Non-numeric tokens are silently ignored."
  (setv tokens (.split (.replace selection-line "," " ")))
  (setv result [])
  (for [token tokens]
    (when (.strip token)
      (try
        (.append result (int (.strip token)))
        (except [ValueError]
          None))))
  result)

(defn get-entity-details [entity-list-text indices]
  "Ask Gemini for detailed facts and relationships for selected entities.
   entity-list-text is the numbered list from extract-entities.
   indices is a list of integers the user selected."
  (setv index-str (.join ", " (lfor i indices (str i))))
  (setv prompt
    (+ "Review this numbered list of entities:\n"
       entity-list-text "\n\n"
       "The user has specifically selected the following entity numbers "
       "from the list: " index-str ".\n"
       "Task 1: For each selected entity, generate detailed, factual, "
       "encyclopedic information (like birth place, description, and "
       "relationships for people; industry, net income, description, "
       "relationships for companies; and similar details for countries, "
       "cities, or products).\n"
       "Task 2: Evaluate ALL the selected entities collectively and "
       "explicitly summarize any known relationships, associations, or "
       "historical connections among them.\n"
       "Format the output carefully with clean section headers and "
       "bullet points."))
  (get-gemini-response prompt))

(defn kbn-ui []
  "Main interactive loop for the Knowledge Base Navigator."
  (while True
    (print "\n============= GEMINI KNOWLEDGE BASE NAVIGATOR =============")
    (print "\nEnter entity names or a descriptive sentence (or 'quit' to exit):")
    (setv prompt (input "> "))

    (when (in (.lower (.strip prompt)) ["quit" "q"])
      (print "Goodbye!")
      (break))

    (when (> (len (.strip prompt)) 0)
      (print "\n[Extracting entities using Gemini...]")
      (setv entity-list-text (extract-entities prompt))

      (if (is entity-list-text None)
        (print "\n[Error getting entity list from Gemini. Please try again.]")
        (do
          (print (+ "\n--- IDENTIFIED ENTITIES ---\n"
                    entity-list-text
                    "\n---------------------------"))
          (print "\nEnter the numbers of entities for detailed info (space or comma separated):")
          (setv selection-line (input "> "))
          (setv indices (parse-selections selection-line))

          (if (= (len indices) 0)
            (print "\n[No valid selections made. Skipping to next prompt.]")
            (do
              (print "\n[Fetching detailed facts and relationships...]")
              (setv details (get-entity-details entity-list-text indices))
              (print (+ "\n" details)))))))))

;; Entry point
(when (= __name__ "__main__")
  (kbn-ui))
