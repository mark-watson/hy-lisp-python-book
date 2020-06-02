# Using the Microsoft Bing Search APIs

You will need to register with Microsoft's Azure search service to use the material in this book. It is likely that you view search as a manual human-centered activity. I hope to expand your thinking to considering applications that automate search, finding information on the web, and automatically organize information.

## Getting an Access Key for Microsoft Bing Search APIs

TBD

## Example Search Script

{lang="hylang",linenos=off}
~~~~~~~~
#!/usr/bin/env hy

(import json)
(import os)
(import sys)
(import [pprint [pprint]])
(import requests)

;; Add your Bing Search V7 subscription key and endpoint to your environment variables.
(setv subscription_key (get os.environ "BING_SEARCH_V7_SUBSCRIPTION_KEY"))

;; Query term(s) to search for. 
(setv query (get sys.argv 1)) ;;  "site:wikidata.org Sedona Arizona"

(setv endpoint "https://api.cognitive.microsoft.com/bing/v7.0/search")

;; Construct a request
(setv mkt "en-US")
(setv params { "q" query "mkt" mkt })
(setv headers { "Ocp-Apim-Subscription-Key" subscription_key })

;; Call the API
(setv response (requests.get endpoint :headers headers :params params))

(print "\nFull JSON response from Bing search query:\n")
(pprint (response.json))

;; pull out resuts and print them individually:

(setv results (get (response.json) "webPages"))

(print "\nResults from the key 'webPages':\n")
(pprint results)

(print "\nDetailed printout from the first search result:\n")

(setv result-list (get results "value"))
(setv first-result (first result-list))

(print "\nFirst result, all data:\n")
(pprint first-result)

(print "\nSummary of first search result:\n")
(pprint (get first-result "displayUrl"))

(if (in "displayUrl" first-result)
    (print (.format " key: {:15} \t:\t {}" "displayUrl" (get first-result "displayUrl"))))
(if (in "language" first-result)
    (print (.format " key: {:15} \t:\t {}" "language" (get first-result "language"))))
(if (in "name" first-result)
    (print (.format " key: {:15} \t:\t {}" "name" (get first-result "name"))))
~~~~~~~~

You can use search hints like "site:wikidata.org" to only search specific web sites. The following example generates 364 lines of output so I only show a few selected lines here:

{lang="hylang",linenos=off}
~~~~~~~~
$ ./bing.hy "site:wikidata.org Sedona Arizona" | wc -l
     364
$ ./bing.hy "site:wikidata.org Sedona Arizona"

Full JSON response from Bing search query:

{'_type': 'SearchResponse',
 'queryContext': {'originalQuery': 'site:wikidata.org Sedona Arizona'},
 
   ...

Results from the key 'webPages':

{'totalEstimatedMatches': 27,
 'value': [{'about': [{'name': 'Sedona'}, {'name': 'Sedona'}],
            'dateLastCrawled': '2020-05-24T00:04:00.0000000Z',
            'displayUrl': 'https://www.wikidata.org/wiki/Q80041',
    ...

Summary of first search result:

'https://www.wikidata.org/wiki/Q80041'
 key: displayUrl      	:	 https://www.wikidata.org/wiki/Q80041
 key: language        	:	 en
 key: name            	:	 Sedona - Wikidata
~~~~~~~~

