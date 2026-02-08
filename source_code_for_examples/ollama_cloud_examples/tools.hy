(import os)
(import httpx)
(import markdownify [markdownify])

(defn list-directory []
  "Lists files and directories in the current working directory"
  ; Args:
  ;   None
  ; Returns:
  ;   string containing the current directory name, followed by list of files in the directory
  (setv current-dir (os.path.realpath "."))
  (setv files (.listdir os))

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
