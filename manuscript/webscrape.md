# Responsible Web Scraping

I put the word "Responsible" in the chapter title to remind you that just because it is easy (as we will soon see) to pull data from web sites, it is important to respect the property rights of web site owners and abide by their terms and conditions for use. This [Wikipedia article on Fair Use](https://en.wikipedia.org/wiki/Fair_use) provides a good overview of using copyright material.

The web scraping code we develop here uses the Python BeautifulSoup and URI libraries.

For my work and research, I have been most interested in using web scraping to collect text data for natural language processing but other common applications include writing AI news collection and summarization assistants, trying to predict stock prices based on comments in social media which is what we did at Webmind Corporation in 2000 and 2001, etc.

## Using the Python BeautifulSoup Library in the Hy Language

There are many good libraries for parsing HTML text and extracting both structure (headings, what is in bold font, etc.) and embedded raw text. I particularly like the Python Beautiful Soup library and we will use it here.

In line 4 for the following listing of file **get_web_page.hy**, I am setting the default user agent to a descriptive string "HyLangBook" but for some web sites you might need to set this to appear as a Firefox or Chrome browser (iOS, Android, Windows, Linux, or macOS). The function **get-raw-data** gets the entire contents of a web site as a single string value.

{lang="hylang",linenos=on}
~~~~~~~~
(import urllib.request [Request urlopen])

(defn get-raw-data-from-web [aUri [anAgent {"User-Agent" "HyLangBook/1.0"}]]
  (setv req (Request aUri :headers anAgent))
  (setv httpResponse (urlopen req))
  (setv data (.read httpResponse))
  data)
~~~~~~~~

Let's test this function in a REPL:

{lang="hylang",linenos=on}
~~~~~~~~
$ hy
=> (import get-page-data [get-raw-data-from-web])
=> (get-raw-data-from-web "http://knowledgebooks.com")
b'<!DOCTYPE html><html><head><title>KnowledgeBooks.com - research on the Knowledge Management, and the Semantic Web ...'
=> 
=> (import get-page-data [get-page-html-elements])
=> (get-page-html-elements "http://knowledgebooks.com")
{'title': [<title>KnowledgeBooks.com - research on the Knowledge Management, and the Semantic Web </title>],
'a': [<a class="brand" href="#">KnowledgeBooks.com  </a>,  ...
=> 
~~~~~~~~

This REPL session shows the the function **get-raw-data-from-web** defined in the previous listing returns a web page as a string. In line 9 we use a function **get-page-html-elements** to find all elements in a string containing HTML. This function is defined in the next listing and shows how to parse and process the string contents of a web pages. Note: you will need to install the **lxml** library for this example (using pip or pip3 depending on your Python configuration):

    pip install lxml

The following listing of file **get_page_data.hy** uses the Beautiful Soup library to parse the string data for HTML text from a web site. The function **get-page-html-elements** returns names and associated data with each element in HTML represented as a string (the extra code on lines 20-24 is just debug example code):

{lang="hylang",linenos=on}
~~~~~~~~
(import get_web_page [get-raw-data-from-web])

(import bs4 [BeautifulSoup])

(defn get-element-data [anElement]
  {"text" (.getText anElement)
   "name" (. anElement name)
   "class" (.get anElement "class")
   "href" (.get anElement "href")})

(defn get-page-html-elements [aUri]
  (setv raw-data (get-raw-data-from-web aUri))
  (setv soup (BeautifulSoup raw-data "lxml"))
  (setv title (.find_all soup "title"))
  (setv a (.find_all soup "a"))
  (setv h1 (.find_all soup "h1"))
  (setv h2 (.find_all soup "h2"))
  {"title" title "a" a "h1" h1 "h2" h2})

(setv elements (get-page-html-elements "http://markwatson.com"))

(print (get elements "a"))

(for [ta (get elements "a")] (print (get-element-data ta)))
~~~~~~~~

The function **get-element-data** defined in lines 5-9 accepts as an argument an HTML element object (as defined in the Beautiful soup library) and extracts data, if available, for text, name, class, and href values. The function **get-page-html-elements** defied in lines 11-18 accepts as an argument a string containing a URI and returns a dictionary (or map, or hash table) containing lists of all **a**, **h1**, **h2**, and **title** elements in the web page pointed to by the input URI. You can modify **get-page-html-elements** to add additional HTML element types, as needed.

Here is the output (with many lines removed for brevity):

{linenos=on}
~~~~~~~~
{'text': 'Mark Watson artificial intelligence consultant and author',
 'name': 'a', 'class': ['navbar-brand'], 'href': '#'}
{'text': 'Home page', 'name': 'a', 'class': None, 'href': '/'}
{'text': 'My Blog', 'name': 'a', 'class': None,
 'href': 'https://mark-watson.blogspot.com'}
{'text': 'GitHub', 'name': 'a', 'class': None,
 'href': 'https://github.com/mark-watson'}
{'text': 'Twitter', 'name': 'a', 'class': None, 'href': 'https://twitter.com/mark_l_watson'}
{'text': 'WikiData', 'name': 'a', 'class': None, 'href': 'https://www.wikidata.org/wiki/Q18670263'}
~~~~~~~~

## Getting HTML Links from the DemocracyNow.org News Web Site

I financially support and rely on both NPR.org and DemocracyNow.org news as my main sources of news so I will use their news sites for examples here and in the next section. Web sites differ so much in format that it is often necessary to build highly customized web scrapers for individual web sites and to maintain the web scraping code as the format of the site changes in time.

Before working through this example and/or the example in the next section use the file **Makefile** to fetch data:

{linenos=off}
~~~~~~~~
make data
~~~~~~~~

This should copy the home pages for both web sites to the files:

- democracynow_home_page.html (used here)
- npr_home_page.html (used for the example in the next section)

The following listing shows **democracynow_front_page.hy**

{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import get-web-page [get-web-page-from-disk])
(import bs4 [BeautifulSoup])

;; you need to run 'make data' to fetch sample HTML data for dev and testing

(defn get-democracy-now-links []
  (setv test-html (get-web-page-from-disk "democracynow_home_page.html"))
  (setv bs (BeautifulSoup test-html :features "lxml"))
  (setv all-anchor-elements (.findAll bs "a"))
  (lfor e all-anchor-elements
          :if (> (len (.get-text e)) 0)
          (, (.get e "href") (.get-text e))))

(when (= __name__ "__main__")
  (for [[uri text] (get-democracy-now-links)]
    (print uri ":" text)))
~~~~~~~~

This simply prints our URIs and text (separated with the string ":") for each link on the home page. On line 13 we discard any anchor elements that do not contain text. On line 14 the comma character at the start of the return list indicates that we are constructing a tuple. Lines 16-18 define a main function that is used when running this file art the command line. This is similar to how main functions can be defined in Python to allow a library file to also be run as a command line tool.

A few lines of output from today's front page is:

{linenos=off}
~~~~~~~~
/2020/1/7/the_great_hack_cambridge_analytica : Meet Brittany Kaiser, Cambridge Analytica Whistleblower Releasing Troves of New Files from Data Firm
/2019/11/8/remembering_orangeburg_massacre_1968_south_carolina : Remembering the 1968 Orangeburg Massacre When Police Shot Dead Three Unarmed Black Students
/2020/1/15/democratic_debate_higher_education_universal_programs : Democrats Debate Wealth Tax, Free Public College & Student Debt Relief as Part of New Economic Plan
/2020/1/14/dahlia_lithwick_impeachment : GOP Debate on Impeachment Witnesses Intensifies as Pelosi Prepares to Send Articles to Senate
/2020/1/14/oakland_california_moms_4_housing : Moms 4 Housing: Meet the Oakland Mothers Facing Eviction After Two Months Occupying Vacant House
/2020/1/14/luis_garden_acosta_martin_espada : “Morir Soñando”: Martín Espada Reads Poem About Luis Garden Acosta, Young Lord & Community Activist
~~~~~~~~

The URIs are relative to the root URI https://www.democracynow.org/.



## Getting Summaries of Front Page from the NPR.org News Web Site

This example is similar to the example in the last section except that text from home page links is formatted to provide a daily news summary. I am assuming that you ran the example in the last section so the web site home pages have been copied to local files.

The following listing shows **npr_front_page_summary.hy**

{lang="hylang",linenos=on}
~~~~~~~~
#!/usr/bin/env hy

(import get-web-page [get-web-page-from-disk])
(import bs4 [BeautifulSoup])

;; you need to run 'make data' to fetch sample HTML data for dev and testing

(defn get-npr-links []
  (setv test-html (get-web-page-from-disk "npr_home_page.html"))
  (setv bs (BeautifulSoup test-html :features "lxml"))
  (setv all-anchor-elements (.findAll bs "a"))
  (setv filtered-a
    (lfor e all-anchor-elements
          :if (> (len (.get-text e)) 0)
          #((.get e "href") (.get-text e))))
  filtered-a)

(defn create-npr-summary []
  (setv links (get-npr-links))
  (setv filtered-links (lfor [uri text] links :if (> (len (.strip text)) 40) (.strip text)))
  (.join "\n\n" filtered-links))

(when (= __name__ "__main__")
  (print (create-npr-summary)))
~~~~~~~~

In lines 12-15 we are filtering out (or removing) all anchor HTML elements that do not contain text. The following shows a few lines of the generated output for data collected today:

{linenos=off}
~~~~~~~~
January 16, 2020  Birds change the shape of their wings far more than
planes. The complexities of bird flight have posed a major design challenge
for scientists trying to translate the way birds fly into robots.

FBI Vows To Warn More Election Officials If Discovering A Cyberattack

January 16, 2020  The bureau was faulted after the Russian attack on the
2016 election for keeping too much information from state and local
authorities. It says it'll use a new policy going forward.

Ukraine Is Investigating Whether U.S. Ambassador Yovanovitch Was Surveilled

January 16, 2020  Ukraine's Internal Affairs Ministry says it's asking the
FBI to help determine whether international laws were broken, or "whether it
is just a bravado and a fake information" from a U.S. politician.

Electric Burn: Those Who Bet Against Elon Musk And Tesla Are Paying A Big Price

January 16, 2020  For years, Elon Musk skeptics have shorted Tesla stock, confident the electric carmaker was on the brink of disaster. Instead, share value has skyrocketed, costing short sellers billions.

TSA Says It Seized A Record Number Of Firearms At U.S. Airports Last Year
~~~~~~~~

The examples seen here are simple but should be sufficient to get you started gathering text data from the web.