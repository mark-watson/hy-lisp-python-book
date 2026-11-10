;; server.hy -- A small REST server built on the standard library.
;;
;;   GET    /health     engine status
;;   GET    /triples    every triple with its source
;;   POST   /triples    add    {"subject": .., "predicate": .., "object": ..}
;;   DELETE /triples    remove {"subject": .., "predicate": .., "object": ..}
;;   POST   /query      one pattern; null or "?name" fields are variables
;;   POST   /ask        a join: {"select": ["?a"], "where": [[s, p, o], ...]}
;;   POST   /ingest     {"text": ".."} extracts triples with the model
;;
;; In JSON a term is a string. "?name" is a variable, a predicate written
;; "~name" is neural, and any other string becomes a keyword.

(import json)
(import http.server [BaseHTTPRequestHandler ThreadingHTTPServer])
(import hy.models [Keyword])
(import nsk.terms [Var Neural to-keyword])
(import nsk.query [run-query saturate])
(import nsk [neural])


(defn json-to-term [value role]
  (cond
    (is value None) (Var role)
    (and (isinstance value str) (.startswith value "?")) (Var (cut value 1 None))
    (and (isinstance value str) (.startswith value "~"))
      (Neural (to-keyword (cut value 1 None)))
    (isinstance value str)
      (or (to-keyword value) (raise (ValueError f"empty term: {value !r}")))
    True value))

(defn term-to-json [term]
  (cond (isinstance term Keyword) term.name
        (isinstance term Var) (+ "?" term.name)
        True term))

(defn triple-to-json [triple]
  (list (map term-to-json triple)))

(defn fields-to-pattern [body]
  (tuple (gfor role ["subject" "predicate" "object"]
               (json-to-term (.get body role) role))))

(defn result-to-json [result]
  "Render a QueryResult. The provenance list names every triple in the answer
  that the model inferred or a rule derived."
  (setv provenance [])
  (for [used result.support]
    (for [[triple source] used]
      (setv item {"triple" (triple-to-json triple)  "source" source})
      (when (not-in item provenance)
        (.append provenance item))))
  {"count" (len result)
   "results" (lfor row result
               (dfor [name value] (.items row) name (term-to-json value)))
   "provenance" provenance})

(defn handle [graph method path body]
  "Route one request. Return (status, payload). This function does no I/O, so
  the tests call it directly."
  (setv route #(method (or (.rstrip (get (.split path "?") 0) "/") "/")))
  (cond
    (= route #("GET" "/health"))
      #(200 {"status" "ok"
             "triples" (len graph)
             "rules" (len graph.rules)
             "model" (get neural.config "model")})
    (= route #("GET" "/triples"))
      (with [graph.lock]
        (saturate graph)
        #(200 {"triples" (lfor [triple source] (graph.facts)
                           {"triple" (triple-to-json triple)  "source" source})}))
    (= route #("POST" "/triples"))
      #(200 {"added" (graph.add (fields-to-pattern body))  "triples" (len graph)})
    (= route #("DELETE" "/triples"))
      #(200 {"removed" (graph.remove (fields-to-pattern body))
             "triples" (len graph)})
    (= route #("POST" "/query"))
      #(200 (result-to-json (run-query [(fields-to-pattern body)] :graph graph)))
    (= route #("POST" "/ask"))
      (do
        (setv where (lfor [n row] (enumerate (.get body "where" []))
                          (tuple (gfor [role value] (zip "spo" row)
                                       (json-to-term value f"_{role}{n}"))))
              select (.get body "select"))
        #(200 (result-to-json
                (run-query where
                           (if select (lfor name select (json-to-term name None)) None)
                           :graph graph
                           :limit (.get body "limit")))))
    (= route #("POST" "/ingest"))
      #(200 {"added" (lfor triple (neural.ingest (.get body "text" "") graph)
                       (triple-to-json triple))})
    True #(404 {"error" f"no route for {method} {path}"})))


(defclass Handler [BaseHTTPRequestHandler]

  (defn respond [self]
    (try
      (setv length (int (or (self.headers.get "Content-Length") 0))
            body (if length (json.loads (self.rfile.read length)) {}))
      (when (not (isinstance body dict))
        (raise (ValueError "the request body must be a JSON object")))
      (setv [status payload] (handle self.server.graph self.command self.path body))
      (except [e [ValueError TypeError KeyError]]
        (setv [status payload] #(400 {"error" (str e)}))))
    (setv data (.encode (json.dumps payload) "utf-8"))
    (self.send-response status)
    (self.send-header "Content-Type" "application/json")
    (self.send-header "Content-Length" (str (len data)))
    (self.end-headers)
    (self.wfile.write data))

  (setv do-GET respond
        do-POST respond
        do-DELETE respond)

  (defn log-message [self #* args]
    None))


(defn make-server [graph [host "127.0.0.1"] [port 8800]]
  "Create the server without starting it. Port 0 picks a free port."
  (setv server (ThreadingHTTPServer #(host port) Handler)
        server.graph graph)
  server)

(defn serve [graph [host "127.0.0.1"] [port 8800]]
  "Serve until interrupted."
  (setv server (make-server graph host port))
  (print f"NSK serving on http://{host}:{(get server.server-address 1)}  (Ctrl-C to stop)"
         :flush True)
  (try
    (server.serve-forever)
    (except [KeyboardInterrupt]
      (print))
    (finally
      (server.server-close))))
