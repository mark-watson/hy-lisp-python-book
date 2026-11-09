#!/usr/bin/env hy

(import argparse)
(import os)
(import keras.models [Sequential])
(import keras.layers [Dense])
(import keras.optimizers [RMSprop])

(import pandas [read-csv])
(import pandas)

(defn build-model []
  (setv model (Sequential))
  (.add model (Dense 9
                 :activation "relu"))
  (.add model (Dense 12
                 :activation "relu"))
  (.add model (Dense 1
                 :activation "sigmoid"))
  (.compile model :loss      "binary_crossentropy"
                  :optimizer (RMSprop))
  model)

(defn first [x] (get x 0))

(defn train [batch-size model x y]
  (for [it (range 50)]
    (.fit model x y :batch-size batch-size :epochs 10 :verbose False)))

(defn predict [model x-data]
    (.predict model x-data))

(defn load-data [file-name]
  (setv all-data (read-csv file-name :header None))
  (setv x-data10 (. all-data.iloc [#((slice None) [0 1 2 3 4 5 6 7 8])] values))
  (setv x-data (* 0.1 x-data10))
  (setv y-data (. all-data.iloc [#((slice None) [9])] values))
  [x-data y-data])

(defn main []
  (setv xyd (load-data "train.csv"))
  (setv model (build-model))
  (setv xytest (load-data "test.csv"))
  (train 10 model (. xyd [0]) (. xyd [1]))
  (setv predictions (lfor p (predict model (. xytest [0])) (round (float (first p)) 4)))
  (setv expected (lfor e (. xytest [1]) (int (first e))))
  (setv correct (sum (gfor [p e] (zip predictions expected) (= (round p) e))))
  (print f"* accuracy on {(len expected)} test samples: {(/ correct (len expected)) :.3f}")
  (print "* first 10 predictions (calculated, expected):")
  (print (list (zip (cut predictions 10) (cut expected 10)))))


(when (= __name__ "__main__")
  (main))
