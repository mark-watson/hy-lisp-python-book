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
