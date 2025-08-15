(import os)

(defn list-directory []
  "Lists files and directories in the current working directory"
  ; Args:
  ;   None
  ; Returns:
  ;   string containing the current directory name, followed by list of files in the directory
  (setv current-dir (os.path.realpath "."))
  (setv files (.listdir os))

  (return f"Contents of current directory {current-dir} is: {files}"))


; Function metadata for Ollama integration (Hy doesn't have function metadata like Python)
; You might need to store this information separately or adapt it to your Ollama integration method.
; For example, you could create a dictionary mapping function names to their metadata.

(setv list-directory-metadata
  {
    "name" "list_directory"
    "description" "Lists files and directories in the current working directory"
    "parameters" {}
  })


