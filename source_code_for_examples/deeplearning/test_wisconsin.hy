;; Tests for wisconsin.hy  --  run with:  uv run pytest
;;
;; These tests check data loading and the model's shape, and run one short
;; training pass. lstm.hy is not tested: it downloads a corpus and trains for
;; a long time as soon as it is loaded.

(import os)
(setv (get os.environ "TF_CPP_MIN_LOG_LEVEL") "3")   ; quiet TensorFlow logging

(import pathlib [Path])
(import numpy :as np)
(import wisconsin)

(setv here (. (Path __file__) parent))


;; ---------- load-data ----------

(defn test-load-data-shapes []
  (setv [x y] (wisconsin.load-data (str (/ here "train.csv"))))
  ;; every row is loaded; 9 feature columns and 1 label column
  (assert (= x.shape #(497 9)))
  (assert (= y.shape #(497 1))))

(defn test-load-data-scales-features []
  (setv [x y] (wisconsin.load-data (str (/ here "train.csv"))))
  ;; raw features are 1..10, so scaled features are 0.1..1.0
  (assert (np.all (>= x 0.1)))
  (assert (np.all (<= x 1.0)))
  (assert (np.allclose (get x 0) [1.0 1.0 1.0 0.8 0.6 0.1 0.8 0.9 0.1]))
  (assert (= (set (.tolist (.flatten y))) #{0 1})))


;; ---------- model ----------

(defn test-first []
  (assert (= (wisconsin.first [7 8 9]) 7)))

(defn test-build-model-and-predict []
  (setv model (wisconsin.build-model))
  (setv [x _] (wisconsin.load-data (str (/ here "test.csv"))))
  (setv preds (wisconsin.predict model x))
  (assert (= preds.shape #(151 1)))
  ;; sigmoid output is a probability
  (assert (np.all (>= preds 0)))
  (assert (np.all (<= preds 1)))
  (assert (= (lfor layer model.layers layer.units) [9 12 1])))

(defn test-model-learns-training-data []
  (setv model (wisconsin.build-model))
  (setv [x y] (wisconsin.load-data (str (/ here "train.csv"))))
  (setv loss-before (model.evaluate x y :verbose 0))
  (.fit model x y :batch-size 10 :epochs 50 :verbose False)
  (assert (< (model.evaluate x y :verbose 0) loss-before)))

(defn test-main-prints-accuracy [monkeypatch capsys]
  (monkeypatch.chdir here)
  ;; one short training pass is enough to check the output format
  (monkeypatch.setattr wisconsin "train"
    (fn [batch-size model x y] (.fit model x y :batch-size batch-size :epochs 5 :verbose False)))
  (wisconsin.main)
  (setv out (. (capsys.readouterr) out))
  (assert (in "* accuracy on 151 test samples:" out))
  (assert (in "* first 10 predictions (calculated, expected):" out)))
