# Using Perplexity Sonar Model for Combined Web Search and LLM Based Reasoning

This chapter combines ideas from the earlier chapter "Using the Microsoft Bing Search APIs" and using LLMs for reasoning.  We will use a commercial API from Perplexity. You need a Perplexity API key: [https://docs.perplexity.ai/home](https://docs.perplexity.ai/home)

I buy $5 of credits at a time and these credits usually last me a few months of experimenting, your mileage may vary. If you use this API in production you will want to check the pricing information and use the cheapest model that will work for you: [https://docs.perplexity.ai/guides/pricing](https://docs.perplexity.ai/guides/pricing)

Perplexity's Sonar API represents a significant advancement in leveraging large language models by seamlessly integrating real-time web search capabilities directly into the reasoning process. Unlike traditional approaches that might require complex orchestration between separate search APIs and LLMs, Sonar allows the language model to autonomously access and synthesize current information from the web as it formulates a response. This dynamic interaction ensures that the generated outputs are not limited to the potentially outdated knowledge contained within the model's training data, thereby providing more accurate, relevant, and up-to-date answers. The API offers different models, such as Sonar, Sonar Pro, Sonar Reasoning, and Sonar Deep Research, each tailored for varying levels of search depth, reasoning complexity, and the ability to handle intricate, multi-step queries. A key benefit of using the Perplexity API for this combined approach is the ability to ground LLM responses in verifiable information, often accompanied by citations to the sources found during the real-time search. This enhances the trustworthiness and reliability of the AI's output, which is particularly valuable for applications requiring factual accuracy. You, dear reader, can utilize the Perplexity API to build applications that require access to current events, perform in-depth research, or provide answers to questions where the information is constantly changing, effectively overcoming the limitations of models that rely solely on static knowledge and mitigating the risk of generating incorrect or fabricated information.

## A Hy Language Client Library for Perplexity

The following Hy code defines a function **search_llm** that interacts with the Perplexity AI API to answer a user query. It begins by importing necessary libraries like **os** to retrieve the API key from the environment variable PERPLEXITY_API_KEY and the Python OpenAI library (Perplexity offers an OpenAI compatibility feature that we use here), which is configured to use the Perplexity API endpoint. A standard system message is defined to instruct the AI on its role as a programming and tech assistant utilizing web search and reasoning. The **search_llm** function takes a query string, constructs a conversation history including the system message and the user's query, initializes the **openai.OpenAI** client pointing to the Perplexity API's base URL and using the retrieved key, sends the messages to the "sonar" model via the chat completions endpoint, extracts the text content of the first message from the AI's response, and returns this content string. Finally for testing, the script calls the search_llm function with a specific question about Mark Watson's musical instruments and prints the resulting answer from the AI.

Here is a listing of the file **perplexity_search_llm/search_llm.hy**:

```hy
(import os)
(import openai)
(import pprint [pprint]) ; Import pprint for potentially pretty printing responses

;; Set your Perplexity API key from an environment variable
(setv YOUR-API-KEY (os.environ.get "PERPLEXITY_API_KEY"))

;; Define the messages for the conversation using triple quotes for multiline content
(setv system-message
      {"role" "system"
       "content" "You are an artificial intelligence assistant for helping a user with programming and tech questions using web search and reasoning."})

(defn search_llm [query]
  (setv user-message
        {"role" "user"
         "content" query})
  
  (setv messages [system-message user-message])

  ;; Initialize the OpenAI client, pointing to the Perplexity API base URL
  (setv client (openai.OpenAI :api-key YOUR-API-KEY
                              :base-url "https://api.perplexity.ai"))

  ;; --- Chat completion without streaming ---
  (setv response (client.chat.completions.create
                   :model "sonar" ; Use a model supported by Perplexity
                   :messages messages))
  (setv choices-list (. response choices))
  (setv first-choice (get choices-list 0))
  (setv message-object-result (. first-choice message))
  (setv content-string (. message-object-result content))
  ;;(print content-string)
  content-string)

(print (search_llm "Consultant Mark Watson has written many books on AI, Lisp and the semantic web. What musical instruments does he play?"))
```

In this code, I unpack the response data in several steps so you can use **pprint** to inspect the response and optionally use other data returned by the Perplexity API.

## Example Output

Here is the output from the test query at the bottom of the last program listing:

```text
$ venv/bin/hy search_llm.hy                                                         
Mark Watson, the consultant known for writing books on AI, Lisp, and the semantic web, plays several musical instruments as a hobby. These include the **guitar**, **didgeridoo**, and **American Indian flute**[4]. There is no indication in the available information that he is professionally involved in music or plays any other instruments beyond these. 

It's worth noting that there are other individuals with the name Mark Watson who are involved in music professionally, such as Mark Watson (@markwatsonmusic) and another Mark Watson who is a bass baritone[1][5]. However, the consultant Mark Watson mentioned in the query is distinct from these individuals and is known for his work in technology and AI[4].
```

## Wrap Up for Using Perplexity

While the Perplexity API could be expensive to use in high API call volume production applications, I find it to be very useful for simplifying my code when I need to combine web search with LLM use.