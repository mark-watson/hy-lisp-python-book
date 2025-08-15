# Using the Brave Search APIs

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
