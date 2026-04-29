(import os)
(import json)
(import threading)
(import tkinter :as tk)
(import tkinter.ttk :as ttk)
(import tkinter.scrolledtext :as st)
(import requests)

(setv api-key (os.getenv "GOOGLE_API_KEY"))

;; ---------------------------------------------------------------------------
;; API call (runs in background thread)
;; ---------------------------------------------------------------------------

(defn call-gemini [chat-history user-input use-search model temperature]
  (setv headers {"Content-Type" "application/json"})

  (setv contents [])
  (for [message chat-history]
    (.append contents message))
  (.append contents {"role" "user" "parts" [{"text" user-input}]})

  (setv body {
    "contents" contents
    "generationConfig" {
      "maxOutputTokens" 4096
      "temperature" temperature}})

  (when use-search
    (setv (get body "tools") [{"google_search" {}}]))

  (setv url f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api-key}")
  (setv response (requests.post url :headers headers :data (json.dumps body) :timeout 60))
  (. response raise-for-status)
  (response.json))

;; ---------------------------------------------------------------------------
;; Chat application class
;; ---------------------------------------------------------------------------

(defclass ChatApp []
  (defn __init__ [self]
    (setv self.root (tk.Tk))
    (.title self.root "Gemini Chat")
    (.geometry self.root "800x650")
    (.minsize self.root 500 400)

    ;; State
    (setv self.chat-history [])
    (setv self.busy False)

    ;; Model options
    (setv self.models [
      "gemini-2.5-flash"
      "gemini-2.5-pro"
      "gemini-2.5-flash-lite"])

    (self._build-ui)
    (self._bind-keys)

    ;; Center window
    (.update_idletasks self.root)
    (setv w (// (- (.winfo_screenwidth self.root) 800) 2))
    (setv h (// (- (.winfo_screenheight self.root) 650) 2))
    (.geometry self.root f"+{w}+{h}")

    (.focus self.input))

  ;; -- Layout ----------------------------------------------------------------

  (defn _build-ui [self]
    ;; Main container
    (setv self.main (ttk.Frame self.root :padding 8))
    (.pack self.main :fill tk.BOTH :expand True)

    ;; --- Control bar ---
    (setv self.control-bar (ttk.Frame self.main))
    (.pack self.control-bar :fill tk.X :pady #(0 8))

    ;; Search toggle
    (setv self.search-var (tk.BooleanVar :value False))
    (setv self.search-cb (ttk.Checkbutton
      self.control-bar :text "Web Search" :variable self.search-var))
    (.pack self.search-cb :side tk.LEFT :padx #(0 12))

    ;; Model label + dropdown
    (.pack (ttk.Label self.control-bar :text "Model:") :side tk.LEFT :padx #(0 4))
    (setv self.model-var (tk.StringVar :value (get self.models 0)))
    (setv self.model-dd (ttk.Combobox
      self.control-bar :textvariable self.model-var
      :values self.models :state "readonly" :width 22))
    (.pack self.model-dd :side tk.LEFT :padx #(0 12))

    ;; Temperature label + scale
    (.pack (ttk.Label self.control-bar :text "Temp:") :side tk.LEFT :padx #(0 4))
    (setv self.temp-var (tk.DoubleVar :value 1.0))
    (setv self.temp-scale (ttk.Scale
      self.control-bar :from 0.0 :to 2.0
      :variable self.temp-var :length 100))
    (.pack self.temp-scale :side tk.LEFT :padx #(0 4))
    (setv self.temp-label (ttk.Label self.control-bar :text "1.0" :width 4))
    (.pack self.temp-label :side tk.LEFT :padx #(0 12))

    ;; Trace temp changes to update label
    (.trace_add self.temp-var "write"
      (fn [*args] (.configure self.temp-label :text f"{(self.temp-var.get):.1f}")))

    ;; Clear button (right side)
    (setv self.clear-btn (ttk.Button
      self.control-bar :text "Clear Chat" :command self.clear-chat))
    (.pack self.clear-btn :side tk.RIGHT)

    ;; --- Chat display ---
    (setv self.display (st.ScrolledText
      self.main :wrap tk.WORD :state tk.DISABLED
      :font #("Helvetica" 12) :bg "#ffffff" :relief tk.FLAT
      :borderwidth 0 :padx 10 :pady 10))
    (.pack self.display :fill tk.BOTH :expand True :pady #(0 8))

    ;; Tag styles for user / assistant / system / error
    (.tag_configure self.display "user"
      :foreground "#0056b3" :lmargin1 40 :lmargin2 40
      :spacing1 6 :spacing3 6
      :font #("Helvetica" 12))
    (.tag_configure self.display "assistant"
      :foreground "#333333" :lmargin1 10 :lmargin2 10
      :spacing1 2 :spacing3 8
      :font #("Helvetica" 12))
    (.tag_configure self.display "system"
      :foreground "#28a745" :font #("Helvetica" 10 "italic"))
    (.tag_configure self.display "error"
      :foreground "#dc3545" :font #("Helvetica" 10 "italic"))
    (.tag_configure self.display "label"
      :foreground "#007bff" :font #("Helvetica" 10 "bold")
      :spacing1 8)

    ;; Welcome message
    (self._append "Gemini Chat" "system")
    (self._append
      "Ask anything. Toggle Web Search for live results. Ctrl+Return or Cmd+Return to send.\n"
      "system")

    ;; --- Input area ---
    (setv self.input-frame (ttk.Frame self.main))
    (.pack self.input-frame :fill tk.X)

    (setv self.input (tk.Text
      self.input-frame :height 3 :wrap tk.WORD
      :font #("Helvetica" 12) :relief tk.FLAT
      :borderwidth 1 :padx 8 :pady 6
      :bg "#ffffff" :fg "#000000"
      :insertbackground "#000000"))
    (.pack self.input :side tk.LEFT :fill tk.X :expand True :padx #(0 8))

    ;; Send button
    (setv self.send-btn (ttk.Button
      self.input-frame :text "Send" :command self.send-message))
    (.pack self.send-btn :side tk.RIGHT)

    ;; --- Status bar ---
    (setv self.status (ttk.Label self.main :text "Ready" :relief tk.SUNKEN :padding #(2 1)))
    (.pack self.status :fill tk.X :pady #(8 0)))

  ;; -- Key bindings ---------------------------------------------------------

  (defn _bind-keys [self]
    ;; Send on Ctrl+Return / Cmd+Return
    (setv send-event (fn [event]
      (self.send-message)
      "break"))
    (.bind self.input "<Control-Return>" send-event)
    (.bind self.input "<Command-Return>" send-event)

    ;; Close on Escape
    (.bind self.root "<Escape>" (fn [e] (.destroy self.root)))

    ;; Focus input on click anywhere
    (.bind self.root "<Button-1>" (fn [e]
      (when (not (isinstance (tk.Tk.winfo_containing self.root e.x_root e.y_root) tk.Text))
        (.focus self.input)))))

  ;; -- Display helpers -------------------------------------------------------

  (defn _append [self text tag]
    (.configure self.display :state tk.NORMAL)
    (setv end (.index self.display "end-1c"))

    ;; Add role label for user/assistant
    (when (in tag ["user" "assistant"])
      (setv label "You")
      (if (= tag "user") (setv label "You") (setv label "Gemini"))
      ;;(when (= tag "user") (setv label "You"))
      (when (= tag "assistant") (setv label "Gemini"))
      (.insert self.display f"{end} lineend" f"{label}\n" "label"))

    (.insert self.display f"{end} lineend" f"{text}\n" tag)
    (.configure self.display :state tk.DISABLED)
    (.see self.display tk.END))

  (defn _show-status [self text]
    (.configure self.status :text text))

  ;; -- Actions ---------------------------------------------------------------

  (defn send-message [self]
    (when self.busy (return))

    (setv user-text (.strip (.get self.input "1.0" tk.END)))
    (when (not user-text) (return))

    ;; Clear input
    (.delete self.input "1.0" tk.END)

    ;; Display user message
    (self._append user-text "user")

    ;; Capture state for the thread
    (setv use-search (self.search-var.get))
    (setv model (self.model-var.get))
    (setv temperature (self.temp-var.get))
    (setv history (list self.chat-history))

    ;; Disable UI
    (setv self.busy True)
    (.configure self.send-btn :state tk.DISABLED)
    (self._show-status (if use-search "Searching..." "Thinking..."))

    ;; Run API call in background thread
    (.start (threading.Thread
      :target (fn []
        (try
          (setv response (call-gemini history user-text use-search model temperature))
          (setv candidates (get response "candidates"))
          (setv first-candidate (get candidates 0))
          (setv content (get first-candidate "content"))
          (setv parts (.get content "parts" []))
          (setv assistant-text "")
          (when parts
            (setv assistant-text (get (get parts 0) "text")))

          ;; Update UI from main thread
          (.after self.root 0 (fn []
            (when assistant-text
              (self._append assistant-text "assistant")
              (.append self.chat-history
                {"role" "user" "parts" [{"text" user-text}]})
              (.append self.chat-history
                {"role" "model" "parts" [{"text" assistant-text}]}))
            (when (not assistant-text)
              (self._append "[no response from model]" "error"))
            (setv self.busy False)
            (.configure self.send-btn :state tk.NORMAL)
            (self._show-status "Ready")
            (.focus self.input)))

          (except [e Exception]
            (.after self.root 0 (fn []
              (self._append f"Error: {e}" "error")
              (setv self.busy False)
              (.configure self.send-btn :state tk.NORMAL)
              (self._show-status "Error — see details above")
              (.focus self.input))))))
      :daemon True)))

  (defn clear-chat [self]
    (setv self.chat-history [])
    (.configure self.display :state tk.NORMAL)
    (.delete self.display "1.0" tk.END)
    (.configure self.display :state tk.DISABLED)
    (self._append "Chat cleared." "system")
    (self._show-status "Ready")
    (.focus self.input))

  (defn run [self]
    (try
      (.mainloop self.root)
      (except [KeyboardInterrupt]
        (.destroy self.root)))))

;; ---------------------------------------------------------------------------
;; Entry point
;; ---------------------------------------------------------------------------

(when (= __name__ "__main__")
  (when (not api-key)
    (print "Error: GOOGLE_API_KEY environment variable not set.")
    (import sys)
    (sys.exit 1))

  (setv app (ChatApp))
  (.run app))
