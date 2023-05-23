# Using LangChain to Chain Together Large Language Models

Harrison Chase started the LangChain project in October 2022 and as I write this book in February 2023 the GitHub repository for LangChain [https://github.com/hwchase17/langchain](https://github.com/hwchase17/langchain) has 171 contributors.

[LangChain](https://langchain.readthedocs.io/en/latest/index.html) is a framework for building applications with large language models (LLMs) through chaining different components together. Some of the applications of LangChain are chatbots, generative question-answering, summarization, data-augmented generation and more. LangChain can save time in building chatbots and other systems by providing a standard interface for chains, agents and memory, as well as integrations with other tools and end-to-end examples. We refer to "chains" as sequences of calls (to an LLMs and a different program utilities, cloud services, etc.) that go beyond just one LLM API call. LangChain provides a standard interface for chains, many integrations with other tools, and end-to-end chains for common applications. Often you will find existing chains already written that meet the requirements for your applications.

For example, one can create a chain that takes user input, formats it using a PromptTemplate, and then passes the formatted response to a Large Language Model (LLM) for processing.

While LLMs are very general in nature which means that while they can perform many tasks effectively, they often can not directly provide specific answers to questions or tasks that require deep domain knowledge or expertise. LangChain provides a standard interface for agents, a library of agents to choose from, and examples of end-to-end agents.

LangChain Memory is the concept of persisting state between calls of a chain or agent. LangChain provides a standard interface for memory, a collection of memory implementations, and examples of chains/agents that use memory². LangChain provides a large collection of common utils to use in your application. Chains go beyond just a single LLM call, and are sequences of calls (whether to an LLM or a different utility). LangChain provides a standard interface for chains, lots of integrations with other tools, and end-to-end chains for common applications.

LangChain can be integrated with one or more model providers, data stores, APIs, etc. LangChain can be used for in-depth question-and-answer chat sessions, API interaction, or action-taking. LangChain can be integrated with Zapier's platform through a natural language API interface (we have an entire chapter dedicated to Zapier integrations).


## Installing Necessary Packages

For the purposes of examples in this book, you might want to create a new Anaconda or other Python environment and install:

    pip install langchain llama_index openai
    pip install kor pydrive pandas rdflib 
    pip install google-search-results SPARQLWrapper

For the rest of this chapter we will use the subdirectory **langchain_getting_started** and in the next chapter use **llama-index_case_study** in the GitHub repository for this book.

## Creating a New LangChain Project

Simple LangChain projects are often just a very short Python script file. As you read this book, when any example looks interesting or useful, I suggest copying the requirements.txt and Python source files to a new directory and making your own GitHub private repository to work in. Please make the examples in this book "your code," that is, freely reuse any code or ideas you find here.

## Basic Usage and Examples

While I try to make the material in this book independent, something you can enjoy with no external references, you should also take advantage of the high quality [documentation](Langchain Quickstart Guide) and the individual detailed guides for prompts, chat, document loading, indexes, etc.

As we work through some examples please keep in mind what it is like to use the ChatGPT web application: you enter text and get repsonses. The way you prompt ChatGPT is obviously important if you want to get useful responses. In code examples we automate and formalize this manual process.

You need to choose a LLM to use. We will usually choose the GPT-3.5 API from OpenAI because it is general purpose and much less expensive than OpenAI's previous model APIs. You will need to [sign up](https://platform.openai.com/account/api-keys) for an API key and set it as an environment variable:

    export OPENAI_API_KEY="YOUR KEY GOES HERE"

Both the libraries **openai** and **langchain** will look for this environment variable and use it. We will look at a few simple examples in a Python REPL. We will start by just using OpenAI's text prediction API:

```console
$ python
>>> from langchain.llms import OpenAI
>>> llm = OpenAI(temperature=0.8)
>>> s = llm("John got into his new sports car, and he drove it")
>>> s
' to work\n\nJohn started up his new sports car and drove it to work. He had a huge smile on his face as he drove, excited to show off his new car to his colleagues. The wind blowing through his hair, and the sun on his skin, he felt a sense of freedom and joy as he cruised along the road. He arrived at work in no time, feeling refreshed and energized.'
>>> s = llm("John got into his new sports car, and he drove it")
>>> s
" around town\n\nJohn drove his new sports car around town, enjoying the feeling of the wind in his hair. He stopped to admire the view from a scenic lookout, and then sped off to the mall to do some shopping. On the way home, he took a detour down a winding country road, admiring the scenery and enjoying the feel of the car's powerful engine. By the time he arrived back home, he had a huge smile on his face."
```

Notice how when we ran the same input text prompt twice that we see different results.Setting the temperature in line 3 to a higher value increases the randomness.

Our next example is in the source file **directions_template.py** and uses the **PromptTemplate** class. A prompt template is a reproducible way to generate a prompt. It contains a text string (“the template”), that can take in a set of parameters from the end user and generate a prompt. The prompt template may contain language model instructions, few-shot examples to improve the model’s response, or specific questions for the model to answer.


```python
from langchain.prompts import PromptTemplate
from langchain.llms import OpenAI
llm = OpenAI(temperature=0.9)

def get_directions(thing_to_do):
    prompt = PromptTemplate(
        input_variables=["thing_to_do"],
        template="How do I {thing_to_do}?",
    )
    prompt_text = prompt.format(thing_to_do=thing_to_do)
    print(f"\n{prompt_text}:")
    return llm(prompt_text)

print(get_directions("get to the store"))
print(get_directions("hang a picture on the wall"))
```

You could just write Python string manipulation code to create a prompt but using the utiltiy class **PromptTemplate** is more legible and works with any number of prompt input variables.

The output is:

```console
$ python directions_template.py

How do I get to the store?:

To get to the store, you will need to use a mode of transportation such as walking, driving, biking, or taking public transportation. Depending on the location of the store, you may need to look up directions or maps to determine the best route to take.

How do I hang a picture on the wall?:

1. Find a stud in the wall, or use two or three wall anchors for heavier pictures.
2. Measure and mark the wall where the picture hanger will go. 
3. Pre-drill the holes and place wall anchors if needed.
4. Hammer the picture hanger into the holes.
5. Hang the picture on the picture hanger.
```

The next example in the file **country_information.py** is derived from an example in the LangChain documentation. In this example we use  **PromptTemplate** that contains the pattern we would like the LLM to use when returning a response.

```python
from langchain.prompts import PromptTemplate
from langchain.llms import OpenAI
llm = OpenAI(temperature=0.9)

def get_country_information(country_name):
    print(f"\nProcessing {country_name}:")
    global prompt
    if "prompt" not in globals():
        print("Creating prompt...")
        prompt = PromptTemplate(
            input_variables=["country_name"],
            template = """
Predict the capital and population of a country.

Country: {country_name}
Capital:
Population:""",
        )
    prompt_text = prompt.format(country_name=country_name)
    print(prompt_text)
    return llm(prompt_text)

print(get_country_information("Canada"))
print(get_country_information("Germany"))
```

You can use the ChatGPT web interface to experiment with prompts and when you find a pattern that works well then write a Python script like the last example, but changing the data you supply in the **PromptTemplate** instance.

The output of the last example is:

```console
 $ python country_information.py

Processing Canada:
Creating prompt...

Predict the capital and population of a country.

Country: Canada
Capital:
Population:


Capital: Ottawa
Population: 37,058,856 (as of July 2020)

Processing Germany:

Predict the capital and population of a country.

Country: Germany
Capital:
Population:


Capital: Berlin
Population: 83,02 million (est. 2019)
```


## Creating Embeddings

We will reference the [LangChain embeddings documentation](https://python.langchain.com/en/latest/reference/modules/embeddings.html). We can use a Python REPL to see what text to vector space embeddings might look like:

```console
$ python
Python 3.10.8 (main, Nov 24 2022, 08:08:27) [Clang 14.0.6 ] on darwin
Type "help", "copyright", "credits" or "license" for more information.
>>> from langchain.embeddings import OpenAIEmbeddings
>>> embeddings = OpenAIEmbeddings()
>>> text = "Mary has blond hair and John has brown hair. Mary lives in town and John lives in the country."
>>> doc_embeddings = embeddings.embed_documents([text])
>>> doc_embeddings
[[0.007727328687906265, 0.0009025644976645708, -0.0033224383369088173, -0.01794492080807686, -0.017969949170947075, 0.028506645932793617, -0.013414892368018627, 0.0046676816418766975, -0.0024965214543044567, -0.02662956342101097,
...]]
>>> query_embedding = embeddings.embed_query("Does John live in the city?")
>>> query_embedding
[0.028048301115632057, 0.011499025858938694, -0.00944007933139801, -0.020809611305594444, -0.023904507979750633, 0.018750663846731186, -0.01626438833773136, 0.018129095435142517,
...]
>>>
```

Notice that the **doc_embeddings** is a list where each list element is the embeddings for one input text document. The **query_embedding** is a single embedding. Please read the above linked embedding documentation.

We will use vector stores to store calculated embeddings for future use. In the next chapter we will see a document database search example using LangChain and Llama-Index.

## Using LangChain Vector Stores to Query Documents

We will reference the [LangChain Vector Stores documentation](https://python.langchain.com/en/latest/reference/modules/vectorstore.html). You need to install a few libraries:

    pip install chroma
    pip install chromadb
    pip install unstructured pdf2image pytesseract

The example script is **doc_search.py**:

```python
from langchain.text_splitter import CharacterTextSplitter
from langchain.vectorstores import Chroma
from langchain.embeddings import OpenAIEmbeddings
from langchain.document_loaders import DirectoryLoader
from langchain import OpenAI, VectorDBQA

embeddings = OpenAIEmbeddings()

loader = DirectoryLoader('../data/', glob="**/*.txt")
documents = loader.load()
text_splitter = CharacterTextSplitter(chunk_size=2500, chunk_overlap=0)

texts = text_splitter.split_documents(documents)

docsearch = Chroma.from_documents(texts, embeddings)

qa = VectorDBQA.from_chain_type(llm=OpenAI(),
                                chain_type="stuff",
                                vectorstore=docsearch)

def query(q):
    print(f"Query: {q}")
    print(f"Answer: {qa.run(q)}")

query("What kinds of equipment are in a chemistry laboratory?")
query("What is Austrian School of Economics?")
query("Why do people engage in sports?")
query("What is the effect of body chemistry on exercise?")
```

The **DirectoryLoader** class is useful for loading a directory full of input documents. In this example we specified that we only want to process text files, but the file matching pattern could have also specified PDF files, etc.

The output is:

```console
$ python doc_search.py      
Created a chunk of size 1055, which is longer than the specified 1000
Running Chroma using direct local API.
Using DuckDB in-memory for database. Data will be transient.
Query: What kinds of equipment are in a chemistry laboratory?
Answer:  A chemistry lab would typically include glassware, such as beakers, flasks, and test tubes, as well as other equipment such as scales, Bunsen burners, and thermometers.
Query: What is Austrian School of Economics?
Answer:  The Austrian School is a school of economic thought that emphasizes the spontaneous organizing power of the price mechanism. Austrians hold that the complexity of subjective human choices makes mathematical modelling of the evolving market extremely difficult and advocate a "laissez faire" approach to the economy. Austrian School economists advocate the strict enforcement of voluntary contractual agreements between economic agents, and hold that commercial transactions should be subject to the smallest possible imposition of forces they consider to be (in particular the smallest possible amount of government intervention). The Austrian School derives its name from its predominantly Austrian founders and early supporters, including Carl Menger, Eugen von Bohm-Bawerk and Ludwig von Mises.
Query: Why do people engage in sports?
Answer:  People engage in sports for leisure and entertainment, as well as for physical exercise and athleticism.
Query: What is the effect of body chemistry on exercise?
Answer:  Body chemistry can affect the body's response to exercise, as certain hormones and enzymes produced by the body can affect the energy levels and muscle performance. Chemicals in the body, such as adenosine triphosphate (ATP) and urea, can affect the body's energy production and muscle metabolism during exercise. Additionally, the body's levels of electrolytes, vitamins, and minerals can affect exercise performance.
Exiting: Cleaning up .chroma directory
```


## LangChain Wrap Up

I wrote a Python book that goes into greater detail on both LangChain and also the library LlamaIndex that are often used together. You can my book [LangChain and LlamaIndex Projects Lab Book: Hooking Large Language Models Up to the Real World](https://leanpub.com/langchain) for free online using the *Free To Read Online Link*.