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

~~~~~~~~




{lang="hylang",linenos=on}
~~~~~~~~

~~~~~~~~



## Using a LSTM Recurrent Neural Network to Generate Hy Language Code

TBD

We will translate a Python example program from the [Keras documentation (listing of LSTM example)](https://keras.io/examples/lstm_text_generation/) to Hy. This is a moderately long example and you can use the original Python and the translated Hy code as a guide if you see other models written using Keras that you want in Hy. I have (mostly) kept the same variable names to make it easier to compare the Python and Hy code.


{lang="hylang",linenos=on}
~~~~~~~~

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

{lang="hylang",linenos=on}
~~~~~~~~

~~~~~~~~

