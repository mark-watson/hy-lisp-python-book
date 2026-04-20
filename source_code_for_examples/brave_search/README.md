# Using the Brave Search APIs

**Book Chapter:** [Using the Brave Search APIs](https://leanpub.com/read/hy-lisp-python/leanpub-auto-using-the-brave-search-apis) — *A Lisp Programmer Living in Python-Land* (free to read online).

You will need an API key - see book for details.

## Running an example

```
$ uv run hy -i brave.hy 
Hy 1.1.0 (Business Hugs) using CPython(main) 3.12.0 on Darwin
=> (brave-search "site:wikidata.org Sedona Arizona")
[["Sedona - Wikidata" "https://www.wikidata.org/wiki/Q80041" "city in counties of Yavapai and Coconino,
 ...
```

Note I am using **uv**, otherwise use: **hy -i brave.hy **
