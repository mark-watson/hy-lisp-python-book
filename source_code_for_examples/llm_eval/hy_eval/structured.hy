;; hy_eval/structured.hy -- Pydantic schema validation with self-correcting retry loop.

(import json)
(import re)
(import pydantic [BaseModel Field ValidationError field_validator])


(defclass CitedAnswer [BaseModel]
  "Structured RAG answer with required source citations and confidence score."
  #^ str answer
  (setv #^ (get list str) citations (Field :default-factory list)
        #^ float confidence (Field :ge 0.0 :le 1.0)
        #^ bool abstained False)

  (defn [(field_validator "answer")] non-empty-answer [cls v]
    (when (not (.strip v))
      (raise (ValueError "answer must not be empty")))
    v))


(defclass ExtractedTriple [BaseModel]
  "A knowledge graph triple extracted from text."
  #^ str subject
  #^ str predicate
  #^ str object)


(defn extract-json-block [#^ str text]
  "Extract JSON object from markdown code fences or surrounding prose."
  (setv stripped (.strip (or text "")))
  (setv fence-match (re.search r"```(?:json)?\s*(\{.*?\})\s*```" stripped re.DOTALL))
  (when fence-match
    (return (.group fence-match 1)))
  (setv brace-match (re.search r"\{.*\}" stripped re.DOTALL))
  (if brace-match
    (.group brace-match 0)
    stripped))


(defn generate-structured [model schema-cls #^ str prompt [system ""] [max-retries 2]]
  "Generate a response validated against `schema-cls` (a Pydantic BaseModel).

  On invalid JSON or schema validation failure, feeds the error back to the
  model up to `max-retries` times."
  (setv schema-json (json.dumps (.model_json_schema schema-cls))
        full-system
        (+ (if system (+ system "\n\n") "")
           "Respond ONLY with valid JSON conforming to this JSON Schema:\n"
           schema-json)
        current-prompt prompt
        errors []
        last-raw "")

  (for [attempt (range (+ max-retries 1))]
    (setv resp (.generate model current-prompt :system full-system)
          last-raw resp.text)
    (try
      (setv candidate (extract-json-block resp.text)
            parsed (json.loads candidate)
            validated (.model_validate schema-cls parsed))
      (return {"valid" True
               "data" validated
               "attempts" (+ attempt 1)
               "errors" errors
               "raw_response" last-raw})
      (except [e #(json.JSONDecodeError ValidationError ValueError)]
        (setv err-msg (str e))
        (.append errors err-msg)
        (setv current-prompt
          (+ prompt
             f"\n\n[VALIDATION_RETRY_{attempt}]\n"
             f"Your previous output was invalid:\n{resp.text}\n"
             f"Validation error:\n{err-msg}\n"
             "Return ONLY corrected JSON matching the schema.")))))

  {"valid" False
   "data" None
   "attempts" (+ max-retries 1)
   "errors" errors
   "raw_response" last-raw})
