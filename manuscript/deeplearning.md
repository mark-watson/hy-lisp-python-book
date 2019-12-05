# Deep Learning

Most of my professional career since 2014 has involved deep learning, mostly with TensorFlow using the Keras APIs. In the late 1980s I was on a DARPA neural network technology advisory panel for a year, I wrote the first prototype of the SAIC ANSim neural network library commercial product, and I wrote the neural network prediction code for a bomb detector my company designed and built for the FAA for deployment in airports.

The Hy language utilities and example programs we develop here all use TensorFlow and Keras "under the hood" to do the heavy lifting. 

TBD

## Tutorial on Deep Learning

TBD

## Data Preparation Utilities

### Normalizing the Range of Data

TBD

### Handling Missing Input Data

TBD


## Using Keras and TensorFlow to Model The Wisconsin Cancer Data Set

TBD


{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import argparse os)
(import keras
        keras.utils.data-utils)

(import [pandas [read-csv]])

(defn build-model []
  (setv model (keras.models.Sequential))
  (.add model (keras.layers.core.Dense 9
                 :activation "relu"))
  (.add model (keras.layers.core.Dense 12
                 :activation "relu"))
  (.add model (keras.layers.core.Dense 1
                 :activation "sigmoid"))
  (.compile model :loss      "binary_crossentropy"
                  :optimizer (keras.optimizers.RMSprop))
  model)

(defn train [batch-size model x y]
  (for [it (range 50)]
    (.fit model x y :batch-size batch-size :epochs 10 :verbose False)))

(defn predict [model x-data]
    (.predict model x-data))

(defn load-data [file-name]
  (setv all-data (read-csv file-name :header None))
  (setv x-data10 (. all-data.iloc [(, (slice 0 10) [0 1 2 3 4 5 6 7 8])] values))
  (setv x-data (* 0.1 x-data10))
  (setv y-data (. all-data.iloc [(, (slice 0 10) [9])] values))
  [x-data y-data])

(defn main []
  (setv xyd (load-data "train.csv"))
  (setv model (build-model))
  (setv xytest (load-data "test.csv"))
  (train 10 model (. xyd [0]) (. xyd [1]))
  (print "* predictions (calculated, expected):")
  (setv predictions (list (map first (predict model (. xytest [0])))))
  (setv expected (list (map first (. xytest [1]))))
  (print
    (list
      (zip predictions expected))))

(main)
~~~~~~~~




{lang="hylang",linenos=on}
~~~~~~~~

~~~~~~~~



## Using a LSTM Recurrent Neural Network to Generate Hy Language Code

TBD

We will translate a Python example program from the [Keras documentation (listing of LSTM.py example)](https://keras.io/examples/lstm_text_generation/) to Hy. This is a moderately long example and you can use the original Python and the translated Hy code as a guide if you see other models written using Keras that you want in Hy. I have (mostly) kept the same variable names to make it easier to compare the Python and Hy code.

Note that using the nietzsche.txt data set requires a fair amount of memory. If your computer has less than 16G of RAM, you might want to run the following example until you see the printout "Create sentencs and next_chars data..." then kill the program, manually edit the file ~/.keras/datasets/nietzsche.txt to remove 75% of the data by:

        cd
        mv nietzsche.txt nietzsche_large.txt
        head -800 nietzsche_large.txt > nietzsche.txt

When I am training deep learning models I like to monitor system resources using the **top** command line activity, specifically watching for page faults when training on a CPU. If you are using CUDA and a GPU then use the CUDA command line utilities for monitoring the state of the GPU.

{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

;; This example was translated from the Python example in the Keras
;; documentation at: https://keras.io/examples/lstm_text_generation/
;; The original Python file LSTM.py is included in the directory
;; hy-lisp-python/deeplearning for reference.

(import [keras.callbacks [LambdaCallback]])
(import [keras.models [Sequential]])
(import [keras.layers [Dense LSTM]])
(import [keras.optimizers [RMSprop]])
(import [keras.utils.data_utils [get_file]])
(import [numpy :as np]) ;; note the syntax for aliasing a module name
(import random sys io)

(setv path
      (get_file        ;; this saves a local copy in ~/.keras/datasets
        "nietzsche.txt"
        :origin "https://s3.amazonaws.com/text-datasets/nietzsche.txt"))

(with [f (io.open path :encoding "utf-8")]
  (setv text (.read f))) ;; note: sometimes we use (.lower text) to
;;       convert text to all lower case
(print "corpus length:" (len text))

(setv chars (sorted (list (set text))))
(print "total chars (unique characters in input text):" (len chars))
(setv char_indices (dict (lfor i (enumerate chars) (, (last i) (first i)))))
(setv indices_char (dict (lfor i (enumerate chars) i)))

;; cut the text in semi-redundant sequences of maxlen characters
(setv maxlen 40)
(setv step 3) ;; when we sample text, slide sampling window 3 characters
(setv sentences (list))
(setv next_chars (list))

(print "Create sentencs and next_chars data...")
(for [i (range 0 (- (len text) maxlen) step)]
  (.append sentences (cut text i (+ i maxlen)))
  (.append next_chars (get text (+ i maxlen))))

(print "Vectorization...")
(setv x (np.zeros [(len sentences) maxlen (len chars)] :dtype np.bool))
(setv y (np.zeros [(len sentences) (len chars)] :dtype np.bool))
(for [[i sentence] (lfor j (enumerate sentences) j)]
  (for [[t char] (lfor j (enumerate sentence) j)]
    (setv (get x i t (get char_indices char)) 1))
  (setv (get y i (get char_indices (get next_chars i))) 1))
(print "Done creating one-hot encoded training data.")

(print "Builing model...")
(setv model (Sequential))
(.add model (LSTM 128 :input_shape [maxlen (len chars)]))
(.add model (Dense (len chars) :activation "softmax"))

(setv optimizer (RMSprop 0.01))
(.compile model :loss "categorical_crossentropy" :optimizer optimizer)

(defn sample [preds &optional [temperature 1.0]]
  (setv preds (.astype (np.array preds) "float64"))
  (setv preds (/ (np.log preds) temperature))
  (setv exp_preds (np.exp preds))
  (setv preds (/ exp_preds (np.sum exp_preds)))
  (setv probas (np.random.multinomial 1 preds 1))
  (np.argmax probas))

(defn on_epoch_end [epoch &optional not-used]
  (print)
  (print "----- Generating text after Epoch:" epoch)
  (setv start_index (random.randint 0 (- (len text) maxlen 1)))
  (for [diversity [0.2 0.5 1.0 1.2]]
    (print "----- diversity:" diversity)
    (setv generated "")
    (setv sentence (cut text start_index (+ start_index maxlen)))
    (setv generated (+ generated sentence))
    (print "----- Generating with seed:" sentence)
    (sys.stdout.write generated)
    (for [i (range 400)]
      (setv x_pred (np.zeros [1 maxlen (len chars)]))
      (for [[t char] (lfor j (enumerate sentence) j)]
        (setv (get x_pred 0 t (get char_indices char)) 1))
      (setv preds (first (model.predict x_pred :verbose 0)))
      (setv next_index (sample preds diversity))
      (setv next_char (get indices_char next_index))
      (setv sentence (+ (cut sentence 1) next_char))
      (sys.stdout.write next_char)
      (sys.stdout.flush))
    (print)))

(setv print_callback (LambdaCallback :on_epoch_end on_epoch_end))

(model.fit x y :batch_size 128 :epochs 60 :callbacks [print_callback])
~~~~~~~~


If we print out the number of characters in text and the unique list of characters (variable **chars**) in the training text file nietzsche.txt we see:

{linenos=off}
~~~~~~~~
corpus length: 600893
['\n', ' ', '!', '"', "'", '(', ')', ',', '-', '.', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ':', ';', '=', '?', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '[', ']', '_', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'Æ', 'ä', 'æ', 'é', 'ë']
~~~~~~~~

It is important to understand how we one hot encode input text and decode back to text when we use a trained model to generate text. It will hep to see the dictionaries for converting characters to indices and th reverse indices to original characters:

{linenos=off}
~~~~~~~~
char_indices:
 {'\n': 0, ' ': 1, '!': 2, '"': 3, "'": 4, '(': 5, ')': 6, ',': 7, '-': 8, '.': 9, '0': 10, '1': 11, '2': 12, '3': 13, '4': 14, '5': 15, '6': 16, '7': 17, '8': 18, '9': 19, ':': 20, ';': 21, '=': 22, '?': 23, 'A': 24, 'B': 25, 'C': 26, 'D': 27, 'E': 28, 'F': 29, 'G': 30, 'H': 31, 'I': 32, 'J': 33, 'K': 34, 'L': 35, 'M': 36, 'N': 37, 'O': 38, 'P': 39, 'Q': 40, 'R': 41, 'S': 42, 'T': 43, 'U': 44, 'V': 45, 'W': 46, 'X': 47, 'Y': 48, 'Z': 49, '[': 50, ']': 51, '_': 52, 'a': 53, 'b': 54, 'c': 55, 'd': 56, 'e': 57, 'f': 58, 'g': 59, 'h': 60, 'i': 61, 'j': 62, 'k': 63, 'l': 64, 'm': 65, 'n': 66, 'o': 67, 'p': 68, 'q': 69, 'r': 70, 's': 71, 't': 72, 'u': 73, 'v': 74, 'w': 75, 'x': 76, 'y': 77, 'z': 78, 'Æ': 79, 'ä': 80, 'æ': 81, 'é': 82, 'ë': 83}
indices_char:
 {0: '\n', 1: ' ', 2: '!', 3: '"', 4: "'", 5: '(', 6: ')', 7: ',', 8: '-', 9: '.', 10: '0', 11: '1', 12: '2', 13: '3', 14: '4', 15: '5', 16: '6', 17: '7', 18: '8', 19: '9', 20: ':', 21: ';', 22: '=', 23: '?', 24: 'A', 25: 'B', 26: 'C', 27: 'D', 28: 'E', 29: 'F', 30: 'G', 31: 'H', 32: 'I', 33: 'J', 34: 'K', 35: 'L', 36: 'M', 37: 'N', 38: 'O', 39: 'P', 40: 'Q', 41: 'R', 42: 'S', 43: 'T', 44: 'U', 45: 'V', 46: 'W', 47: 'X', 48: 'Y', 49: 'Z', 50: '[', 51: ']', 52: '_', 53: 'a', 54: 'b', 55: 'c', 56: 'd', 57: 'e', 58: 'f', 59: 'g', 60: 'h', 61: 'i', 62: 'j', 63: 'k', 64: 'l', 65: 'm', 66: 'n', 67: 'o', 68: 'p', 69: 'q', 70: 'r', 71: 's', 72: 't', 73: 'u', 74: 'v', 75: 'w', 76: 'x', 77: 'y', 78: 'z', 79: 'Æ', 80: 'ä', 81: 'æ', 82: 'é', 83: 'ë'}
~~~~~~~~

We prepare the input and target output data in lines XXXX to YYYYY. Using a short string lets look at how these input and output training exampes are extracted for an input string:

{lang="bash",linenos=on}
~~~~~~~~
Marks-MacBook:deeplearning $ hy
hy 0.17.0+108.g919a77e using CPython(default) 3.7.3 on Darwin
=> (setv text "0123456789abcdefg")
=> (setv maxlen 4)
=> (setv i 3)
=> (cut text i (+ i maxlen))
'3456'
=> (cut text (+ 1 maxlen))
'56789abcdefg'
=> (setv i 4)                 ;; i is the for loop variable for
=> (cut text i (+ i maxlen))  ;; defining sentences and next_chars
'4567'
=> (cut text i (+ i maxlen))
'4567'
=> (cut text (+ i maxlen))
'89abcdefg'
=> 
~~~~~~~~

So the input training sentences are each **maxlen** characters long and the **next-chars** target outputs each start with the character after the last character in the corresponding input training sentence.

This script pauses during each training epoc to generate text given diversity values of 0.2, 0.5, 1.0, and 1.2. The smaller the diversity value the more closely the generated text matches the training text. The generated text is more realistic after many training epocs. In the following, I list a highly edited copy of running through several training epochs. I only show generated text for diversity equal to 0.2:

{lang="hylang",linenos=on}
~~~~~~~~
----- Generating text after Epoch: 0
----- diversity: 0.2
----- Generating with seed: ocity. Equally so, gratitude.--Justice r
ocity. Equally so, gratitude.--Justice read in the become to the conscience the seener and the conception that the becess of the power to the procentical that the because and the prostice of the prostice and the will to the conscience of the power of the perhaps the self-distance of the all the soul and the world and the soul of the soul of the world and the soul and an an and the profound the self-dister the all the belief and the

----- Generating text after Epoch: 8
----- diversity: 0.2
----- Generating with seed: nations
laboring simultaneously under th
nations
laboring simultaneously under the subjection of the soul of the same to the subjection of the subjection of the same not a strong the soul of the spiritual to the same really the propers to the stree be the subjection of the spiritual that is to probably the stree concerning the spiritual the sublicities and the spiritual to the processities the spirit to the soul of the subjection of the self-constitution and propers to the

----- Generating text after Epoch: 14
----- diversity: 0.2
----- Generating with seed:  to which no other path could conduct us
 to which no other path could conduct us a stronger that is the self-delight and the strange the soul of the world of the sense of the sense of the consider the such a state of the sense of the sense of the sense of such a sandine and interpretation of the process of the sense of the sense of the sense of the soul of the process of the world in the sense of the sense of the spirit and superstetion of the world the sense of the

----- Generating text after Epoch: 17
----- diversity: 0.2
----- Generating with seed: hemselves although they could easily hav
hemselves although they could easily have been moral morality and the self-in which the self-in the world to the same man in the standard to the possibility that is to the strength of the sense-in the former the sense-in the special and the same man in the consequently the soul of the superstition of the special in the end to the possible that it is will not be a sort of the superior of the superstition of the same man to the same man
~~~~~~~~

Here we trained on examples, translated to English, of the philosopher Nietzsche. I have used similar code to this example to train on highly structured JSON data and the resulting LSTM bsed model was usually able to generate similarly structured JSON. I have seen other examples where the training data was code in C++.

How is this example working? The model learns what combinations of characters tend to appear together and in what order.

TBD: better explanation


{lang="hylang",linenos=on}
~~~~~~~~

~~~~~~~~

I have used LSTM models trained on application specific highly structured JSON data to generate synthetic JSON data matching the schema of the original JSON training data. In the next chapter we will use pre-trained deep learning models for natural language processing (NLP).
