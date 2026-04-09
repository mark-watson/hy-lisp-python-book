;; hello.hy - A simple Kivy "Hello World" application written in Hy (Lisp for Python)
;;
;; This example demonstrates:
;;   - Importing modules using Hy's import syntax
;;   - Defining a class that inherits from a Python class
;;   - Creating a basic Kivy UI with a Button widget

;; Import Kivy's App base class - all Kivy apps must inherit from App
(import kivy.app [App])

;; Import the Button widget from kivy.uix.button module
(import kivy.uix.button [Button])

;; Define a new class HelloApp that inherits from App
;; In Hy, defclass creates a class definition. The parent class(es) go in square brackets.
(defclass HelloApp [App]
  ;; The build method is the entry point for Kivy apps
  ;; It must return the root widget of the application
  (defn build [self]
    ;; Create and return a Button widget with text "Hello Hy!"
    ;; The :text keyword argument sets the button's label
    (Button :text "Hello Hy!")))

;; Create an instance of HelloApp and run the application
;; The . macro calls the run method on the HelloApp instance
(.run (HelloApp))