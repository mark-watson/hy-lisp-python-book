;; hy_eval/ops.hy -- Operational controls: response cache, cost/token budget, and fallback router.

(import dataclasses [replace])
(import hy_eval.guardrails [GuardrailViolation detect-prompt-injection])


(defclass BudgetExceededError [Exception]
  "Raised when cumulative token usage or USD cost exceeds the configured budget.")


(defclass ResponseCache []
  "In-memory deterministic cache keyed by (model, system, prompt, temperature)."

  (defn __init__ [self]
    (setv self._store {}
          self.hits 0
          self.misses 0))

  (defn _key [self #^ str model-name #^ str system #^ str prompt #^ float temperature]
    #(model-name system prompt (round (float temperature) 4)))

  (defn get [self #^ str model-name #^ str system #^ str prompt [temperature 0.0]]
    (setv k (self._key model-name system prompt temperature))
    (if (in k self._store)
      (do
        (+= self.hits 1)
        (setv orig (get self._store k))
        (replace orig :cached True :cost-usd 0.0 :latency-ms 0.1))
      (do
        (+= self.misses 1)
        None)))

  (defn put [self #^ str model-name #^ str system #^ str prompt temperature response]
    (setv k (self._key model-name system prompt temperature))
    (setv (get self._store k) response)
    response))


(defclass BudgetTracker []
  "Tracks cumulative USD cost and token consumption against hard ceilings."

  (defn __init__ [self [max-usd 0.05] [max-tokens 50000]]
    (setv self.max-usd (float max-usd)
          self.max-tokens (int max-tokens)
          self.spent-usd 0.0
          self.used-tokens 0
          self.calls 0))

  (defn check-available [self]
    (when (>= self.spent-usd self.max-usd)
      (raise (BudgetExceededError
               f"Cost budget exhausted: spent ${self.spent-usd :.6f} >= limit ${self.max-usd :.6f}")))
    (when (>= self.used-tokens self.max-tokens)
      (raise (BudgetExceededError
               f"Token budget exhausted: used {self.used-tokens} >= limit {self.max-tokens}"))))

  (defn record [self response]
    (setv call-tokens (+ response.prompt-tokens response.completion-tokens)
          new-usd (round (+ self.spent-usd response.cost-usd) 8)
          new-tokens (+ self.used-tokens call-tokens))
    (when (> new-usd self.max-usd)
      (raise (BudgetExceededError
               f"Call exceeded USD budget: ${new-usd :.6f} > ${self.max-usd :.6f}")))
    (when (> new-tokens self.max-tokens)
      (raise (BudgetExceededError
               f"Call exceeded token budget: {new-tokens} > {self.max-tokens}")))
    (setv self.spent-usd new-usd
          self.used-tokens new-tokens)
    (+= self.calls 1)
    {"spent_usd" self.spent-usd
     "used_tokens" self.used-tokens
     "calls" self.calls}))


(defclass ModelRouter []
  "Routes LLM requests through input guardrails, cache, budget enforcement, and fallback models."

  (defn __init__ [self primary [fallbacks None] [cache None] [budget None] [tracer None] [guardrails True]]
    (setv self.primary primary
          self.fallbacks (if (is fallbacks None) [] (list fallbacks))
          self.cache cache
          self.budget budget
          self.tracer tracer
          self.guardrails guardrails
          self.fallback-count 0))

  (defn generate [self #^ str prompt [system ""] [temperature 0.0] [span-name "router.generate"]]
    (when self.guardrails
      (setv scan (detect-prompt-injection prompt))
      (when (get scan "blocked")
        (setv rules (get scan "matched_rules"))
        (raise (GuardrailViolation
                 f"Prompt blocked by injection guardrail: {rules}"))))

    (when (not (is self.cache None))
      (setv cached-resp (.get self.cache self.primary.name system prompt temperature))
      (when (not (is cached-resp None))
        (when (not (is self.tracer None))
          (.record-response self.tracer span-name prompt cached-resp :tags {"cache_hit" True}))
        (return cached-resp)))

    (when (not (is self.budget None))
      (.check-available self.budget))

    (setv models [self.primary #* self.fallbacks]
          last-err None)
    (for [[idx mdl] (enumerate models)]
      (try
        (setv resp (.generate mdl prompt :system system :temperature temperature))
        (when (> idx 0)
          (+= self.fallback-count 1))
        (when (not (is self.budget None))
          (.record self.budget resp))
        (when (not (is self.cache None))
          (.put self.cache self.primary.name system prompt temperature resp))
        (when (not (is self.tracer None))
          (.record-response self.tracer span-name prompt resp
                            :tags {"cache_hit" False "fallback_index" idx}))
        (return resp)
        (except [e BudgetExceededError]
          (raise))
        (except [e Exception]
          (setv last-err e))))

    (raise (RuntimeError f"All models in router failed; last error: {last-err}"))))
