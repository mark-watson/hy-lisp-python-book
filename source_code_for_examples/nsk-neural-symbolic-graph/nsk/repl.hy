;; repl.hy -- The interactive NSK prompt.
;;
;; Each line is read with the Hy reader. Three kinds of form are understood:
;;
;;   :facts  (:add :mark :wrote :nsk)     commands
;;   [?who :wrote :nsk]                   a query; several patterns on one
;;                                        line are joined
;;   anything else                        ordinary Hy, with ask and rule ready
;;
;; Commands and bare patterns are converted to terms without being evaluated.

(import types)
(import hy.models [Keyword Expression List])
(import nsk.terms [show to-term to-pattern])
(import nsk.store [Graph use-graph])
(import nsk.query [QueryResult run-query saturate])
(import nsk [neural])

(setv BANNER "NSK: Neural-Symbolic Knowledge Graph Engine
Type :help for commands, :quit to exit.")

(setv HELP "Commands:
  :help                  show this help
  :facts                 list every triple and where it came from
  :count                 show the triple count
  (:add s p o)           add a triple, as in (:add :mark :wrote :nsk)
  (:del s p o)           remove a triple
  (:ingest \"text\")       extract triples from text with the model
  (:rule head body...)   add a rule, as in
                         (:rule [?x :grandparent ?z] [?x :parent ?y] [?y :parent ?z])
  :rules                 list the rules
  (:unrule n)            remove rule number n
  :forget                remove every triple the model inferred
  :model                 show the model; (:model \"name\") changes it
  :save                  force the log to disk
  :compact               rewrite the log to hold only the live state
  :quit                  leave the REPL

Queries:
  [?who :wrote :nsk]                       one pattern
  [?a :wrote :nsk] [?a :codes-in ?lang]    a join: patterns on one line
  [:mark ~:codes-in ?lang]                 ~ falls back to the model
  (ask [?a] [?a :wrote :nsk] :limit 1)     the ask macro, with options

Anything else is evaluated as Hy. The graph is bound to the name graph.")

(setv BARE-COMMANDS #{"help" "facts" "count" "rules" "forget" "model" "save"
                      "compact" "quit" "exit"})
(setv LIST-COMMANDS #{"add" "del" "ingest" "rule" "unrule" "model"})
(setv QUIT (object))


(defn command? [form]
  (or (and (isinstance form Keyword) (in form.name BARE-COMMANDS))
      (and (isinstance form Expression) form
           (isinstance (get form 0) Keyword)
           (in (. (get form 0) name) LIST-COMMANDS))))

(defn show-rule [rule]
  (setv [head body] rule)
  (+ (show head) " <- " (.join " " (map show body))))

(defn plural [n word]
  f"{n} {word}{(if (= n 1) "" "s")}")

(defn run-command [form graph]
  "Run one command. Return the text to print, or QUIT."
  (setv bare (isinstance form Keyword)
        name (if bare form.name (. (get form 0) name))
        args (if bare [] (list (cut form 1 None))))
  (cond
    (in name ["quit" "exit"]) QUIT
    (= name "help") HELP
    (= name "count") (plural (len graph) "triple")
    (= name "facts")
      (do
        (saturate graph)
        (.join "\n"
          (+ (lfor [triple source] (graph.facts)
                   (+ "  " (show triple)
                      (if (= source "fact") "" f"    ; {source}")))
             [f"({(plural (len graph) "triple")})"])))
    (= name "add")
      (do
        (setv triple (to-pattern (List args)))
        (if (graph.add triple) f"added {(show triple)}" "already known"))
    (= name "del")
      (do
        (setv triple (to-pattern (List args)))
        (if (graph.remove triple) f"removed {(show triple)}" "no such triple"))
    (= name "ingest")
      (do
        (setv added (neural.ingest (str (get args 0)) graph))
        (.join "\n" (+ (lfor triple added (+ "  " (show triple)))
                       [f"ingested {(plural (len added) "triple")}"])))
    (= name "rule")
      (do
        (setv patterns (lfor arg args (to-pattern arg)))
        (if (graph.add-rule (get patterns 0) (cut patterns 1 None))
            (+ "rule added: " (show-rule (get graph.rules -1)))
            "already known"))
    (= name "rules")
      (.join "\n" (+ (lfor [n rule] (enumerate graph.rules)
                           f"  {n}: {(show-rule rule)}")
                     [f"({(plural (len graph.rules) "rule")})"]))
    (= name "unrule")
      (+ "rule removed: " (show-rule (graph.remove-rule (int (get args 0)))))
    (= name "forget") f"forgot {(plural (graph.forget) "inferred triple")}"
    (= name "model")
      (do
        (when args
          (setv (get neural.config "model") (str (get args 0))))
        (+ "model: " (get neural.config "model")))
    (= name "save") (do (graph.save) "saved.")
    (= name "compact") f"log rewritten: {(plural (graph.compact) "line")}"))

(defn make-namespace [graph]
  "Build the module that ordinary Hy forms are evaluated in."
  (setv module (types.ModuleType "nsk_repl"))
  (hy.eval '(do (require nsk [ask rule])
                (import nsk)
                (import nsk [Graph Var Neural show run-query]))
           :module module)
  (setv module.graph graph)
  module)

(defn group-forms [forms]
  "Gather each run of consecutive [s p o] forms into one conjunctive query."
  (setv grouped [])
  (for [form forms]
    (if (isinstance form List)
        (if (and grouped (isinstance (get grouped -1) list))
            (.append (get grouped -1) form)
            (.append grouped [form]))
        (.append grouped form)))
  grouped)

(defn run-form [form graph module]
  "Run one grouped form. Return the text to print (maybe None), or QUIT."
  (cond
    (isinstance form list) (str (run-query (lfor p form (to-pattern p)) :graph graph))
    (command? form) (run-command form graph)
    True
      (do
        (setv value (hy.eval form :module module))
        (cond (isinstance value QueryResult) (str value)
              (is value None) None
              True (+ "=> " (hy.repr value))))))

(defn run-text [text graph module]
  "Read and run every form in text. Return (outputs, quit?)."
  (setv outputs [])
  (for [form (group-forms (list (hy.read-many text)))]
    (try
      (setv output (run-form form graph module))
      (except [e Exception]
        (setv output f"; error: {e}")))
    (when (is output QUIT)
      (return #(outputs True)))
    (when (is-not output None)
      (.append outputs output)))
  #(outputs False))

(defn repl [[graph None] [read-line input]]
  "Start the interactive loop. Line editing and history come from Python's
  readline module, so no rlwrap is needed."
  (try (import readline) (except [ImportError]))
  (setv graph (use-graph (if (is graph None) (Graph) graph))
        module (make-namespace graph)
        buffer "")
  (print BANNER)
  (while True
    (try
      (setv line (read-line (if buffer "...> " "nsk> ")))
      (except [EOFError]
        (print)
        (break))
      (except [KeyboardInterrupt]
        (print)
        (setv buffer "")
        (continue)))
    (setv buffer (+ buffer line "\n"))
    (try
      (setv [outputs done] (run-text buffer graph module))
      (except [hy.PrematureEndOfInput]
        (continue))                       ; the form continues on the next line
      (except [e Exception]
        (setv outputs [f"; read error: {e}"]
              done False)))
    (setv buffer "")
    (for [output outputs]
      (print output))
    (when done
      (break)))
  (print "Bye."))
