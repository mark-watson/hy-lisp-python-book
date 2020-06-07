# Using the Microsoft Bing Search APIs

You will need to register with Microsoft's Azure search service to use the material in this chapter. It is likely that you view search as a manual human-centered activity. I hope to expand your thinking to considering applications that automate search, finding information on the web, and automatically organizing information.

## Getting an Access Key for Microsoft Bing Search APIs

You will need an Azure account. I use the Bing search APIs fairly often for research but I have never spent more than about a dollar a month and usually I get no bill at all. For personal use it is an inexpensive service.

Get started by going to the web page [https://azure.microsoft.com/en-us/try/cognitive-services/](https://azure.microsoft.com/en-us/try/cognitive-services/) and sign up for an access key. The Search APIs signup is currently in the fourth tab in this web form. When you navigate to the Search APIs tab, select the option Bing Search APIs v7. You will get an API key that you need to store in an environment variable that you will soon need:

{lang="bash",linenos=off}
~~~~~~~~
export BING_SEARCH_V7_SUBSCRIPTION_KEY=4e97234341d9891191c772b7371ad5b1
~~~~~~~~

That is not my real subscription key!

After adding this to your **.profile** file (or **.zshrc**, or **.bashrc**, or etc.), open a new terminal window and make sure the following works for you:

{lang="hylang",linenos=off}
~~~~~~~~
$ hy
hy 0.18.0 using CPython(default) 3.7.4 on Darwin
=> (import os)
=> (get os.environ "BING_SEARCH_V7_SUBSCRIPTION_KEY")
'4e97234341d9891191c772b7371ad5b1'
=> 
~~~~~~~~


## Example Search Script

It takes very little Hy code to access the Bing search APIs. we will look at a long example script that expects a single command line argument that is a string containing search terms. The following example script shows you how to make a search query that requests search results in JSON format. We also look at parsing the returned JSON data. I formatted this listing to fit the page width:

{lang="hylang",linenos=off}
~~~~~~~~
#!/usr/bin/env hy

(import json)
(import os)
(import sys)
(import [pprint [pprint]])
(import requests)

;; Add your Bing Search V7 subscription key and 
;; the endpoint to your environment variables.
(setv subscription_key (get os.environ "BING_SEARCH_V7_SUBSCRIPTION_KEY"))
(setv endpoint "https://api.cognitive.microsoft.com/bing/v7.0/search")

;; Query term(s) to search for. 
(setv query (get sys.argv 1)) ;; an example: "site:wikidata.org Sedona Arizona"

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
    (print
     (.format
       " key: {:15} \t:\t {}" "displayUrl"
       (get first-result "displayUrl"))))
(if (in "language" first-result)
    (print
      (.format " key: {:15} \t:\t {}" "language" 
      (get first-result "language"))))
(if (in "name" first-result)
    (print 
      (.format 
        " key: {:15} \t:\t {}" "name" 
        (get first-result "name"))))
~~~~~~~~

You can use search hints like "site:wikidata.org" to only search specific web sites. In the following example I use the search query:

    "site:wikidata.org Sedona Arizona"
  
This example generates 364 lines of output so I only show a few selected lines here:

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

## Wrap-up

In addition to using automated web scraping to get data for my personal research, I often use automated web search. I find the Microsoft's Azure Bing search APIs are the most convenient to use and I like paying for services that I use. The search engine Duck Duck Go also provides free search APIs but even though I use Duck Duck Go for 90% of my manual web searches, when I build automated systems I prefer to rely on services that I pay for.