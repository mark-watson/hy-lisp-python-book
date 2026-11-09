# OpenAI Completion Example

**Book Chapter:** [Using OpenAI GPT](https://leanpub.com/read/hy-lisp-python/leanpub-auto-using-openai-gpt) — *A Lisp Programmer Living in Python-Land* (free to read online).

This example demonstrates calling the **OpenAI GPT chat completion API** from Hy using the [openai](https://pypi.org/project/openai/) Python package. The script `text_completion.hy` sends a prompt to the model and prints the response.

![OpenAI chat completion architecture: Hy client to GPT API request and response flow](FIG_openai_apis.png)

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager
- An OpenAI API key set as the `OPENAI_API_KEY` environment variable

## Running the Example

```bash
uv sync
uv run hy text_completion.hy
```

## Running the Tests

The tests are written in Hy in `test_text_completion.hy`. Run them with:

```bash
uv run pytest
```

No API key or network access is needed: the OpenAI client is replaced with a fake, and `conftest.py` sets a placeholder `OPENAI_API_KEY` because the client is created when the module is imported.

By default pytest does not collect `.hy` files, so `conftest.py` adds a small hook that tells it to collect any file named `test_*.hy`. To add more tests, create another `test_*.hy` file or add `test-` functions to `test_text_completion.hy`.
