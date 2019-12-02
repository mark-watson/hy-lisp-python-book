# Writing Web Applications

TBD wrap Flask

Python has good libraries and frameworks for building web applications and here we will use the **Flask** library and framework "under the hood" and write a Hy Language API for making it even simpler to build web applications.

I like light weight web frameworks. In Ruby I use Sinatra, in Haskell I use Spock, and when I built Java web apps I liked light weight tools like JSP. Flask is simple but capable and using it from Hy is productive and fun.

TBD
## Getting Started With Flask

You will need to install Flask using:

        pip install flask

I first used Flask with the Hy language afer seeing a post of code from HN user "volent", seen in the file **flask_test.hy** in the directory **hy-lisp-python/webapp**:

{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

;; snippet by HN user volent:

(import [flask [Flask]])

(setv app (Flask "Flask test"))
(with-decorator (app.route "/")
  (defn index []
    "Hello World !"))
(app.run)
~~~~~~~~

TBD, explain above code

The **with-decorator** macro is used to use Python code with annotations. The Python version would be:

{lang="python",linenos=on}
~~~~~~~~
@app.route('/')
  def index():
     return "Hello World !")
~~~~~~~~

I liked this and started real use of Hy and Flask. Please try running this example to make sure you are setup properly with Flask:

{lang="bash",linenos=off}
~~~~~~~~
(base) Marks-MacBook:webapp $ ./flask_test.hy 
 * Serving Flask app "Flask test" (lazy loading)
 * Environment: production
   WARNING: This is a development server. Do not use it in a production deployment.
   Use a production WSGI server instead.
 * Debug mode: off
 * Running on http://127.0.0.1:5000/ (Press CTRL+C to quit)
~~~~~~~~

## Using Jinja2 Templates To Generate HTML

{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import [flask [Flask render_template request]])

(setv app (Flask "Flask and Jinja2 test"))

(with-decorator (app.route "/")
  (defn index []
    (render_template "template1.j2")))

(with-decorator (app.route "/response" :methods ["POST"])
  (defn response []
    (setv name (request.form.get "name"))
    (print name)
    (render_template "template1.j2" :name name)))

(app.run)
~~~~~~~~

The template file **templates/template1.j2** contains:


{lang="html",linenos=on}
~~~~~~~~
<html>
  <head>
    <title>Testing Jinja2 and Flask with the Hy language</title>
  </head>
  <body>
     {% if name %}
       <h1>Hello {{name}}</h1>
     {% else %}
       <h1>Hey, please enter your name!</h1>
     {% endif %}
    
    <form method="POST" action="/response">
      Name: <input type="text" name="name" required>
      <input type="submit" value="Submit">
    </form>
  </body>
</html>
~~~~~~~~
