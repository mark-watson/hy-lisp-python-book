# Run:

**Book Chapter:** [Using Google Gemini API](https://leanpub.com/read/hy-lisp-python/leanpub-auto-using-google-gemini-api) — *A Lisp Programmer Living in Python-Land* (free to read online).

## chat

```
$ uv sync
$ uv run hy chat.hy
```

## Gemini search tool

```
$ uv run  hy web_search.hy "What is the latest news about the James Webb Space Telescope?"
The James Webb Space Telescope (JWST) continues to deliver groundbreaking observations and discoveries, providing unprecedented insights into the universe. Recent highlights include:

*   **Exoplanet Atmospheres and "Puffy" Planets** The JWST has helped resolve a long-standing mystery surrounding "puffy" exoplanets by detecting thick atmospheres around them. It has also captured compelling evidence of a planet with a mass similar to Saturn orbiting the young star TWA 7.
*   **Stellar Nurseries and Star Formation** New images from the telescope have revealed the "ghostly glow" of newborn stars within stellar nurseries in the Triangulum galaxy, offering an unprecedented view of how stars and planets begin to form.
...
```

## Web URI context

```
$ uv run hy context_url.hy
Mark Watson plays the guitar, didgeridoo, and American Indian flute.
```

## Code Notes

### chat.hy - Continuous chat interface

Uses the requests library to maintain a conversation with Gemini:

- Stores chat history between turns
- Alternates between "user" and "model" roles
- Default: 2000 max tokens, 1.2 temperature
- Continuously prompts for input until EOF

### context_url.hy - Web content Q&A

Uses google-genai SDK with url_context tool:

- Fetches and analyzes web page content
- Takes prompt containing both URL and question
- Example: "https://example.com What products are mentioned?"

### web_search.hy - Live web search

Uses google-genai SDK with google_search tool:

- Performs live Google searches via Gemini
- Accepts search query as command-line argument
- Example: "hy web_search.hy 'latest JWST news'"

Architecture: The code demonstrates two approaches - chat.hy uses direct HTTP requests for manual control, while web_search.hy and context_url.hy use Google's SDK for simpler tool integration. All require GOOGLE_API_KEY environment variable.

