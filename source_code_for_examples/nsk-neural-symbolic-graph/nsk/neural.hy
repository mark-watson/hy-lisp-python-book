;; neural.hy -- The neural layer: a local model served by Ollama.
;;
;; The model does two jobs. It completes a triple when a ~ predicate finds no
;; symbolic match, and it turns free text into triples.
;;
;; Both calls pass Ollama a JSON schema, so the reply is constrained to the
;; shape we ask for. The ollama package is imported only when a call is made;
;; the symbolic engine runs without it and without a daemon.

(import json)
(import os)
(import sys)
(import time)
(import nsk.terms [Var show to-keyword])

(setv config
  {"model" (os.environ.get "NSK_MODEL" "qwen3.5:4b")
   "host" (os.environ.get "OLLAMA_HOST" "http://localhost:11434")
   "enabled" True      ; False turns every ~ predicate into a plain one
   "cache" True        ; store inferred triples in the graph, marked "neural"
   "think" False       ; skip the reasoning phase of thinking models
   "timeout" 120})

(setv memo {})         ; question -> answer, so a join never asks twice
(setv _down-until 0)   ; after a failed call, stay quiet for a few seconds

(setv INFER-SYSTEM
  "You are the inference node of a knowledge graph. You receive known facts and one triple with a missing term, shown as ???. Reply with the single most likely value for the missing term as a short name of one to three words. Use the known facts first, then general knowledge. If neither settles the answer, reply with null instead of guessing. Reply only with JSON of the form {\"result\": \"value\"}.")

(setv INFER-SCHEMA
  {"type" "object"
   "properties" {"result" {"type" ["string" "null"]}}
   "required" ["result"]})

(setv EXTRACT-SYSTEM
  "You extract knowledge-graph triples from text. Use short lower-case names. Name each entity the same way every time it appears. State only what the text says. Reply only with JSON of the form {\"triples\": [{\"subject\": \"..\", \"predicate\": \"..\", \"object\": \"..\"}]}.")

(setv EXTRACT-SCHEMA
  {"type" "object"
   "properties"
     {"triples"
       {"type" "array"
        "items" {"type" "object"
                 "properties" {"subject" {"type" "string"}
                               "predicate" {"type" "string"}
                               "object" {"type" "string"}}
                 "required" ["subject" "predicate" "object"]}}}
   "required" ["triples"]})

(setv NON-ANSWERS #{"" "null" "none" "unknown" "n/a" "???"})


(defn extract-json [text]
  "Return the first JSON object in text, or None. This tolerates a Markdown
  fence or a stray sentence around the object."
  (setv start (.find (or text "") "{"))
  (when (= start -1)
    (return None))
  (try
    (get (.raw-decode (json.JSONDecoder) text start) 0)
    (except [ValueError]
      None)))

(defn chat-json [system prompt schema]
  "Send one request to the model and return its reply as a dict. This is the
  only function that touches the network; the tests replace it with a fake."
  (import ollama)
  (setv client (ollama.Client :host (get config "host")
                              :timeout (get config "timeout"))
        response (client.chat
                   :model (get config "model")
                   :messages [{"role" "system"  "content" system}
                              {"role" "user"  "content" prompt}]
                   :format schema
                   :think (get config "think")
                   :options {"temperature" 0}))
  (or (extract-json response.message.content) {}))

(defn label [term]
  "A term as the model should read it."
  (if (isinstance term hy.models.Keyword) term.name (str term)))

(defn sentence [triple]
  (.join " " (gfor term triple (if (isinstance term Var) "???" (label term)))))

(defn context [graph term [limit 20]]
  "Facts the graph already holds about term, to ground the model's answer."
  (setv facts (+ (graph.candidates #(term (Var "p") (Var "o")))
                 (graph.candidates #((Var "s") (Var "p") term))))
  (lfor triple (cut facts limit) (sentence triple)))

(defn infer [subject predicate object graph]
  "Complete a triple that is missing its subject or its object. Return the
  full triple, or None when the model has no answer or cannot be reached."
  (global _down-until)
  (setv missing (lfor term #(subject object) (isinstance term Var)))
  (when (or (not (get config "enabled"))
            (!= (sum missing) 1)
            (isinstance predicate Var)
            (< (time.monotonic) _down-until))
    (return None))
  (setv known (if (get missing 0) object subject)
        key (sentence #(subject predicate object)))
  (when (not-in key memo)
    (setv facts (context graph known)
          prompt (+ (if facts (+ "Known facts:\n" (.join "\n" facts) "\n\n") "")
                    "Complete this triple: " key))
    (try
      (setv reply (chat-json INFER-SYSTEM prompt INFER-SCHEMA))
      (except [e Exception]
        (print f"; neural layer unavailable: {e}" :file sys.stderr)
        (setv _down-until (+ (time.monotonic) 5))
        (return None)))
    (setv answer (.get reply "result")
          (get memo key) (if (and (isinstance answer str)
                                  (not-in (.lower (.strip answer)) NON-ANSWERS))
                             (to-keyword answer)
                             None)))
  (setv value (get memo key))
  (when (is value None)
    (return None))
  (setv triple (if (get missing 0)
                   #(value predicate object)
                   #(subject predicate value)))
  (when (get config "cache")
    (graph.add triple "neural"))
  triple)

(defn text-to-triples [text]
  "Ask the model to read text and return a list of keyword triples."
  (try
    (setv reply (chat-json EXTRACT-SYSTEM text EXTRACT-SCHEMA))
    (except [e Exception]
      (print f"; neural layer unavailable: {e}" :file sys.stderr)
      (return [])))
  (setv triples [])
  (for [row (or (.get reply "triples") [])]
    (when (isinstance row dict)
      (setv triple (tuple (gfor field ["subject" "predicate" "object"]
                                (to-keyword (or (.get row field) "")))))
      (when (and (all triple) (not-in triple triples))
        (.append triples triple))))
  triples)

(defn ingest [text graph]
  "Extract triples from text and add them to graph. Return the new ones."
  (graph.add-all (text-to-triples text)))
