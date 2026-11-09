;; Tests for plot_relu.hy and plot_sigmoid.hy  --  run with:  uv run pytest
;;
;; conftest.py selects the non-interactive "Agg" backend, so importing the
;; scripts draws the plots without opening a window.

(import math)
(import numpy :as np)
(import matplotlib.pyplot :as plt)
(import pytest)

(import plot-relu)
(import plot-sigmoid)


;; ---------- relu ----------

(defn test-relu-values []
  (assert (= (.tolist (plot-relu.relu (np.array [-2.0 0.0 3.5]))) [0.0 0.0 3.5])))

(defn test-relu-scalar []
  (assert (= (plot-relu.relu -1) 0.0))
  (assert (= (plot-relu.relu 4) 4.0)))


;; ---------- sigmoid ----------

(defn test-sigmoid-at-zero []
  (assert (= (plot-sigmoid.sigmoid 0) 0.5)))

(defn test-sigmoid-is-bounded-and-increasing []
  (setv ys (plot-sigmoid.sigmoid plot-sigmoid.X))
  (assert (np.all (> ys 0)))
  (assert (np.all (< ys 1)))
  (assert (np.all (> (np.diff ys) 0))))

(defn test-sigmoid-symmetry []
  (for [v [0.5 1.0 3.0]]
    (assert (math.isclose (+ (plot-sigmoid.sigmoid v) (plot-sigmoid.sigmoid (- v)))
                          1.0))))


;; ---------- plot data ----------

(defn test-x-axis-range []
  (for [m [plot-relu plot-sigmoid]]
    (assert (= (len m.X) 50))
    (assert (= (get m.X 0) -8.0))
    (assert (= (get m.X -1) 8.0))))

(defn test-plot-labels []
  ;; the most recently imported script owns the current figure
  (setv ax (plt.gca))
  (assert (= (.get-title ax) "Sigmoid Function"))
  (assert (= (.get-xlabel ax) "X"))
  (assert (= (.get-ylabel ax) "Sigmoid")))
