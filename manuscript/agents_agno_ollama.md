# Agents Using Agno Agent Framework Running On Local Ollama Model

The example in this chapter uses a local LLM running on Ollama. The examples for this chapter are found in the directory **agents_agno**.

## An Agent For Answering Questions About A Specific Web Site

Here we construct a sophisticated web scraping agent using the agno library. This program defines a specialized tool, **scrape-website-content** which leverages the **requests** and **BeautifulSoup** libraries to fetch and parse the textual content from any given URL, stripping away common non-content elements like navigation bars and scripts. This tool is then integrated into an Agent powered by a local Ollama model. The agent is configured with a detailed description, a step-by-step instruction set, and a defined output format, guiding it to first scrape a user-provided URL and then answer a specific question based only on the extracted information, ensuring a focused and verifiable response.

```hy
(import textwrap [dedent])
(import os requests)
(import bs4 [BeautifulSoup])
(import agno.agent [Agent])
(import agno.models.ollama [Ollama])
(import agno.tools [tool])

(tool ;; in Python this would be a @tool annotation
  (defn scrape-website-content [url]
    "Fetches and extracts the clean, textual content from a given webpage URL.
    Use this tool when you need to read the contents of a specific web page to
    answer a question.
    
    Args:
        url (str): The full, valid URL of the webpage to be scraped
        (e.g., 'https://example.com').
        
    Returns:
        str: The extracted text content of the webpage.
    "
    (try
      ;; Set a User-Agent header to mimic a real browser.
      (let
        [headers
         {"User-Agent" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"}
         response (requests.get url :headers headers :timeout 10)]
        (.raise_for_status response)
        (let [soup (BeautifulSoup response.text "html.parser")]
          ;; Remove unwanted tags
          (for [tag (soup ["script" "style" "nav" "footer" "aside"])]
            (.decompose tag))
          (let [text (.get_text soup :separator "\n" :strip True)]
            (if (not text)
              f"Connected to {url}, but no text content could be extracted."
              f"Successfully scraped content from {url}:\n\n{text}")))))))

;; Initialize the web scraping and analysis agent
(setv scraper-agent (Agent
  :model (Ollama :id "qwen3:30b")
  :tools [scrape-website-content]
  :description (dedent
    "You are an expert web scraping and analysis agent. You follow a strict process:

    - Given a URL in a prompt, you will first use the appropriate tool to scrape
      its content.
    - You will then carefully read the scraped content to understand it thoroughly.
    - Finally, you will answer the user's question based *only* on the information
      contained within that specific URL's content.")
  
  ;; The instructions are refined to provide a clear, step-by-step reasoning process.
  :instructions (dedent
    "1. Scrape Phase 🕸️
       - Analyze the user's prompt to identify the target URL.
       - Invoke the `scrape` tool with the identified URL.

    2. Analysis Phase 📊
       - Carefully read the entire content returned by the `scrape` tool.
       - Systematically extract the specific information required to answer the
         user's question.

    3. Answering Phase ✍️
       - Formulate a concise and accurate answer based exclusively on the scraped
         information.
       - If the information is not present, state that clearly.

    4. Quality Control ✓
       - Reread the original query and your answer to ensure it is accurate
         and relevant.")
  
  :expected_output (dedent
    "# {Answer based on website content}
    
    **Source:** {URL provided by the user}")
  
  :markdown True
  :show_tool_calls True
  :add_datetime_to_instructions True))

;; Main execution block
(when (= __name__ "__main__")
  (setv prompt "Using the web site https://markwatson.com Consultant Mark Watson has written Common Lisp, semantic web, Clojure, Java, and AI books. What musical instruments does he play?")
  
  (.print-response scraper-agent
    prompt
    :stream True))
```

This code is divided into two main parts: the tool definition and the agent configuration.

The first part is the definition of the **scrape-website-content** function acts as the agent's primary capability. It takes a URL, uses the requests library to perform an HTTP GET request (while mimicking a browser's User-Agent header to improve compatibility), and then processes the resulting HTML with BeautifulSoup. Critically, it removes tags like <script>, <style>, <nav>, and <footer> that typically contain boilerplate or non-essential content. This cleaning step is vital as it provides the language model with a concise and relevant block of text, free from the noise of web page structure and styling, allowing it to focus on the core information needed to answer the user's query.

The second part initializes the Agent from the agno library. This is where the AI's behavior is defined. It's configured to use a specific Ollama model and is given access to the scrape-website-content tool we defined. The description and instructions parameters are crucial; they act as a system prompt that programs the agent's workflow, forcing it into a strict sequence of scraping, analyzing, and then answering. By specifying expected_output, we enforce a consistent structure on the agent's final response. The main execution block demonstrates a practical example, asking the agent to find information about musical instruments from a specific website, which triggers the entire scrape-and-answer process.

*Note: The AGno framework prints beautiful colored bounding boxes around blocks of output text. In the following listing the bounding boxes, represented by four specific Unicode characters, just show up here as tiny box-characters.*

```text
$ uv run hy web_site_qa.hy
┏━ Message ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                                                               ┃
┃ Using the web site https://markwatson.com Consultant Mark Watson has written  ┃
┃ Common Lisp, semantic web, Clojure, Java, and AI books. What musical          ┃
┃ instruments does he play?                                                     ┃
┃                                                                               ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
┏━ Tool Calls ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                                                               ┃
┃ • scrape_website_content(url=https://markwatson.com)                          ┃
┃                                                                               ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
┏━ Response (11.8s) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                                                               ┃
┃ Mark Watson plays the guitar, didgeridoo, and American Indian flute.          ┃
┃                                                                               ┃
┃ Source: https://markwatson.com                                                ┃
┃                                                                               ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

## Wrap Up for Agno Agent Example

The Python source code repository for Agno is found here: [https://github.com/agno-agi/agno](https://github.com/agno-agi/agno).

Documentation is found here: [https://docs.agno.com/introduction](https://docs.agno.com/introduction).

There were a few Hy-specific nuances for using Agno with the Hy language. Hopefully, dear reader, the example here serves as a good example fr writing your own aganet in the Hy language.