# Using OpenAI GPT and Hugging Face APIs

I use both the OpenAI and Hugging Face Large Language Models (LLMs) and APIs in my work. In this chapter we use the GPT-3.5 API since it works well for our examples. Using GTP-4 and ChatGPT is more expensive. We will also use a free Hugging Face API and a local Hugging Face model on our laptops.

## OpenAI Text Completion API

OpenAI GPT (Generative Pre-trained Transformer 3) models like gpt-4o, gpt-4o-mini, and ChatGPT are advanced language processing models developed by OpenAI. There are three general classes of OpenAI API services:

- GPT which performs a variety of natural language tasks.
- Codex which translates natural language to code.
- DALL·E which creates and edits original images.

GPT-3.5 and GPT-4 are capable of generating human-like text, completing tasks such as language translation, summarization, and question answering, and much more. OpenAI offers GPT-3 APIs, which allows developers to easily integrate GPT's capabilities into their applications.

The GPT-40-mini API provides a simple and flexible interface for developers to access the model’s capabilities such as text completion, language translation, and text generation. The API can be accessed using a simple API call, and can be integrated into a wide range of applications such as chatbots, language translation services, and text summarization.

Note: gpt-4o-mini is very inexpensive to run. I like to start using gpt-4o-mini and switch to gpt-4o if necessary.

Overall, the OpenAI APIs provide a powerful and easy-to-use tool for developers to integrate advanced language processing capabilities into their applications, and can be a game changer for developers looking to add natural language processing capabilities to their projects.

The following examples are derived from the official set of cookbook examples at [https://github.com/openai/openai-cookbook](https://github.com/openai/openai-cookbook). The first example calls the OpenAI gpt-4o-mini Completion API with a sample of input text and the model completes the text.

Here is a listing or the source file **openai/text_completion.hy**:


```hy
(import os)
(import openai)

(setv openai.api_key (os.environ.get "OPENAI_KEY"))

(setv client (openai.OpenAI))

(defn completion [query] ; return a Completion object
  (setv
    completion
    (client.chat.completions.create
      :model "gpt-4o-mini"
      :messages
      [{"role" "user"
        "content" query
        }]))
  (print completion)
  (get completion.choices 0))

(setv x (completion "how to fix leaky faucet?"))

(print x.message.content)
```

Every time you run this example you get different output. Here is one example run (output truncated for brevity):

```text
Fixing a leaky faucet can be a straightforward process, and you can often do it yourself with some basic tools. Here’s a step-by-step guide:

### Tools and Materials Needed:
- Adjustable wrench
- Screwdriver (flathead or Phillips, depending on your faucet)
- Replacement parts (O-rings, washers, or cartridge, depending on your faucet type)
- Plumber's grease
- Towel or rag

### Steps to Fix a Leaky Faucet:

1. **Turn Off the Water Supply**:
   - Look for shut-off valves under the sink and turn them clockwise to close. If there are no shut-off valves, you may need to turn off the main water supply to your home.

2. **Drain the Faucet**:
   - Open the faucet to let any remaining water drain out.

etc.
```


## Coreference: Resolve Pronouns to Proper Nouns in Text Using Hugging Face APIs

Hugging Face is a great resource for both APIs and for open models that you can run on your laptop. For the following example you need to signup for a free API key: [https://huggingface.co/docs/huggingface_hub/guides/inference](https://huggingface.co/docs/huggingface_hub/guides/inference).

The [documentation page for Hugging Face GPT2 models](https://huggingface.co/docs/transformers/model_doc/gpt2) has many examples for using their GPT2 model for tokenization and other NLP tasks.

You can find this example script in **hy-lisp-python/hugging_face/coreference.hy**:

```hy
(import json)
(import requests)
(import os)

(setv HF_API_TOKEN (os.environ.get "HF_API_TOKEN"))
(setv
  headers
  {"Authorization"
   (.join "" ["Bearer " HF_API_TOKEN])
  })
(setv
  API_URL
  "https://api-inference.huggingface.co/models/bert-base-uncased")

(defn query [payload]
   (setv data (json.dumps payload))
   (setv
     response
     (requests.request "POST" API_URL  :headers headers :data data))
   (json.loads (response.content.decode "utf-8")))
```

Here is example output shown running a Hy REPL in the directory **hy-lisp-python/hugging_face**:

```
$ hy
Hy 0.26.0 using CPython(main) 3.11.0 on Darwin
=> (import coreference [query])
=> (import pprint [pprint])
=> (pprint (query "John Smith bought a car. [MASK] drives it fast."))
[{'score': 0.9037206768989563,
  'sequence': 'john smith bought a car. he drives it fast.',
  'token': 2002,
  'token_str': 'he'},
 {'score': 0.015135547146201134,
  'sequence': 'john smith bought a car. john drives it fast.',
  'token': 2198,
  'token_str': 'john'},
 {'score': 0.011254887096583843,
  'sequence': 'john smith bought a car. she drives it fast.',
  'token': 2016,
  'token_str': 'she'},
 {'score': 0.002539013046771288,
  'sequence': 'john smith bought a car. johnny drives it fast.',
  'token': 5206,
  'token_str': 'johnny'},
 {'score': 0.002136017195880413,
  'sequence': 'john smith bought a car. it drives it fast.',
  'token': 2009,
  'token_str': 'it'}]
=> 
```


### Summarizing Text Using a Pre-trained Hugging Face Model on Your Laptop

For most Hugging Face pre-trained models you can either use them running on Hugging Face servers via an API call or use the **transformers** library to download and run the model on your laptop. The downloaded model we use here and associated files are a little less than two gigabytes of data. Once a model is downloaded to **~/.cache/huggingface** on your local filesystem you can use the model again without re-downloading it. The download process is automatic the first time you call the function **pipeline**:

```hy
(import transformers [pipeline])

(setv
  summarizer
  (pipeline "summarization" :model "facebook/bart-large-cnn"))
  
(setv
  text
  "The President sent a request for changing the debt ceiling to Congress. The president might call a press conference. The Congress was not oblivious of what the Supreme Court's majority had ruled on budget matters. Even four Justices had found nothing to criticize in the President's requirement that the Federal Government's four-year spending plan. It is unclear whether or not the President and Congress can come to an agreement before Congress recesses for a holiday. There is major dissagrement between the Democratic and Republican parties on spending.")

(setv results
  (get
    (summarizer text :max_length 60)
    0))

(print (.join "" (get results "summary_text")))
```

Here is some sample output:

```
The President sent a request for changing the debt ceiling to Congress. The Congress was not oblivious of what the Supreme Court's majority had ruled on budget matters. Even four Justices had found nothing to criticize in the President's requirement that the Federal Government's four-year spending plan be changed
```

Although the OpenAI and Hugging Face APIs are convenient to use I also like to run models locally on my laptop or on Google Colab.