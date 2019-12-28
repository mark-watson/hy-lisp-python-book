# Responsible Web Scraping

I put the word "Responsible" in the chapter title to remind you that just because it is easy (as we will soon see) to pull data from web sites, it is important to respect the property rights of web site owners and abide by their terms and conditions for use. This [Wikipedia article on Fair Use](https://en.wikipedia.org/wiki/Fair_use) provides a good overview of using copyright material.

The web scraping code we develop here uses the Python BeautifulSoup Python library and URI libraries.

For my work and research, I have been most interested in using web scraping to collect text data for natural language processing but other applications include writing AI news collection and summarization assistants, trying to predict stock prices based on comments in social media (which is what we did at Webmind Corporation in 2000 and 2001), etc.

## Using the Python BeautifulSoup Library in the Hy Language

There are many good libraries for parsing HTML text and extracting both structure (headings, what is in bold font, etc.) and embedded raw text. I particularly like the Python Beautiful Soup library and we will use it here.

In line 4 for the following listing of file XXXX.hy, I am setting the default user agent to a descriptive string "HyLangBook" but you might for some web sites need to set this to appear as a Firefox or Chrome browser (iOS, Android, Windows, Linux, or macOS). The function **get-raw-data** gets the entire contents of a web site as a single string value.

{lang="hylang",linenos=on}
~~~~~~~~
(import [urllib.request [Request urlopen]])

(defn get-raw-data-from-web [aUri
                             &optional [anAgent {"User-Agent" "HyLangBook/1.0"}]]
  (setv req (Request aUri :headers anAgent))
  (setv httpResponse (urlopen req))
  (setv data (.read httpResponse))
  data)
~~~~~~~~

The following listing of file YYYY.hy uses the Beautiful Soup library to parse the string data for HTML text from a web site. The funtion **get-page-html-tags** TBD TBD also add repl examples TBD


{lang="hylang",linenos=on}
~~~~~~~~
(import argparse os)
(import [get_web_page [get-raw-data-from-web]])

(import [bs4 [BeautifulSoup]])

(defn get-tag-data [aTag]
  {"text" (.getText aTag)
   "name" (. aTag name)
   "class" (.get aTag "class")
   "href" (.get aTag "href")})

(defn get-page-html-tags [aUri]
  (setv raw-data (get-raw-data-from-web aUri))
  (setv soup (BeautifulSoup raw-data "lxml"))
  (setv title (.find_all soup "title"))
  (setv a (.find_all soup "a"))
  (setv h1 (.find_all soup "h1"))
  (setv h2 (.find_all soup "h2"))
  {"title" title "a" a "h1" h1 "h2" h2})

;; throw away code for book output:
(setv tags (get-page-html-tags "http://markwatson.com"))
;;(print (get tags "a"))
(for [ta (get tags "a")] (print (get-tag-data ta)))
~~~~~~~~

Here is the utput (with many lines removed for brevity):

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

## Getting Headlines and Summaries from the DemocracyNow.org News Web Site

I financially support and rely on DemocracyNow.org News as the main news that I usually watch so I will use their news site for this  example. Web sites differ so much in format that it is often necessary to build highly customized web scrapers for individual web sites and to maintain the web scraping code as the format of the site changes in time.

I have copied the HTML from a recent home page for DemocracyNow.org the file democracy_now_front_page.html in the example repo hy-lisp-python/webscraping and we will use this fetched file for experimenting with the current example.

TBD

The function get_headline_stories returns a list of tuples, each tuple containing:

TBD: fix the following list

- URI of a news story
- Title of news story
- Plain text from story

Here is an edited for brevity example:

TBD: replace the following list

~~~~~~~~
('https://www.npr.org/2019/05/01/716760556/watch-live-attorney-general',
 "Barr, After Acrimonious Day In Congress, Says He'll Skip Another One On Thursday",
 'Attorney General William Barr testifies before the Senate Judiciary Committee on Wednesday about the special counsel report on Russian interference in the 2016 election ... ')
~~~~~~~~

TBD
