;; hy_eval/guardrails.hy -- Prompt-injection heuristics and deny-by-default tool allowlist.

(import re)
(import urllib.parse [urlparse])


(defclass GuardrailViolation [Exception]
  "Raised when a prompt or tool invocation violates safety guardrails.")


(setv _INJECTION_RULES
  [#("instruction_override"
     0.9
     (re.compile r"(?i)\b(ignore|disregard|forget|override)\s+(all\s+)?(previous|prior|above|system|developer)\s+(instructions|prompts|rules|directions)"))
   #("system_prompt_leak"
     0.85
     (re.compile r"(?i)\b(reveal|print|show|repeat|output|dump)\s+(your|the)\s+(system\s+prompt|hidden\s+instructions|developer\s+message|initial\s+prompt)"))
   #("role_hijack"
     0.9
     (re.compile r"(?i)\b(you\s+are\s+now\s+DAN|do\s+anything\s+now|act\s+as\s+an?\s+unrestricted|bypass\s+all\s+safety)"))
   #("delimiter_injection"
     0.75
     (re.compile r"(?i)(</?system>|\[INST\]|\[/INST\]|###\s*System:|<\|im_start\|>system)"))
   #("exfiltration_attempt"
     0.85
     (re.compile r"(?i)\b(exfiltrate|send\s+the\s+secret|post\s+the\s+api\s+key|upload\s+credentials)\b"))])


(defn detect-prompt-injection [#^ str text [threshold 0.7]]
  "Inspect `text` for prompt-injection patterns and return a risk assessment dict."
  (setv matched []
        max-risk 0.0)
  (for [[rule-name weight pattern] _INJECTION_RULES]
    (when (.search pattern (or text ""))
      (.append matched rule-name)
      (setv max-risk (max max-risk weight))))
  (setv risk (min 1.0 (round (+ max-risk (* 0.1 (max 0 (- (len matched) 1)))) 4)))
  {"blocked" (>= risk threshold)
   "risk_score" risk
   "matched_rules" matched})


(setv _BLOCKED_HOSTS
  #{"localhost" "127.0.0.1" "0.0.0.0" "169.254.169.254" "::1"})


(defn _is-private-host [#^ str host]
  (setv h (.lower (or host "")))
  (or (in h _BLOCKED_HOSTS)
      (.startswith h "10.")
      (.startswith h "192.168.")
      (.startswith h "172.16.")
      (.endswith h ".internal")
      (.endswith h ".local")))


(defclass ToolAllowlist []
  "Deny-by-default permission gate for agent tools and URL arguments."

  (defn __init__ [self allowed-tools [allowed-domains None]]
    (setv self.allowed-tools (set allowed-tools)
          self.allowed-domains (if (is allowed-domains None)
                                 None
                                 (set (gfor d allowed-domains (.lower d))))))

  (defn validate-call [self #^ str tool-name [arguments None]]
    "Return {\"allowed\": bool, \"reason\": str} for a proposed tool call."
    (setv args (if (is arguments None) {} (dict arguments)))
    (when (not (in tool-name self.allowed-tools))
      (return {"allowed" False
               "reason" f"Tool '{tool-name}' is not in the allowlist."}))

    (when (in "url" args)
      (setv raw-url (str (get args "url"))
            parsed (urlparse raw-url)
            scheme (.lower (or parsed.scheme ""))
            host (.lower (or parsed.hostname "")))
      (when (not (in scheme #{"http" "https"}))
        (return {"allowed" False
                 "reason" f"Disallowed URL scheme '{scheme}' in {(repr raw-url)}."}))
      (when (or (not host) (_is-private-host host))
        (return {"allowed" False
                 "reason" f"Blocked private or loopback host '{host}'."}))
      (when (not (is self.allowed-domains None))
        (setv domain-ok (any (gfor d self.allowed-domains
                                   (or (= host d) (.endswith host (+ "." d))))))
        (when (not domain-ok)
          (setv allowed-list (sorted self.allowed-domains))
          (return {"allowed" False
                   "reason" f"Host '{host}' is outside allowed domains {allowed-list}."}))))

    {"allowed" True "reason" "ok"})

  (defn enforce [self #^ str tool-name [arguments None]]
    "Validate a tool call and raise GuardrailViolation if denied."
    (setv verdict (self.validate-call tool-name arguments))
    (when (not (get verdict "allowed"))
      (raise (GuardrailViolation (get verdict "reason"))))
    verdict))
