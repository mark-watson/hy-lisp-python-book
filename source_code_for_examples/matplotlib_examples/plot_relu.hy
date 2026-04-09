;; Import NumPy library for numerical operations
(import numpy :as np)

;; Import Matplotlib's pyplot for plotting
(import matplotlib.pyplot :as plt)

;; Define the ReLU (Rectified Linear Unit) activation function
;; ReLU returns 0 for negative inputs and the identity for positive inputs
;; Mathematically: f(x) = max(0, x)
(defn relu [x]
  (np.maximum 0.0 x))

;; Create an array of 50 evenly spaced values from -8 to 8
;; This serves as our X-axis values for the plot
(setv X (np.linspace -8 8 50))

;; Plot X values against ReLU(X) values
(plt.plot X (relu X))

;; Add a title to the plot
(plt.title "Relu (Rectilinear) Function")

;; Label the Y-axis
(plt.ylabel "Relu")

;; Label the X-axis
(plt.xlabel "X")

;; Display grid lines on the plot
(plt.grid)

;; Show the plot window
(plt.show)