# Linked Data and the Semantic Web

Tim Berners Lee, XX, and YY wrote an article for Scientific Amercican where the introduced the term Semantic Web. Here I do not capitalize semantic web and use the similar term linked data somewhat interchangably with semantic web.

TBD: describe differences between sw and ld....

While the "web" describes information for human readers, the semantic web is meant to provide structured data for ingestion by software agents. This distinction will be clear as we compare WikiPedia, made for human readers, with DBPedia which uses the info boxes on WikiPedia topics to automatically extract RDF data describing WikiPedia topics. Lets look at the WikiPedia topic for the town I live in Sedona Arizona and show how the info box on the English version of the [WikiPedia topic page for Sedona https://en.wikipedia.org/wiki/Sedona,_Arizona](https://en.wikipedia.org/wiki/Sedona,_Arizona) maps to the [DBPedia page http://dbpedia.org/page/Sedona,_Arizona](http://dbpedia.org/page/Sedona,_Arizona). Please open both of these WikiPedia and DBPedia URIs in two browser tabs and keep them open for reference.

I assume that the format of the WikiPedia page is familiar so let's look at the DBPdeia page for Sedona that in human readble form shows the RDF statements with Sedona Arizona as the subject. RDF is used to model and represent data. RDF is defined by three values so an instance of an RDF statement is called a *triple* with three parts:

- subject: a URI
- property: a URI
- value: a URI or a literal value (like a string)

The subject for each Sedona related triple is the above URI for the DBPedia human readable page. The subject and property references in an RDF triple will almost always be a URI that can both ground an entity to information on the web. The human readable page for Sedona lists several properies and the values of these properties. One of the properties is "dbo:areaCode" where "dbo" is a name space reference (in this case for a [DatatypeProperty](http://www.w3.org/2002/07/owl#DatatypeProperty).

We will be diving a little deeper into RDF examples but for now I want you to understand the idea of RDF statements represented as triples, that web URIs represent things, properties, and sometimes values, and that URIs can be followed manually to see what they reference.

## Understanding the Resource Description Framework (RDF)


## Resource Namespaces Provided in rdflib

The following standard namespaces are predefined in **rdflib**:

- RDF       [https://www.w3.org/TR/rdf-syntax-grammar/](https://www.w3.org/TR/rdf-syntax-grammar/)
- RDFS      [https://www.w3.org/TR/rdf-schema/](https://www.w3.org/TR/rdf-schema/)
- OWL       [http://www.w3.org/2002/07/owl#](http://www.w3.org/2002/07/owl#)
- XSD       [http://www.w3.org/2001/XMLSchema#](http://www.w3.org/2001/XMLSchema#)
- FOAF      [http://xmlns.com/foaf/0.1/](http://xmlns.com/foaf/0.1/)
- SKOS      [http://www.w3.org/2004/02/skos/core#](http://www.w3.org/2004/02/skos/core#)
- DOAP      [http://usefulinc.com/ns/doap#](http://usefulinc.com/ns/doap#)
- DC        [http://purl.org/dc/elements/1.1/](http://purl.org/dc/elements/1.1/)
- DCTERMS   [http://purl.org/dc/terms/](http://purl.org/dc/terms/)
- VOID      [http://rdfs.org/ns/void#](http://rdfs.org/ns/void#)

Let's look into the Friend of a Friend (FOAF) namespace. Click on the above link for FOAF [http://xmlns.com/foaf/0.1/](http://xmlns.com/foaf/0.1/) and find the definitions for:


FOAF Core

        Agent
        Person
        name
        title
        img
        depiction (depicts)
        familyName
        givenName
        knows
        based_near
        age
        made (maker)
        primaryTopic (primaryTopicOf)
        Project
        Organization
        Group
        member
        Document
        Image

and:


Social Web

    nick
    mbox
    homepage
    weblog
    openid
    jabberID
    mbox_sha1sum
    interest
    topic_interest
    topic (page)
    workplaceHomepage
    workInfoHomepage
    schoolHomepage
    publications
    currentProject
    pastProject
    account
    OnlineAccount
    accountName
    accountServiceHomepage
    PersonalProfileDocument
    tipjar
    sha1
    thumbnail
    logo

{lang="hylang",linenos=on}
~~~~~~~~
Marks-MacBook:database $ hy
hy 0.17.0+108.g919a77e using CPython(default) 3.7.3 on Darwin
=> (import [rdflib.namespace [FOAF]])
=> FOAF
Namespace('http://xmlns.com/foaf/0.1/')
=> FOAF.name
rdflib.term.URIRef('http://xmlns.com/foaf/0.1/name')
=> FOAF.title
rdflib.term.URIRef('http://xmlns.com/foaf/0.1/title')
=> (import rdflib)
=> (setv graph (rdflib.Graph))
=> (setv mark (rdflib.BNode))
=> (graph.bind "foaf" FOAF)
=> (import [rdflib [RDF]])
=> (graph.add [mark RDF.type FOAF.Person])
=> (graph.add [mark FOAF.nick (rdflib.Literal "Mark" :lang "en")])
=> (graph.add [mark FOAF.name (rdflib.Literal "Mark Watson" :lang "en")])
=> (for [node graph] (print node))
(rdflib.term.BNode('N21c7fa7385b545eb8a7e3821b75b9cb5'), rdflib.term.URIRef('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'), rdflib.term.URIRef('http://xmlns.com/foaf/0.1/Person'))
(rdflib.term.BNode('N21c7fa7385b545eb8a7e3821b75b9cb5'), rdflib.term.URIRef('http://xmlns.com/foaf/0.1/name'), rdflib.term.Literal('Mark Watson', lang='en'))
(rdflib.term.BNode('N21c7fa7385b545eb8a7e3821b75b9cb5'), rdflib.term.URIRef('http://xmlns.com/foaf/0.1/nick'), rdflib.term.Literal('Mark', lang='en'))
=> (graph.serialize :format "pretty-xml")
b'<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF
    xmlns:foaf="http://xmlns.com/foaf/0.1/"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
>
  <foaf:Person rdf:nodeID="N21c7fa7385b545eb8a7e3821b75b9cb5">
    <foaf:name xml:lang="en">Mark Watson</foaf:name>
    <foaf:nick xml:lang="en">Mark</foaf:nick>
  </foaf:Person>
</rdf:RDF>\n'
=> (graph.serialize :format "turtle")
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xml: <http://www.w3.org/XML/1998/namespace> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

[] a foaf:Person ;
     foaf:name "Mark Watson"@en ;
     foaf:nick "Mark"@en .

=> (graph.serialize :format "nt")
_:N21c7fa7385b545eb8a7e3821b75b9cb5
   <http://www.w3.org/1999/02/22-rdf-syntax-ns#type>
   <http://xmlns.com/foaf/0.1/Person> .
_:N21c7fa7385b545eb8a7e3821b75b9cb5 <http://xmlns.com/foaf/0.1/name> "Mark Watson"@en .
_:N21c7fa7385b545eb8a7e3821b75b9cb5 <http://xmlns.com/foaf/0.1/nick> "Mark"@en .
=> 
~~~~~~~~


## Understanding the SPARQL Query Language

TBD

## Wrapping the Python **rdflib** Library

TBD


You can install using the [source code for **rdflib**](https://github.com/RDFLib/rdflib) or using:

{lang="bash",linenos=off}
~~~~~~~~
pip install rdflib
~~~~~~~~

## Wrapping the Python **sparqlwrapper** Library

TBD

You can install using the [source code for **sparqlwrapper**](https://github.com/RDFLib/sparqlwrapper) or using:

{lang="bash",linenos=off}
~~~~~~~~
pip install sparqlwrapper
~~~~~~~~

## RDF Data Storage and SPARQL Query Examples

TBD
