(import os)
(import httpx)
(import markdownify [markdownify])
(import datetime [datetime])
(import xml.etree.ElementTree :as ET)

(defn list-directory []
  "Lists files and directories in the current working directory"
  ; Args:
  ;   None
  ; Returns:
  ;   string containing the current directory name, followed by list of files in the directory
  (setv current-dir (os.path.realpath "."))
  (setv files (os.listdir current-dir))

  (return f"Contents of current directory {current-dir} is: {files}"))

(defn read-file-contents [file-path]
  "Reads the contents of a file, given an input file-path"
  ; Args:
  ;   file-path: The path to the file
  ; Returns:
  ;   The contents of the file as a string
  (with [f (open file-path "r")]
    (.read f)))

(defn uri-to-markdown [uri]
  "Fetches HTML from a URI and converts it to markdown."
  (setv response (httpx.get uri))
  (.raise-for-status response)
  ; Convert the HTML text to Markdown
  (setv md (markdownify response.text))
  (return f"# Content from {uri}\n\n{md}"))

(defn write-file-contents [file-path content]
  "Writes the provided content to a file, given an input file-path"
  (with [f (open file-path "w")]
    (.write f content))
  (return f"Successfully wrote to {file-path}"))

(defn get-current-datetime []
  "Returns the current system date and time as a string"
  (return (.strftime (datetime.now) "%Y-%m-%d %H:%M:%S")))

(defn get-weather [location]
  "Fetches current weather data for a given city or region"
  (setv response (httpx.get f"https://wttr.in/{location}?format=3"))
  (.raise-for-status response)
  (return (.strip response.text)))

(defn search-wikipedia [query]
  "Takes a search query and returns an introductory summary paragraph from Wikipedia"
  (setv url f"https://en.wikipedia.org/api/rest_v1/page/summary/{query}")
  (setv url (.replace url " " "_"))
  (setv headers {"User-Agent" "OllamaToolsExample/1.0 (https://github.com/markwatson/ollama_cloud_examples)"})
  (setv response (httpx.get url :headers headers))
  (if (= response.status_code 200)
    (do
      (setv data (.json response))
      (return (get data "extract")))
    (return f"Failed to fetch Wikipedia page for {query}")))

(defn get-npr-news []
  "Fetches the top daily news headlines and summaries from NPR's public RSS feed"
  (setv headers {"User-Agent" "OllamaToolsExample/1.0 (https://github.com/markwatson/ollama_cloud_examples)"})
  (setv response (httpx.get "https://feeds.npr.org/1001/rss.xml" :headers headers))
  (.raise-for-status response)
  (setv root (ET.fromstring response.text))
  (setv items (get (.findall root "./channel/item") (slice 0 5)))
  (setv news-md "# NPR Top News\n\n")
  (for [item items]
    (setv title (. (item.find "title") text))
    (setv desc (. (item.find "description") text))
    (setv link (. (item.find "link") text))
    (setv news-md (+ news-md f"## [{title}]({link})\n{desc}\n\n")))
  (return news-md))
