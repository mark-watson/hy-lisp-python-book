# Knowledge Base Navigator: Building an AI-Powered Information System {#kbn}

Earlier we looked at the Knowledge Graph Navigator (KGN) project that combined symbolic Natural Language Processing (NLP) with access to public knowledge graphs like DBPedia. Here we take a much simpler and more powerful approach using Google's Gemini API with built-in web search grounding.

The code can be found in the directory: **source_code_for_examples/knowledge_base_navigator**.

In this chapter, we explore a practical application that combines modern AI APIs with Hy to create an interactive knowledge exploration tool. The Knowledge Base Navigator demonstrates how to integrate external services using Python's rich library ecosystem while writing expressive Lisp-style code.

This example differs from the KGN project since no SPARQL queries or local knowledge base are involved. Instead, we use Gemini's built-in `google_search` tool to dynamically retrieve and synthesize information from the web. Dear reader, this is a fundamentally different and simpler approach!

## Project Overview

The Knowledge Base Navigator is a modern evolution of the classic Knowledge Graph Navigator (KGN). This new version uses Google's Gemini API to extract entities from natural language, disambiguate them, discover semantic links between entities, and retrieve detailed encyclopedic information. This represents a paradigm shift from traditional database-backed systems to an AI-driven pipeline.

The system follows a two-stage process:

1. **Entity Extraction**: The user provides text, Gemini identifies potential entities (people, companies, countries, etc.) and returns them as a numbered list
2. **Deep Retrieval**: The user selects entities by number, Gemini provides detailed facts and analyzes relationships between entities — grounded by live web search

## Project Structure

The Knowledge Base Navigator consists of just two files:

{linenos=off}
~~~~~~~~
knowledge_base_navigator/
├── pyproject.toml                    # uv project configuration
└── knowledge_base_navigator.hy      # Core application
~~~~~~~~

### Project Configuration

The `pyproject.toml` file defines the project and its dependencies:

{linenos=off}
~~~~~~~~
[project]
name = "knowledge-base-navigator"
version = "0.1.0"
description = "AI-powered Knowledge Base Navigator using Gemini"
readme = "README.md"
requires-python = ">=3.12"
dependencies = [
    "google-genai>=1.31.0",
    "hy>=1.1.0",
]
~~~~~~~~

We only need two dependencies beyond the Python standard library:

- **`google-genai`** — Google's official Python SDK for the Gemini API
- **`hy`** — The Hy language itself

Compare this to the KGN example which required `spacy`, `requests`, and several other libraries. By delegating entity extraction and knowledge retrieval to Gemini, we dramatically simplify our dependency footprint.

## Core Implementation

The following code is from the file **knowledge_base_navigator.hy**.

### Gemini API Client Setup

The SDK initialization is straightforward:

{lang="hylang",linenos=off}
~~~~~~~~
(import google [genai])

;; The google-genai SDK reads GOOGLE_API_KEY from the environment.
(setv client (genai.Client))
~~~~~~~~

The `genai.Client` constructor automatically reads the `GOOGLE_API_KEY` environment variable. This is a clean example of Hy's seamless Python interop — we import and use the Google SDK exactly as we would in Python, but with Lisp syntax.

### Generic Gemini Response Function

The core API function wraps the SDK's `generate_content` call:

{lang="hylang",linenos=off}
~~~~~~~~
(defn get-gemini-response [prompt #** kwargs]
  "Send a prompt to Gemini and return the text response.
   Accepts optional keyword arguments passed to config."
  (setv config (| {"tools" [{"google_search" {}}]} kwargs))
  (setv response
    (client.models.generate_content
      :model "gemini-2.5-flash"
      :contents prompt
      :config config))
  response.text)
~~~~~~~~

Key Hy patterns demonstrated here:

- **`#** kwargs`** collects arbitrary keyword arguments, equivalent to Python's `**kwargs`
- **`(| dict1 dict2)`** merges dictionaries, equivalent to Python's `dict1 | dict2`
- **Keyword arguments** to Python methods use the `:keyword value` syntax (`:model`, `:contents`, `:config`)
- **Attribute access** uses dot notation: `response.text`

The `google_search` tool is included by default in every request, giving Gemini access to live web search results for grounded, factual answers.

### Entity Extraction

The entity extraction function constructs a carefully engineered prompt:

{lang="hylang",linenos=off}
~~~~~~~~
(defn extract-entities [user-text]
  "Ask Gemini to identify encyclopedic entities in the user's text.
   Returns the raw numbered-list text from Gemini."
  (setv prompt
    (+ "Analyze the following user text: \"" user-text "\".\n"
       "Identify potential encyclopedic entities (people, companies, "
       "countries, cities, products, concepts, etc.) mentioned.\n"
       "Categorize them if necessary. Return them as a neatly formatted "
       "numbered list (1., 2., 3., etc.) with a short 1-sentence "
       "description for each.\n"
       "DO NOT return any other conversational text, ONLY the numbered "
       "list so the user can see their options."))
  (get-gemini-response prompt))
~~~~~~~~

**Prompt engineering principle**: Be explicit about output format. The instruction to return ONLY the numbered list prevents verbose conversational responses that would be harder to parse. This is a recurring pattern in LLM-powered applications — constrained output formatting makes downstream processing much simpler.

Notice how Hy's string concatenation with `+` keeps long prompts readable across multiple lines without complex escape sequences.

### User Selection Parsing

The selection parser handles flexible user input:

{lang="hylang",linenos=off}
~~~~~~~~
(defn parse-selections [selection-line]
  "Parse a string of space- or comma-separated numbers into a list
   of ints. Non-numeric tokens are silently ignored."
  (setv tokens (.split (.replace selection-line "," " ")))
  (setv result [])
  (for [token tokens]
    (when (.strip token)
      (try
        (.append result (int (.strip token)))
        (except [ValueError]
          None))))
  result)
~~~~~~~~

This function demonstrates several Hy idioms:

- **Method chaining**: `(.split (.replace selection-line "," " "))` — first replace commas with spaces, then split on whitespace
- **`try`/`except`**: Exception handling uses the same pattern as Python but with Hy's s-expression syntax
- **`when`**: A Lisp-style conditional that only executes its body when the test is truthy (equivalent to `if` without an else branch)

The function is intentionally lenient — if the user types `1, 2, 3` or `1 2 3` or even `1, two, 3`, it extracts the valid numbers and ignores everything else.

### Detail Retrieval with Relationship Discovery

The detail retrieval function sends a multi-task prompt to Gemini:

{lang="hylang",linenos=off}
~~~~~~~~
(defn get-entity-details [entity-list-text indices]
  "Ask Gemini for detailed facts and relationships for selected
   entities. entity-list-text is the numbered list from
   extract-entities. indices is a list of integers the user selected."
  (setv index-str (.join ", " (lfor i indices (str i))))
  (setv prompt
    (+ "Review this numbered list of entities:\n"
       entity-list-text "\n\n"
       "The user has selected entity numbers: " index-str ".\n"
       "Task 1: For each selected entity, generate detailed, factual, "
       "encyclopedic information (like birth place, description, and "
       "relationships for people; industry, net income, description, "
       "relationships for companies; and similar details for countries, "
       "cities, or products).\n"
       "Task 2: Evaluate ALL the selected entities collectively and "
       "explicitly summarize any known relationships, associations, or "
       "historical connections among them.\n"
       "Format the output carefully with clean section headers and "
       "bullet points."))
  (get-gemini-response prompt))
~~~~~~~~

The `lfor` (list comprehension for) expression `(lfor i indices (str i))` converts each integer index to a string, then `.join` assembles them into a comma-separated list. This is Hy's equivalent of Python's `", ".join(str(i) for i in indices)`.

The two-task prompt structure ensures we get both individual entity details AND a relationship analysis in a single API call, making efficient use of the Gemini API.

### Interactive UI Loop

The `kbn-ui` function implements the main interactive text interface:

{lang="hylang",linenos=off}
~~~~~~~~
(defn kbn-ui []
  "Main interactive loop for the Knowledge Base Navigator."
  (while True
    (print "\n============= GEMINI KNOWLEDGE BASE NAVIGATOR =============")
    (print "\nEnter entity names or a descriptive sentence (or 'quit' to exit):")
    (setv prompt (input "> "))

    (when (in (.lower (.strip prompt)) ["quit" "q"])
      (print "Goodbye!")
      (break))

    (when (> (len (.strip prompt)) 0)
      (print "\n[Extracting entities using Gemini...]")
      (setv entity-list-text (extract-entities prompt))

      (if (is entity-list-text None)
        (print "\n[Error getting entity list from Gemini. Please try again.]")
        (do
          (print (+ "\n--- IDENTIFIED ENTITIES ---\n"
                    entity-list-text
                    "\n---------------------------"))
          (print "\nEnter the numbers of entities for detailed info (space or comma separated):")
          (setv selection-line (input "> "))
          (setv indices (parse-selections selection-line))

          (if (= (len indices) 0)
            (print "\n[No valid selections made. Skipping to next prompt.]")
            (do
              (print "\n[Fetching detailed facts and relationships...]")
              (setv details (get-entity-details entity-list-text indices))
              (print (+ "\n" details)))))))))
~~~~~~~~

**Key loop patterns in Hy**:

- **`while True`** with **`(break)`** for controlled exit — the Lisp `loop`/`return` idiom translates naturally
- **`(input "> ")`** for user input — Python's built-in function called directly
- **`(when ...)`** guards for conditional execution
- **`(do ...)`** groups multiple expressions where only one is expected (like `progn` in Common Lisp)
- **Nested `if`/`do`** handles the multi-branch control flow

Finally, the entry point:

{lang="hylang",linenos=off}
~~~~~~~~
(when (= __name__ "__main__")
  (kbn-ui))
~~~~~~~~

This is the standard Python `if __name__ == "__main__"` guard expressed in Hy. It allows the file to be both imported as a module and run as a standalone script.

## Running the Application

{lang="bash",linenos=off}
~~~~~~~~
$ cd source_code_for_examples/knowledge_base_navigator
$ uv sync
$ uv run hy knowledge_base_navigator.hy
~~~~~~~~

### Example Session

{linenos=off}
~~~~~~~~
============= GEMINI KNOWLEDGE BASE NAVIGATOR =============

Enter entity names or a descriptive sentence (or 'quit' to exit):
> Bill Gates and Microsoft

[Extracting entities using Gemini...]

--- IDENTIFIED ENTITIES ---
1. Bill Gates: An American business magnate, software developer,
   and philanthropist who co-founded Microsoft Corporation.
2. Microsoft: A multinational technology corporation that develops,
   manufactures, and licenses computer software.
---------------------------

Enter the numbers of entities for detailed info (space or comma separated):
> 1 2

[Fetching detailed facts and relationships...]

=== BILL GATES ===
* Born: October 28, 1955, Seattle, Washington
* Occupation: Business magnate, investor, philanthropist
* Net Worth: ~$120 billion
* Founded Microsoft in 1975 with Paul Allen

=== MICROSOFT ===
* Founded: April 4, 1975
* Headquarters: Redmond, Washington
* Industry: Technology, Software, Cloud Computing
* Revenue: $211 billion (2023)

=== RELATIONSHIP ===
Bill Gates co-founded Microsoft with Paul Allen in 1975.
He served as CEO until 2000 and remained Chairman until 2014.
Microsoft was the primary source of Gates' wealth.
~~~~~~~~

## Key Takeaways

1. **Python Interop**: Hy seamlessly imports and uses Python libraries like `google-genai`. The SDK's Pythonic API translates naturally to Hy's s-expression syntax with keyword arguments.
2. **Minimal Dependencies**: By delegating entity extraction and knowledge retrieval to Gemini, we eliminate the need for NLP libraries (spacy), SPARQL endpoints, and HTTP request handling that the KGN example required.
3. **Prompt Engineering**: Constructing clear prompts with explicit format instructions is essential. The "ONLY the numbered list" constraint prevents verbose responses.
4. **Web Search Grounding**: Gemini's `google_search` tool provides live, grounded results rather than relying on static knowledge bases — the information is always current.
5. **Interactive CLI in Hy**: `while True` + `input` + `print` create effective command-line interfaces. Hy's `when` and `do` forms provide clean control flow.
6. **Error Tolerance**: The `parse-selections` function demonstrates defensive programming — accepting flexible input formats and silently ignoring invalid entries rather than crashing.

## Comparison with KGN

| Aspect | KGN (Chapter 12) | Knowledge Base Navigator |
|--------|-------------------|--------------------------|
| Entity Recognition | spaCy NLP model | Gemini LLM |
| Data Source | DBPedia via SPARQL | Gemini + web search |
| Dependencies | 6+ libraries | 2 libraries |
| Source Files | 5 files | 1 file |
| Data Currency | Static knowledge graph | Live web results |
| Relationship Discovery | SPARQL graph traversal | LLM reasoning |

Both approaches have merits. The KGN approach gives you structured, machine-readable relationships from a curated knowledge graph. The Knowledge Base Navigator approach gives you richer, more flexible information with natural language descriptions, at the cost of less structured output. The choice depends on your use case.

## Environment Setup

{lang="bash",linenos=off}
~~~~~~~~
# Set API key before running
export GOOGLE_API_KEY="your_api_key_here"

# Install dependencies and run
cd source_code_for_examples/knowledge_base_navigator
uv sync
uv run hy knowledge_base_navigator.hy
~~~~~~~~

---

This example demonstrates that Hy is an excellent choice for AI-powered applications. The combination of Lisp's expressive syntax with Python's rich library ecosystem makes it easy to build sophisticated tools with minimal code. The `google-genai` SDK integrates naturally with Hy, and the result is a concise, readable application that would be substantially more verbose in most other languages.
