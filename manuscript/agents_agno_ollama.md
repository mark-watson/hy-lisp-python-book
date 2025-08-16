# Agents Using Agno Agent Framework Running On Local Ollama Model

The example in this chapter uses a local LLM running on Ollama. The examples for this chapter are found in the directory **agents_agno**.

## An Agent For Answering Questions About A Specific Web Site

TBD

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
    Use this tool when you need to read the contents of a specific web page to answer a question.
    
    Args:
        url (str): The full, valid URL of the webpage to be scraped (e.g., 'https://example.com').
        
    Returns:
        str: The extracted text content of the webpage, or a descriptive error message if scraping fails.
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
              f"Successfully connected to {url}, but no text content could be extracted."
              f"Successfully scraped content from {url}:\n\n{text}")))))))

;; Initialize the web scraping and analysis agent
(setv scraper-agent (Agent
  :model (Ollama :id "qwen3:30b")
  :tools [scrape-website-content]
  :description (dedent
    "You are an expert web scraping and analysis agent. You follow a strict process:

    - Given a URL in a prompt, you will first use the appropriate tool to scrape its content.
    - You will then carefully read the scraped content to understand it thoroughly.
    - Finally, you will answer the user's question based *only* on the information contained within that specific URL's content.")
  
  ;; The instructions are refined to provide a clear, step-by-step reasoning process.
  :instructions (dedent
    "1. Scrape Phase 🕸️
       - Analyze the user's prompt to identify the target URL.
       - Invoke the `scrape` tool with the identified URL.

    2. Analysis Phase 📊
       - Carefully read the entire content returned by the `scrape` tool.
       - Systematically extract the specific information required to answer the user's question.

    3. Answering Phase ✍️
       - Formulate a concise and accurate answer based exclusively on the scraped information.
       - If the information is not present, state that clearly.

    4. Quality Control ✓
       - Reread the original query and your answer to ensure it is accurate and relevant.")
  
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

agents_agno $ uv run hy web_site_qa.hy

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
