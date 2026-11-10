;; html_dsl.hy -- Compile-time HTML and SVG DSL with static string folding.

(import html :as py-html)
(import hy.models [Dict Expression Float Integer Keyword List String])


(setv VOID-TAGS #{"area" "base" "br" "col" "embed" "hr" "img"
                  "input" "link" "meta" "source" "track" "wbr"})


(defclass RawHtml []
  "Wrapper for pre-rendered HTML/SVG strings that must not be escaped again."
  (defn __init__ [self text]
    (setv self.text (str text)))

  (defn __str__ [self]
    self.text)

  (defn __repr__ [self]
    f"(RawHtml {(hy.repr self.text)})")

  (defn __eq__ [self other]
    (cond
      (isinstance other RawHtml) (= self.text other.text)
      (isinstance other str) (= self.text other)
      True False)))


(defn raw [text]
  "Mark a string as trusted HTML so render-child does not escape it."
  (RawHtml text))


(defn scalar-to-str [value]
  "Convert Hy model scalars (Integer, Float, String) or Python values to str."
  (cond
    (isinstance value Integer) (str (int value))
    (isinstance value Float) (str (float value))
    True (str value)))


(defn escape-html [value]
  "Escape special HTML characters (&, <, >, quotes) in value."
  (py-html.escape (scalar-to-str value) :quote True))


(defn attr-name [key]
  "Convert a keyword or string key into an HTML attribute name."
  (if (isinstance key Keyword)
      key.name
      (str key)))


(defn render-attr [key value]
  "Render one HTML attribute at run time.
  Boolean True renders a bare attribute; False or None omits the attribute."
  (setv name (attr-name key))
  (cond
    (or (is value None) (is value False)) ""
    (is value True) f" {name}"
    True f" {name}=\"{(escape-html value)}\""))


(defn render-child [value]
  "Render a dynamic child value at run time with automatic HTML escaping."
  (cond
    (or (is value None) (is value False)) ""
    (isinstance value RawHtml) value.text
    (isinstance value #(list tuple))
      (.join "" (gfor item value (render-child item)))
    (hasattr value "__iter__")
      (if (isinstance value #(str bytes))
          (escape-html value)
          (.join "" (gfor item value (render-child item))))
    True (escape-html value)))


(defn literal-scalar? [form]
  (isinstance form #(String Integer Float)))


(defn tag-form? [form]
  "True when form is [:tag ...] or (:tag ...) with a Keyword head."
  (and (isinstance form #(List Expression))
       (> (len form) 0)
       (isinstance (get form 0) Keyword)))


(defn compile-attrs [attr-dict]
  "Compile a Hy Dict model of attributes into a list of segments."
  (setv items (list attr-dict))
  (when (% (len items) 2)
    (raise (SyntaxError "Attribute dictionary must have key/value pairs")))
  (setv segments [])
  (for [idx (range 0 (len items) 2)]
    (setv k (get items idx)
          v (get items (+ idx 1))
          name (if (isinstance k #(Keyword String)) (attr-name k) None))
    (cond
      (and name (literal-scalar? v))
        (.append segments f" {name}=\"{(escape-html v)}\"")
      (and name (= v 'True))
        (.append segments f" {name}")
      (and name (or (= v 'False) (= v 'None)))
        None
      name
        (.append segments `(hy.I.html_dsl.render-attr ~(String name) ~v))
      True
        (.append segments `(hy.I.html_dsl.render-attr ~k ~v))))
  segments)


(defn compile-node [form]
  "Compile one DSL node into a list of static strings and runtime expressions."
  (cond
    (tag-form? form)
      (do
        (setv tag (. (get form 0) name)
              rest-forms (list (cut form 1 None))
              has-attrs (and rest-forms (isinstance (get rest-forms 0) Dict))
              attr-form (if has-attrs (get rest-forms 0) None)
              children (if has-attrs (cut rest-forms 1 None) rest-forms)
              segments [f"<{tag}"])
        (when (is-not attr-form None)
          (.extend segments (compile-attrs attr-form)))
        (.append segments ">")
        (if (in tag VOID-TAGS)
            (when children
              (raise (SyntaxError f"Void HTML element <{tag}> cannot have children")))
            (do
              (for [child children]
                (.extend segments (compile-node child)))
              (.append segments f"</{tag}>")))
        segments)
    (literal-scalar? form)
      [(escape-html form)]
    True
      [`(hy.I.html_dsl.render-child ~form)]))


(defn merge-segments [segments]
  "Coalesce adjacent compile-time string segments into single String models."
  (setv merged [])
  (for [seg segments]
    (if (isinstance seg str)
        (if (and merged (isinstance (get merged -1) String))
            (setv (get merged -1) (String (+ (str (get merged -1)) seg)))
            (.append merged (String seg)))
        (.append merged seg)))
  merged)


(defn build-html-expr [nodes]
  "Compile a sequence of nodes into a RawHtml construction form."
  (setv raw-segments [])
  (for [node nodes]
    (.extend raw-segments (compile-node node)))
  (setv merged (merge-segments raw-segments))
  (cond
    (not merged)
      `(hy.I.html_dsl.RawHtml "")
    (and (= (len merged) 1) (isinstance (get merged 0) String))
      `(hy.I.html_dsl.RawHtml ~(get merged 0))
    True
      `(hy.I.html_dsl.RawHtml (.join "" [~@merged]))))


(defmacro html [#* nodes]
  "Compile nested [:tag {:attr val} ...] forms into a RawHtml value.
  Static tags, attributes, and text are folded into string literals at
  compile time; dynamic expressions are escaped at run time."
  (hy.I.html_dsl.build-html-expr nodes))


(defmacro svg [attrs #* children]
  "Compile an inline <svg> element with the default SVG xmlns attribute."
  (when (not (isinstance attrs Dict))
    (raise (SyntaxError "svg expects an attribute dict as its first argument")))
  (setv items (list attrs)
        keys (lfor i (range 0 (len items) 2) (attr-name (get items i)))
        full-items (if (in "xmlns" keys)
                       items
                       [(Keyword "xmlns") (String "http://www.w3.org/2000/svg") #* items])
        svg-node (List [(Keyword "svg") (Dict full-items) #* children]))
  (hy.I.html_dsl.build-html-expr [svg-node]))
