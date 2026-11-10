;; test_html_dsl.hy -- Tests for the compile-time HTML and SVG DSL.

(import pytest)
(import core_macros [expand-once-str])
(import html_dsl [RawHtml raw escape-html])

(require html_dsl [html svg])


(defn test-static-html-folds-at-compile-time []
  (setv exp (hy.repr (hy.macroexpand-1 '(html [:div {:class "card"} [:h1 "Title"] [:hr]]))))
  ;; Entire static tree folds into a single string literal with no .join call
  (assert (in "\"<div class=\\\"card\\\"><h1>Title</h1><hr></div>\"" exp))
  (assert (not-in ".join" exp))

  (setv out (html [:div {:class "card"} [:h1 "Title"] [:hr]]))
  (assert (isinstance out RawHtml))
  (assert (= (str out) "<div class=\"card\"><h1>Title</h1><hr></div>")))


(defn test-dynamic-escaping-and-raw-bypass []
  (setv untrusted "<img src=x onerror=\"alert(1)\">"
        safe-badge (raw "<strong>verified</strong>"))
  (setv rendered
    (str (html [:p {:title untrusted}
                "User: " untrusted " " safe-badge])))
  (assert (= rendered
             (+ "<p title=\"&lt;img src=x onerror=&quot;alert(1)&quot;&gt;\">"
                "User: &lt;img src=x onerror=&quot;alert(1)&quot;&gt; "
                "<strong>verified</strong></p>"))))


(defn test-boolean-and-dynamic-attributes []
  (setv is-disabled True
        is-hidden False
        role "button")
  (setv out
    (str (html [:button {:type "submit"
                         :disabled is-disabled
                         :hidden is-hidden
                         :data-role role
                         :aria-label None}
                "Save"])))
  (assert (= out "<button type=\"submit\" disabled data-role=\"button\">Save</button>")))


(defn test-list-and-generator-children []
  (setv names ["Lisp" "Python" "Hy"])
  (setv list-html
    (str (html [:ul (lfor n names (html [:li n]))])))
  (assert (= list-html "<ul><li>Lisp</li><li>Python</li><li>Hy</li></ul>"))

  (setv gen-html
    (str (html [:ul (gfor n names (html [:li n]))])))
  (assert (= gen-html "<ul><li>Lisp</li><li>Python</li><li>Hy</li></ul>")))


(defn test-void-tag-rejects-children-at-compile-time []
  (with [(pytest.raises Exception)]
    (hy.eval (hy.read "(do (require html_dsl [html]) (html [:br \"oops\"]))"))))


(defn test-svg-macro []
  (setv label "Hy & SVG"
        graphic
        (str (svg {:width 100 :height 50}
               [:rect {:x 0 :y 0 :width 100 :height 50 :stroke-width 2}]
               [:text {:x 50 :y 25 :text-anchor "middle"} label])))
  (assert (in "xmlns=\"http://www.w3.org/2000/svg\"" graphic))
  (assert (in "stroke-width=\"2\"" graphic))
  (assert (in ">Hy &amp; SVG</text>" graphic)))
