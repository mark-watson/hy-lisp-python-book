;; Tests for the Flask examples  --  run with:  uv run pytest
;;
;; Each app is exercised with Flask's built-in test client, so no server is
;; started. conftest.py makes this directory the current directory so Flask
;; can find templates/.

(import pytest)
(import flask-test)
(import jinja2-test)
(import cookie-test)


(defn client-for [module]
  (setv module.app.config.TESTING True)
  (.test-client module.app))


;; ---------- flask_test.hy ----------

(defn test-hello-world []
  (setv resp (.get (client-for flask-test) "/"))
  (assert (= resp.status-code 200))
  (assert (= resp.text "Hello World !")))


;; ---------- jinja2_test.hy ----------

(defn test-jinja2-index-asks-for-name []
  (setv resp (.get (client-for jinja2-test) "/"))
  (assert (= resp.status-code 200))
  (assert (in "Hey, please enter your name!" resp.text)))

(defn test-jinja2-response-greets-user []
  (setv resp (.post (client-for jinja2-test) "/response" :data {"name" "Mark"}))
  (assert (= resp.status-code 200))
  (assert (in "<h1>Hello Mark</h1>" resp.text)))

(defn test-jinja2-response-rejects-get []
  (assert (= (. (.get (client-for jinja2-test) "/response") status-code) 405)))


;; ---------- cookie_test.hy ----------

(defn test-cookie-index-without-cookie []
  (setv resp (.get (client-for cookie-test) "/"))
  (assert (in "Hey, please enter your name!" resp.text)))

(defn test-cookie-is-set-and-remembered []
  (setv client (client-for cookie-test))
  (setv resp (.post client "/response" :data {"name" "Alice"}))
  (assert (in "<h1>Hello Alice</h1>" resp.text))
  (assert (in "hy-cookie=Alice" (.get resp.headers "Set-Cookie")))
  ;; the test client sends the cookie back on the next request
  (assert (in "<h1>Hello Alice</h1>" (. (.get client "/") text))))
