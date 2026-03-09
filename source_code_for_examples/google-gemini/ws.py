import sys
from google import genai

client = genai.Client()

query = (
    sys.argv[1]
    if len(sys.argv) > 1
    else (print('Usage: python ws.py "query"') or sys.exit(1))
)
print(
    client.models.generate_content(
        model="gemini-2.5-flash",
        contents=query,
        config={"tools": [{"google_search": {}}]},
    ).text
)
