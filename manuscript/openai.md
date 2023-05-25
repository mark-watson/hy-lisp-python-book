# Using OpenAI GPT and Hugging Face APIs

I use both the OpenAI and Hugging Face Large Language Models (LLMs) and APIs in my work. In this chapter we use the GPT-3.5 API since it works well for our examples. Using GTP-4 and ChatGPT is more expensive. We will also use a free Hugging Face API and a local Hugging Face model on our laptops.

## OpenAI Text Completion API

OpenAI GPT (Generative Pre-trained Transformer 3) models like GPT-3.5, GPT-4, and ChatGPT are advanced language processing models developed by OpenAI. There are three general classes of OpenAI API services:

- GPT which performs a variety of natural language tasks.
- Codex which translates natural language to code.
- DALL·E which creates and edits original images.

GPT-3.5 and GPT-4 are capable of generating human-like text, completing tasks such as language translation, summarization, and question answering, and much more. OpenAI offers GPT-3 APIs, which allows developers to easily integrate GPT's capabilities into their applications.

The GPT-3.5 API provides a simple and flexible interface for developers to access GPT-3.5's capabilities such as text completion, language translation, and text generation. The API can be accessed using a simple API call, and can be integrated into a wide range of applications such as chatbots, language translation services, and text summarization.

Overall, the OpenAI GPT-3.5 APIs provide a powerful and easy-to-use tool for developers to integrate advanced language processing capabilities into their applications, and can be a game changer for developers looking to add natural language processing capabilities to their projects.

The following examples are derived from the official set of cookbook examples at [https://github.com/openai/openai-cookbook](https://github.com/openai/openai-cookbook). The first example calls the OpenAI GPT-3.5 Completion API with a sample of input text and the model completes the text:


```hy
(import os)
(import openai)

(setv openai.api_key (os.environ.get "OPENAI_KEY"))

(setv
  completion
  (openai.ChatCompletion.create
    :model "gpt-3.5-turbo"
    :messages
    [{"role" "user"
      "content"
      "What do I do when Emacs goes to the background and I can't access it?"
     }]))

(print completion)
```

Every time you run this example you get different output. Here is one example run:

```json
{
  "choices": [
    {
      "finish_reason": "stop",
      "index": 0,
      "message": {
        "content": "If Emacs has gone to the background and you can't access it, you can bring it back to the foreground by following these steps:\n\n1. Press Ctrl-Z to suspend Emacs.\n2. Type `fg` and press Enter to bring Emacs back to the foreground.\n\nIf that does not work, you can try the following steps:\n\n1. Open a new terminal window.\n2. Type `ps aux | grep emacs` and press Enter to see the process ID of Emacs.\n3. Type `kill -CONT <PID>` where `<PID>` is the process ID of Emacs that you found in the previous step.\n4. Emacs should now be back in the foreground.\n\nIf Emacs is still not responding, you may need to force it to quit by using `kill -9 <PID>` where `<PID>` is the ID of the Emacs process. This should only be done as a last resort as it may result in data loss.",
        "role": "assistant"
      }
    }
  ],
  "created": 1684944134,
  "id": "chatcmpl-7JlEESNQAyNmi9ha8djpvfk9eBzoG",
  "model": "gpt-3.5-turbo-0301",
  "object": "chat.completion",
  "usage": {
    "completion_tokens": 187,
    "prompt_tokens": 25,
    "total_tokens": 212
  }
}
```

Let's put this code in a reusable function in the source file **openai/text_completion.hy**:

```hy
(import os)
(import openai)

(setv openai.api_key (os.environ.get "OPENAI_KEY"))

(defn completion [query]
  (setv
    completion
    (openai.ChatCompletion.create
      :model "gpt-3.5-turbo"
      :messages
      [{"role" "user"
        "content" query
       }]))
  (get
    (get (get (get completion "choices") 0) "message")
    "content"))
```

Here we change directory to **hy-lisp-python/openai** and try this function with two example queries in a Hy REPL:

```console
$ hy
Hy 0.26.0 using CPython(main) 3.11.0 on Darwin
=> (import text_completion [completion])
=> (print (completion "how to fix leaky faucet?"))
1. Turn off the water supply: Before you begin any repair work, turn off the water supply to the faucet. This is usually located on the wall or under the sink.

2. Dismantle the faucet: Disassemble the faucet and remove any handles, screws, and retaining nuts. Take care not to damage any of the components.

3. Replace the rubber washer: Check the rubber washer located on the end of the stem. If it is worn or damaged, replace it with a new one. The washer can usually be easily removed by unscrewing the screw that holds it in place.

4. Replace the cartridge: If the washer is in good condition, you may need to replace the entire cartridge. Remove the old cartridge and replace it with a new one.

5. Reassemble the faucet: Once everything is fixed or replaced, reassemble the faucet and turn on the water supply to check for leaks.

6. Test if the faucet is still leaky: Turn on the water supply at the shutoff valve and let the water run for a few seconds. Turn off the faucet and check for any leaks.

7. Tighten the nuts and screws: In case the faucet is still leaky, check the nuts, screws, and other components to ensure they are tight.

8. Call a professional: If you are unable to fix the leak, or the problem is more complicated than you can handle, it may be necessary to call a professional plumber.

=> (print (completion "what are the best programming languages to use for AI?"))
There are several programming languages that are commonly used for AI:

1. Python: Python is a popular programming language for AI due to its simplicity, readability, and large variety of libraries and frameworks such as TensorFlow, PyTorch, and Scikit-learn.

2. Java: Java is a popular programming language for developing AI applications due to its strong security, object-oriented architecture, and scalability.

3. C++: C++ is a widely-used language in the world of AI because of its speed, performance, and memory management.

4. R: R is a language that is specifically designed for statistical computing and data analysis. It is a popular choice for building machine learning models and visualizing data.

5. Lisp: Lisp is an old programming language that is especially well-suited for AI development because of its ability to handle symbolic expressions.

Ultimately, the choice of programming language will depend on the specific requirements of the application being developed.
=>
```

This completion API is very general purpose. If you use the ChatGPT web app try some of the same prompts with this code example. In the function **completion** the messages just had a single interaction but if you follow the OpenAI documentation you can use the same code, with a different value of **:messages** implement interactive chat.

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