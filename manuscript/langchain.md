# Using LangChain to Chain Together Large Language Models

Harrison Chase started the LangChain project in October 2022 and as I write this chapter in May 2023 the GitHub repository for LangChain [https://github.com/hwchase17/langchain](https://github.com/hwchase17/langchain) has over 200 contributors.

The material in this chapter is a very small subset of material in my recent Python book [LangChain and LlamaIndex Projects Lab Book: Hooking Large Language Models Up to the Real World.
Using GPT-3, ChatGPT, and Hugging Face Models in Applications.](https://leanpub.com/langchain) that you can read for free online by using the link *Free To Read Online*.

[LangChain](https://langchain.readthedocs.io/en/latest/index.html) is a framework for building applications with large language models (LLMs) through chaining different components together. Some of the applications of LangChain are chatbots, generative question-answering, summarization, data-augmented generation and more. LangChain can save time in building chatbots and other systems by providing a standard interface for chains, agents and memory, as well as integrations with other tools and end-to-end examples. We refer to "chains" as sequences of calls (to an LLMs and a different program utilities, cloud services, etc.) that go beyond just one LLM API call. LangChain provides a standard interface for chains, many integrations with other tools, and end-to-end chains for common applications. Often you will find existing chains already written that meet the requirements for your applications.

For example, one can create a chain that takes user input, formats it using a PromptTemplate, and then passes the formatted response to a Large Language Model (LLM) for processing.

While LLMs are very general in nature which means that while they can perform many tasks effectively, they often can not directly provide specific answers to questions or tasks that require deep domain knowledge or expertise. LangChain provides a standard interface for agents, a library of agents to choose from, and examples of end-to-end agents.

LangChain Memory is the concept of persisting state between calls of a chain or agent. LangChain provides a standard interface for memory, a collection of memory implementations, and examples of chains/agents that use memory². LangChain provides a large collection of common utils to use in your application. Chains go beyond just a single LLM call, and are sequences of calls (whether to an LLM or a different utility). LangChain provides a standard interface for chains, lots of integrations with other tools, and end-to-end chains for common applications.

LangChain can be integrated with one or more model providers, data stores, APIs, etc.


## Installing Necessary Packages

For the purposes of examples in this chapter, you might want to create a new Anaconda or other Python environment and install:

    pip install langchain openai


## Basic Usage and Examples

While I try to make the material in this book independent, something you can enjoy with no external references, you should also take advantage of the high quality [documentation](LangChain Quickstart Guide) and the individual detailed guides for prompts, chat, document loading, indexes, etc.

As we work through some examples please keep in mind what it is like to use the ChatGPT web application: you enter text and get respponses. The way you prompt ChatGPT is obviously important if you want to get useful responses. In code examples we automate and formalize this manual process.

You need to choose a LLM to use. We will usually choose the GPT-3.5 API from OpenAI because it is general purpose and much less expensive than OpenAI's previous model APIs. You will need to [sign up](https://platform.openai.com/account/api-keys) for an API key and set it as an environment variable:

    export OPENAI_API_KEY="YOUR KEY GOES HERE"

Both the libraries **openai** and **langchain** will look for this environment variable and use it. We will look at a few simple examples in a Hy REPL. We will start by just using OpenAI's text prediction API that accepts a prompt and then continues generating text from that prompt:

```console
$ hy
Hy 0.26.0 using CPython(main) 3.11.0 on Darwin
=> (import langchain.llms [OpenAI])
=> (setv llm (OpenAI :temperature 0.8))
=> (llm "John got into his new sports car, and he drove it")
" to work. He felt really proud that he was able to afford the car and even parked it in a prime spot so everyone could see. He felt like he had really made it."
=> 
```

The temperature should have a value between 0 and 1. Use a small temperature value to get repeatable results and a large temperature value is you want very different completions each time you pass the same prompt text.

Our next example is in the source file **directions_template.hy** and uses the **PromptTemplate** class. A prompt template is a reproducible way to generate a prompt. It contains a text string (“the template”), that can take in a set of parameters from the end user and generate a prompt. The prompt template may contain language model instructions, few-shot examples to improve the model’s response, or specific questions for the model to answer.


```hy
(import langchain.prompts [PromptTemplate])
(import langchain.llms [OpenAI])

(setv llm (OpenAI :temperature 0.9))

(defn get_directions [thing_to_do]
   (setv
     prompt
     (PromptTemplate
       :input_variables ["thing_to_do"]
       :template "How do I {thing_to_do}?"))
    (setv
      prompt_text
      (prompt.format :thing_to_do thing_to_do))
    ;; Print out generated prompt when you are getting started:
    (print "\n" prompt_text ":")
    (llm prompt_text))
```

You could just write Hy string manipulation code to create a prompt but using the utility class **PromptTemplate** is more legible and works with any number of prompt input variables. In this example, the prompt template is really simple. For more complex Python examples see the [LangChain prompt documentation](https://python.langchain.com/en/latest/modules/prompts/prompt_templates/examples/few_shot_examples.html). We will later see a more complex prompt example.

Let's change directory to **hy-lisp-python/langchain** and run two examples in a Hy REPL:

```console
$ hy
Hy 0.26.0 using CPython(main) 3.11.0 on Darwin
=> (import directions_template [get_directions])
=> (print (get_directions "hang a picture on the wall"))

 How do I hang a picture on the wall? :


1. Gather necessary items: picture, level, appropriate hardware for your wall type (nails, screws, anchors, etc).

2. Select the location of the picture on the wall. Use a level to ensure that the picture is hung straight. 

3. Mark the wall where the hardware will be placed.

4. Securely attach the appropriate hardware to the wall. 

5. Hang the picture and secure with the hardware. 

6. Stand back and admire your work!
=> (print (get_directions "get to the store"))

 How do I get to the store? :


The best way to get to the store depends on your location. If you are using public transportation, you can use a bus or train to get there. If you are driving, you can use a GPS or maps app to find the fastest route.
=> 
```

The next example in the file **country_information.hy** is derived from an example in the LangChain documentation. In this example we use  **PromptTemplate** that contains the pattern we would like the LLM to use when returning a response.

```hy
(import langchain.prompts [PromptTemplate])
(import langchain.llms [OpenAI])

(setv llm (OpenAI :temperature 0.9))

(setv
  template
  "Predict the capital and population of a country.\n\nCountry: {country_name}\nCapital:\nPopulation:\n")

(defn get_country_information [country_name]
  (print "Processing " country_name ":")
  (setv
     prompt
     (PromptTemplate
       :input_variables ["country_name"]
       :template template))
  (setv
      prompt_text
      (prompt.format :country_name country_name))
  ;; Print out generated prompt when you are getting started:
  (print "\n" prompt_text ":")
  (llm prompt_text))
```

You can use the ChatGPT web interface to experiment with prompts and when you find a pattern that works well then write a Python script like the last example, but changing the data you supply in the **PromptTemplate** instance.

Here are two examples of this code for getting information about  Canada and Germany:

```console
$ hy
Hy 0.26.0 using CPython(main) 3.11.0 on Darwin
=> (import country_information [get_country_information])
=> (print (get_country_information "Canada"))
Processing  Canada :

 Predict the capital and population of a country.

Country: Canada
Capital:
Population:
 :

Capital: Ottawa
Population: 37,592,000 (as of 2019)
=> (print (get_country_information "Germany"))
Processing  Germany :

 Predict the capital and population of a country.

Country: Germany
Capital:
Population:
 :

Capital: Berlin
Population: 83 million
=> 
```

We print the generated prompt and you can try copying this text (here for Canada) into the ChatGPT web app:

```console
Predict the capital and population of a country.

Country:Canada
Capital:
Population:
```

So there is no magic here. We are simply generating prompts that contain context data.
 
## Creating Embeddings

We will reference the [LangChain embeddings documentation](https://python.langchain.com/en/latest/reference/modules/embeddings.html). We can use a Hy REPL to see what text to vector space embeddings might look like:

```console
 $ hy
Hy 0.26.0 using CPython(main) 3.11.0 on Darwin
=> (import langchain.embeddings [OpenAIEmbeddings])
=> (setv embeddings (OpenAIEmbeddings))
=> (setv text "Mary has blond hair and John has brown hair. Mary lives in town and John lives in the country.")
=> (setv doc_embeddings (embeddings.embed_documents [text]))
=> doc_embeddings
[[0.007754440331396565 0.0008957661819527747 -0.003335848878474548 -0.01803736554483232 -0.017987297643789046 0.028564378295111985 -0.013368429464419828 0.004709617646993997..]]
=> (setv query_embedding (embeddings.embed_query "Does John live in the city?"))
=> query_embedding
[0.028118159621953964 0.011476404033601284 -0.009456867352128029 ...]
```

Notice that the **doc_embeddings** is a list where each list element is the embeddings for one input text document. The **query_embedding** is a single embedding. Please read the above linked embedding documentation.

We will use vector stores to store calculated embeddings for future use in the next example.

## Using LangChain Vector Stores to Query Documents

We will reference the [LangChain Vector Stores documentation](https://python.langchain.com/en/latest/reference/modules/vectorstore.html). You need to install a few libraries:

    pip install chroma
    pip install chromadb
    pip install unstructured pdf2image pytesseract

The next document query example is contained in a single script **hy-lisp-python/langchain/doc_search.hy** with three document queries at the end of the script. In this example we read the text file documents in the directory **hy-lisp-python/langchain/data** and create a local embeddings datastore we use for natural language queries:

```hy
(import langchain.text_splitter [CharacterTextSplitter])
(import langchain.vectorstores [Chroma])
(import langchain.embeddings [OpenAIEmbeddings])
(import langchain.document_loaders [DirectoryLoader])
(import langchain [OpenAI VectorDBQA])

(setv embeddings (OpenAIEmbeddings))

(setv loader (DirectoryLoader "./data/" :glob "**/*.txt"))
(setv documents (loader.load))

(setv
  text_splitter
  (CharacterTextSplitter :chunk_size 2500 :chunk_overlap 0))

(setv
  texts
  (text_splitter.split_documents documents))

(setv
  docsearch
  (Chroma.from_documents texts  embeddings))

(setv
  qa
  (VectorDBQA.from_chain_type
    :llm (OpenAI)
    :chain_type "stuff"
    :vectorstore docsearch))

(defn query [q]
  (print "Query: " q)
  (print "Answer: " (qa.run q)))

(query "What kinds of equipment are in a chemistry laboratory?")
(query "What is Austrian School of Economics?")
(query "Why do people engage in sports?")
(query "What is the effect of body chemistry on exercise?")
```

The **DirectoryLoader** class is useful for loading a directory full of input documents. In this example we specified that we only want to process text files, but the file matching pattern could have also specified PDF files, etc.

The output is:

```console
$ hy doc_search.hy
Using embedded DuckDB without persistence: data will be transient
Query:  What kinds of equipment are in a chemistry laboratory?
Answer:   A chemistry laboratory typically contains various glassware, as well as other equipment such as beakers, flasks, test tubes, Bunsen burners, hot plates, and other materials used for conducting experiments.
Query:  What is Austrian School of Economics?
Answer:   The Austrian School of economics is a school of economic thought that emphasizes the spontaneous organizing power of the price mechanism. Austrians hold that the complexity of subjective human choices makes mathematical modelling of the evolving market extremely difficult and advocate a "laissez faire" approach to the economy. Austrian School economists advocate the strict enforcement of voluntary contractual agreements between economic agents, and hold that commercial transactions should be subject to the smallest possible imposition of forces they consider to be (in particular the smallest possible amount of government intervention). The Austrian School derives its name from its predominantly Austrian founders and early supporters, including Carl Menger, Eugen von Böhm-Bawerk and Ludwig von Mises.
Query:  Why do people engage in sports?
Answer:   People engage in sports because they are enjoyable activities that involve physical athleticism or dexterity, and are governed by rules to ensure fair competition and consistent adjudication of the winner.
Query:  What is the effect of body chemistry on exercise?
Answer:   Body chemistry can affect the transfer of energy from one chemical substance to another, as well as the efficiency of energy-producing systems that do not rely on oxygen, such as anaerobic exercise. It can also affect the body's ability to produce enough moisture, which can lead to dry eye and other symptoms.
```

If you use this example to index a large number of documents you will want to use a separate script to load the documents, call the OpenAI text embedding API to store the index for future use. Then any application can reuse your local index. If you add documents to your data directory then re-run the script to create the local index. You can see examples of persistent vector stores in [my LangChain book](https://leanpub.com/langchain/read).

## LangChain Wrap Up

I wrote a Python book that goes into greater detail on both LangChain and also the library LlamaIndex that are often used together. You can buy my book [LangChain and LlamaIndex Projects Lab Book: Hooking Large Language Models Up to the Real World](https://leanpub.com/langchain) or read it for free online using the *Free To Read Online Link*.