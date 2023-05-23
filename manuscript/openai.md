# OpenAI GPT-4 and ChatGPT APIs

I use both the OpenAI and Hugging Face Models and APIs in my work. Here we will just use OpenAI APIs.

OpenAI GPT (Generative Pre-trained Transformer 3) models like GPT-3.5, GPT-4, and ChatGPT are advanced language processing model developed by OpenAI. There are three general classes of OpenAI API services:

- GPT which performs a variety of natural language tasks.
- Codex which translates natural language to code.
- DALL·E which creates and edits original images.

GPT-3.5 and GPT-4 are capable of generating human-like text, completing tasks such as language translation, summarization, and question answering, and much more. OpenAI offers GPT-3 APIs, which allow developers to easily integrate GPT's capabilities into their applications.

The GPT-3 API provides a simple and flexible interface for developers to access GPT-3's capabilities such as text completion, language translation, and text generation. The API can be accessed using a simple API call, and can be integrated into a wide range of applications such as chatbots, language translation services, and text summarization.

Additionally, OpenAI provides a number of pre-built models that developers can use, such as the GPT-3 language model, the GPT-3 translation model, and the GPT-3 summarization model. These pre-built models allow developers to quickly and easily access GPT-3's capabilities without the need to train their own models.

Overall, the OpenAI GPT-3 APIs provide a powerful and easy-to-use tool for developers to integrate advanced language processing capabilities into their applications, and can be a game changer for developers looking to add natural language processing capabilities to their projects.

We will only use the GPT-3 APIs here. The following examples are derived from the official set of cookbook examples at [https://github.com/openai/openai-cookbook](https://github.com/openai/openai-cookbook). The first example calls the OpenAI GPT-3 Completion API with a sample of input text and the model completes the text (deep-learning/openai/openai-example.py):


```python
# Using ChatGPT API (from OpenAI's documentation)

import os

import openai

openai.api_key = os.environ.get('OPENAI_KEY')

completion = openai.ChatCompletion.create(
  model="gpt-3.5-turbo", 
  messages=[{"role": "user", "content": "What do I do when Emacs goes to the background and I can't access it?"}]
)

print(completion)
```

Every time you run this example you get different output. Here is one example run:

```json
{
  "choices": [
    {
      "finish_reason": "stop",
      "index": 0,
      "message": {
        "content": "\n\nThere are a few steps you can take if Emacs goes to the background and you can't access it:\n\n1. Try pressing the Alt and Tab keys together to cycle through all the open windows on your computer. This may help you find Emacs and bring it to the foreground.\n\n2. If the above step doesn't work, try clicking on the Emacs icon in your taskbar or dock, depending on your operating system. This should bring Emacs to the front.\n\n3. If Emacs is still not accessible after trying the above steps, check if it is still running by opening your system's task manager or activity monitor. If Emacs is there, you can try to force it to quit and relaunch it.\n\n4. If none of these steps work, you can always restart your computer to clear any glitches or issues that may be causing Emacs to stay in the background.",
        "role": "assistant"
      }
    }
  ],
  "created": 1677695823,
  "id": "chatcmpl-6pLbzAdQahv3nYpY8BrCglE428Y80",
  "model": "gpt-3.5-turbo-0301",
  "object": "chat.completion",
  "usage": {
    "completion_tokens": 175,
    "prompt_tokens": 24,
    "total_tokens": 199
  }
}
```

### Using GPT-3 to Name K-Means Clusters

I get a lot of enjoyment finding simple application examples that solve problems that I had previously spent a lot of time solving with other techniques. As an example, around 2010 a customer and I created some ad hoc ways to name K-Means clusters with meaningful cluster names. Several years later at Capital One, my team brainstormed other techniques for assigning meaningful cluster names for the patent [SYSTEM TO LABEL K-MEANS CLUSTERS WITH HUMAN UNDERSTANDABLE LABELS](https://patents.justia.com/patent/20210357429).

One of the OpenAI example Jupyter notebooks [https://github.com/openai/openai-cookbook/blob/main/examples/Clustering.ipynb](https://github.com/openai/openai-cookbook/blob/main/examples/Clustering.ipynb) solves this problem elegantly using a text prompt like:

```
f'What do the following customer reviews have in common?\n\nCustomer reviews:\n"""\n{reviews}\n"""\n\nTheme:'
```

where the variable **reviews** contains the concatenated recipe reviews in a specific cluster. The recipe clusters are named like:

```
Cluster 0 Theme:  All of the reviews are positive and the customers are satisfied with the product they purchased.

Cluster 1 Theme:  All of the reviews are about pet food.

Cluster 2 Theme:  All of the reviews are positive and express satisfaction with the product.

Cluster 3 Theme:  All of the reviews are about food or drink products.
```

### Using GPT-3 to Translate Natural Language Queries to SQL

Another example of a long term project I had that is now easily solved with the OpenAI GPT-3 models is translating natural language queries to SQL queries. I had an example I wrote for the first two editions of my [Java AI book](https://leanpub.com/javaai) (I later removed this example because the code was difficult to follow). I later reworked this example in Common Lisp and used both versions in several consulting projects in the late 1990s and early 2000s.

I refer you to one of the official OpenAI examples [https://github.com/openai/openai-cookbook/blob/main/examples/Backtranslation_of_SQL_queries.py](https://github.com/openai/openai-cookbook/blob/main/examples/Backtranslation_of_SQL_queries.py). In my Java and Common Lisp NLP query examples, I would test generated SQL queries against a database to ensure they were legal queries, etc., and if you modify OpenAI's example I suggest you do the same.

Here is a sample query and a definition of available database tables:

```python
nl_query: str = "Return the name of each department that had more than 10 employees in June 2021",
eval_template: str = "{};\n-- Explanation of the above query in human readable format\n-- {}",
table_definitions: str = "# Employee(id, name, department_id)\n# Department(id, name, address)\n# Salary_Payments(id, employee_id, amount, date)\n",
```

Here is the output to OpenAI's example:

```sql
$ python Backtranslation_of_SQL_queries.py
SELECT department.name
FROM department
JOIN employee ON department.id = employee.department_id
JOIN salary_payments ON employee.id = salary_payments.employee_id
WHERE salary_payments.date BETWEEN '2021-06-01' AND '2021-06-30'
GROUP BY department.name
HAVING COUNT(*) > 10
```

I find this to be a great example of creatively using deep learning via pre-trained models. I urge you, dear reader, to take some time to peruse the Hugging Face example Jupyter notebooks to see which might be applicable to your development projects. I have always felt that my work "stood on the shoulders of giants," that is my work builds on that of others. In the new era of deep learning and large language models, where very large teams work on models and technology that individuals can't compete with, being a solo developer or when working for a small company, we need to be flexible and creative in using resources from OpenAI, Hugging Face, Google, Microsoft, Meta, etc.

## Hugging Face APIs

Hugging Face provides an extensive library of pre-trained models and a set of easy-to-use APIs that allow developers to quickly and easily integrate NLP capabilities into their applications. The pre-trained models are based on the state-of-the-art transformer architectures, which have been trained on large corpus of data and can be fine-tuned for specific tasks, making it easy for developers to add NLP capabilities to their projects. Hugging Face maintains a task page listing all kinds of machine learning that they support [https://huggingface.co/tasks](https://huggingface.co/tasks) for task domains:

- Computer Vision
- Natural Language Processing
- Audio
- Tabular Data
- Multimodal
- Reinforcement Learning

As an open source and open model company, Hugging Face is a provider of NLP technology, with a focus on developing and providing state-of-the-art pre-trained models and tools for NLP tasks. They have developed a library of pre-trained models, including models based on transformer architectures such as BERT, GPT-2, and GPT-3, which can be fine-tuned for various tasks such as language understanding, language translation, and text generation.

Hugging Face also provides a set of APIs, which allows developers to easily access the functionality of these pre-trained models. The APIs provide a simple and flexible interface for developers to access the functionality of these models, such as text completion, language translation, and text generation. This allows developers to quickly and easily integrate NLP capabilities into their applications, without the need for extensive knowledge of NLP or deep learning.

The Hugging Face APIs are available via a simple API call and are accessible via an API key. They support a wide range of programming languages such as Python, Java and JavaScript, making it easy for developers to integrate them into their application.

Since my personal interests are mostly in Natural Language Processing (NLP) as used for processing text data, automatic extraction of structured data from text, and question answering systems, I will just list their NLP task types:

{width: "75%"}
![](hfnlp.png)


### Coreference: Resolve Pronouns to Proper Nouns in Text Using Hugging Face APIs

You can find this example script in **PythonPracticalAIBookCode/deep-learning/huggingface_apis/hf-coreference.py**:

```python
import json
import requests
import os
from pprint import pprint

# NOTE: Hugging Face does not have a direct anaphora resolution model, so this
#       example is faking it using masking with a BERT model.

HF_API_TOKEN = os.environ.get('HF_API_TOKEN')
headers = {"Authorization": f"Bearer {HF_API_TOKEN}"}
API_URL = "https://api-inference.huggingface.co/models/bert-base-uncased"

def query(payload):
    data = json.dumps(payload)
    response = requests.request("POST", API_URL, headers=headers, data=data)
    return json.loads(response.content.decode("utf-8"))

data = query("John Smith bought a car. [MASK] drives it fast.")

pprint(data)
```

Here is example output (I am only showing the highest scored results for each query):

```
$ python hf-coreference.py 
[{'score': 0.9037206768989563,
  'sequence': 'john smith bought a car. he drives it fast.',
  'token': 2002,
  'token_str': 'he'},
 {'score': 0.015135547146201134,
  'sequence': 'john smith bought a car. john drives it fast.',
  'token': 2198,
  'token_str': 'john'}]
```

### GPT-2 Hugging Face Documentation

The [documentation page for Hugging Face GPT2 models](https://huggingface.co/docs/transformers/model_doc/gpt2) has many examples for using their GPT2 model for tokenization and other NLP tasks.

### Answer Questions From Text

We already saw an example Jupyter Notebook in the chapter *Semantic Web, Linked Data and Knowledge Graphs* in the section *A Hybrid Deep Learning and RDF/SPARQL Application for Question Answering* that used the the Hugging Face **NeuML/bert-small-cord19-squad2** model to use a large context text sample to answer questions.

### Calculate Semantic Similarity of Sentences Using Hugging Face APIs

Given a list of sentences we, can calculate sentence embeddings for each one. Any new sentence can be matched by calculating its embedding and finding the closest cosine similarity match. Contents of file **hf-sentence_similarities.py**:


{caption: "Sentence Similarity"}
{format: python}
![](hf-sentence_similarities.py)

Here is example output:

```
$ python hf-sentence_similarities.py 
[0.6945773363113403, 0.9429150819778442, 0.2568760812282562]
```

Here we are using one of the free Hugging Face APIs. At the end of this chapter we will use an alternative sentence embedding model that you can easily run on your laptop.

### Summarizing Text Using a Pre-trained Hugging Face Model on Your Laptop

For most Hugging Face pre-trained models you can either use them running on Hugging Face servers via an API call or use the **transformers** library to download and run the model on your laptop. The downloaded model and associated files are a little less than two gigabytes of data. Once a model is downloaded to **~/.cache/huggingface** on your local filesystem you can use the model again without re-downloading it.

```python
from transformers import pipeline
from pprint import pprint

summarizer = pipeline("summarization", model="facebook/bart-large-cnn")
  
text = "The President sent a request for changing the debt ceiling to Congress. The president might call a press conference. The Congress was not oblivious of what the Supreme Court's majority had ruled on budget matters. Even four Justices had found nothing to criticize in the President's requirement that the Federal Government's four-year spending plan. It is unclear whether or not the President and Congress can come to an agreement before Congress recesses for a holiday. There is major dissagrement between the Democratic and Republican parties on spending."

results = summarizer(text, max_length=60)[0]
print("".join(results['summary_text']))
```

Here is some sample output:

```
$ python hf-summarization.py 
The President sent a request for changing the debt ceiling to Congress. The Congress was not oblivious of what the Supreme Court's majority had ruled on budget matters. Even four Justices had found nothing to criticize in the President's requirement that the Federal Government's four-year spending plan be changed
```


### Zero Shot Classification Using Hugging Face APIs

Zero shot classification models work by specifying which classification labels you want to assign to input texts. In this example we ask the model to classify text into one of: **'refund', 'faq', 'legal'**. Usually for text classification applications we need to pre-train a model using examples of text in different categories we are interested in. This extra work is not required using the Meta/Facebook pre-trained zero shot model **bart-large-mnli**:

{caption: "Hugging Model for Zero Shot Classification"}
{format: python}
![](hf-zero_shot_classification.py)

Here is some example output:

```
$ python hf-zero_shot_classification.py 
{'labels': ['refund', 'faq', 'legal'],
 'scores': [0.877787709236145, 0.10522633045911789, 0.01698593981564045],
 'sequence': 'Hi, I recently bought a device from your company but it is not '
             'working as advertised and I would like to get reimbursed!'}
```

## Comparing Sentences for Similarity Using Transformer Models

Although I use OpenAI and HuggingFace for most of the pre-trained NLP models I use, I recently used a sentence similarity Transformer model from the [Ubiquitous Knowledge Processing Lab](https://www.informatik.tu-darmstadt.de/ukp/ukp_home/index.en.jsp) for a quick work project and their library support for finding similar sentences is simple to use. This model was written using PyTorch. Here is one of their examples, slightly modified for this book:

```python
# pip install sentence_transformers
# The first time this script is run, the sentence_transformers library will
# download a pre-trained model.

# This example is derived from examples at https://www.sbert.net/docs/quickstart.html

from sentence_transformers import SentenceTransformer, util

model = SentenceTransformer('all-MiniLM-L6-v2')

sentences = ['The IRS has new tax laws.',
             'Congress debating the economy.',
             'The polition fled to South America.',
             'Canada and the US will be in the playoffs.',
             'The cat ran up the tree',
             'The meal tasted good but was expensive and perhaps not worth the price.']

#Sentences are encoded by calling model.encode()
sentence_embeddings = model.encode(sentences)

#Compute cosine similarity between all pairs
cos_sim = util.cos_sim(sentence_embeddings, sentence_embeddings)

#Add all pairs to a list with their cosine similarity score
all_sentence_combinations = []
for i in range(len(cos_sim)-1):
    for j in range(i+1, len(cos_sim)):
        all_sentence_combinations.append([cos_sim[i][j], i, j])

#Sort list by the highest cosine similarity score
all_sentence_combinations =
  sorted(all_sentence_combinations, key=lambda x: x[0], reverse=True)

print("Top-8 most similar pairs:")
for score, i, j in all_sentence_combinations[0:8]:
    print("{} \t {} \t {:.4f}".format(sentences[i],
                                      sentences[j],
                                      cos_sim[i][j]))
```

The output is:

```
$ python sentence_transformer.py
Top-8 most similar pairs:
The IRS has new tax laws. 	 Congress debating the economy. 	 0.1793
Congress debating the economy. 	 Canada and the US will be in the playoffs. 	 0.1210
Congress debating the economy. 	 The meal tasted good but was expensive and perhaps not worth the price. 	 0.1131
Congress debating the economy. 	 The polition fled to South America. 	 0.0963
The polition fled to South America. 	 Canada and the US will be in the playoffs. 	 0.0854
The polition fled to South America. 	 The meal tasted good but was expensive and perhaps not worth the price. 	 0.0826
The polition fled to South America. 	 The cat ran up the tree 	 0.0809
Congress debating the economy. 	 The cat ran up the tree 	 0.0496
```

A common use case might be a customer service facing chatbot where we simply match the user's question with all recorded user questions that have accepted "canned answers." The runtime to get the best match is **O(N)** where **N** is the number of previously recorded user questions. The cosine similarity calculation, given two embedding vectors, is very fast.

In this example we used the [Sentence Transformer utility library util.py](https://github.com/UKPLab/sentence-transformers/blob/master/sentence_transformers/util.py) to calculate the cosine similarities between all combinations of sentence embeddings. For a practical application you can use the **cos_sim** function in **util.py**:

```python
>>> from util
>>> util.cos_sim(sentence_embeddings[0], sentence_embeddings[1])
tensor([[0.1793]])
>>> 
```

## Deep Learning Natural Language Processing Wrap-up

In this example and earlier chapters we have seen examples of how effective deep learning is for NLP. I worked on other methods of NLP over a 25-year period and I ask you, dear reader, to take my word on this: deep learning has revolutionized NLP and for almost all practical NLP applications deep learning libraries and models from organizations like Hugging Face and OpenAI should be the first thing that you consider using.