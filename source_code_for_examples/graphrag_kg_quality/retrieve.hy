(import dataclasses [dataclass])
(import math)
(import re)
(import rdflib [OWL RDF RDFS URIRef])
(import kg [EX PROV provenance-for-triple])

(setv STOPWORDS
  #{"the" "a" "an" "what" "which" "who" "how" "does" "do" "is" "are" "was" "were"
    "in" "of" "to" "for" "and" "or" "by" "with" "when" "from" "that" "on" "as" "it"})

(defclass [(dataclass :frozen True)] ScoredTriple []
  "A retrieved graph triple with provenance chunk IDs and confidence."
  #^ str subject
  #^ str predicate
  #^ str object-val
  #^ list chunk-ids
  #^ float confidence
  #^ int hop)

(defclass [(dataclass :frozen True)] CommunitySummary []
  "A thematic subgraph community for global GraphRAG search."
  #^ str community-id
  #^ str title
  #^ list entities
  #^ list triples
  #^ list chunk-ids
  #^ str summary-text)

(defclass [(dataclass :frozen True)] RetrievalContext []
  "Context assembled under a token budget from chunks and/or graph triples."
  #^ str mode
  #^ list seed-entities
  #^ list triples
  #^ list chunks
  #^ list communities
  #^ int tokens-used
  #^ int token-budget)

(defn tokenize [text]
  "Split camelCase, underscores, and hyphens into lowercase root tokens."
  (setv spaced (re.sub r"([a-z0-9])([A-Z])" r"\1 \2" text)
        spaced (re.sub r"[_\-.:]+" " " spaced)
        raw (re.findall r"[a-z0-9]+" (.lower spaced))
        out [])
  (for [t raw]
    (when (and (> (len t) 1) (not (in t STOPWORDS)))
      (.append out t)
      (when (and (> (len t) 4) (.endswith t "s"))
        (.append out (cut t 0 -1)))))
  out)

(defn estimate-tokens [text]
  "Approximate token count as whitespace-delimited words."
  (len (.split text)))

(defn local-slug [uri]
  "Strip the EX namespace prefix from an rdflib URIRef."
  (setv s (str uri)
        prefix (str EX))
  (if (.startswith s prefix)
      (cut s (len prefix) None)
      s))

(defclass KeywordRetriever []
  "IDF-weighted bag-of-words cosine retriever (vector-only / chunk-only baseline)."
  (defn __init__ [self chunks]
    (setv self.chunks chunks
          self.chunk-map (dfor ch chunks ch.chunk-id ch)
          self.doc-freqs {}
          self.chunk-tokens {})
    (for [ch chunks]
      (setv toks (tokenize ch.text))
      (setv (get self.chunk-tokens ch.chunk-id) toks)
      (for [u (set toks)]
        (setv (get self.doc-freqs u) (+ (.get self.doc-freqs u 0) 1))))
    (setv n (max 1 (len chunks)))
    (setv self.idf
      (dfor #(term df) (.items self.doc-freqs)
            term (+ 1.0 (math.log (/ (+ n 1.0) (+ df 1.0)))))))

  (defn tfidf-vector [self tokens]
    (setv tf {})
    (for [t tokens]
      (setv (get tf t) (+ (.get tf t 0) 1.0)))
    (dfor #(t count) (.items tf)
          t (* count (.get self.idf t 1.0))))

  (defn cosine-sim [self vec-a vec-b]
    (when (or (not vec-a) (not vec-b))
      (return 0.0))
    (setv dot 0.0)
    (for [#(k va) (.items vec-a)]
      (when (in k vec-b)
        (setv dot (+ dot (* va (get vec-b k))))))
    (setv norm-a (math.sqrt (sum (gfor v (.values vec-a) (* v v))))
          norm-b (math.sqrt (sum (gfor v (.values vec-b) (* v v)))))
    (if (or (= norm-a 0.0) (= norm-b 0.0))
        0.0
        (/ dot (* norm-a norm-b))))

  (defn score-chunks [self query]
    (setv q-vec (.tfidf-vector self (tokenize query))
          scored [])
    (for [ch self.chunks]
      (setv c-vec (.tfidf-vector self (get self.chunk-tokens ch.chunk-id))
            sim (.cosine-sim self q-vec c-vec))
      (.append scored #(sim ch)))
    (sorted scored :key (fn [pair] #((- (get pair 0)) (. (get pair 1) chunk-id)))))

  (defn retrieve [self query [top-k 2] [token-budget 110]]
    "Return top-k keyword-matched chunks within token-budget (no graph expansion)."
    (setv ranked (.score-chunks self query)
          selected []
          used 0)
    (for [#(sim ch) ranked]
      (when (and (< (len selected) top-k) (> sim 0.0))
        (setv cost (estimate-tokens ch.text))
        (when (<= (+ used cost) token-budget)
          (.append selected ch)
          (setv used (+ used cost)))))
    (RetrievalContext :mode "baseline_keyword"
                      :seed-entities []
                      :triples []
                      :chunks selected
                      :communities []
                      :tokens-used used
                      :token-budget token-budget)))

(setv IGNORED_PREDICATES
  #{RDF.type RDF.subject RDF.predicate RDF.object
    RDFS.label RDFS.subClassOf RDFS.subPropertyOf RDFS.domain RDFS.range
    OWL.sameAs PROV.wasDerivedFrom EX.confidence EX.fromDocument EX.chunkId EX.docId})

(defn lookup-provenance-with-subproperties [g s-slug p-slug o-slug]
  "Find provenance for (s, p, o) directly or through subPropertyOf assertions."
  (setv direct (provenance-for-triple g s-slug p-slug o-slug))
  (when direct
    (return #(direct False)))
  (setv q "
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
    SELECT ?subp WHERE {
      ?subp rdfs:subPropertyOf+ ?p .
      ?s ?subp ?o .
    }
  "
        rows (.query g q :initBindings {"s" (get EX s-slug)
                                        "p" (get EX p-slug)
                                        "o" (get EX o-slug)}))
  (for [r rows]
    (setv sub-slug (local-slug r.subp)
          sub-prov (provenance-for-triple g s-slug sub-slug o-slug))
    (when sub-prov
      (return #(sub-prov True))))
  #([] True))

(defclass GraphRetriever []
  "Hybrid GraphRAG retriever combining 1-2 hop RDF neighborhood expansion with chunk scoring."
  (defn __init__ [self g chunks]
    (setv self.g g
          self.chunks chunks
          self.chunk-map (dfor ch chunks ch.chunk-id ch)
          self.keyword (KeywordRetriever chunks)))

  (defn link-entities [self query]
    "Match query text against entity labels, owl:sameAs aliases, and ontology classes."
    (setv q-low (.lower query)
          q-norm (.replace (.replace q-low "." "") "-" "")
          seeds (set))
    (for [#(s _ lbl) (.triples self.g #(None RDFS.label None))]
      (setv slug (local-slug s)
            l-str (.lower (str lbl))
            l-norm (.replace (.replace l-str "." "") "-" ""))
      (when (or (in l-str q-low) (in l-norm q-norm) (in (.replace slug "_" " ") q-low))
        (.add seeds slug)))
    ;; Resolve owl:sameAs aliases to their canonical targets
    (for [#(alias _ canon) (.triples self.g #(None OWL.sameAs None))]
      (setv a-slug (local-slug alias)
            c-slug (local-slug canon))
      (when (or (in a-slug seeds)
                (in (.replace a-slug "_" " ") q-low))
        (.add seeds c-slug)))
    ;; Support class-level questions such as "AI software projects"
    (when (or (in "ai software" q-low) (in "software project" q-low))
      (for [#(inst _ _) (.triples self.g #(None RDF.type EX.AISoftware))]
        (.add seeds (local-slug inst))))
    (sorted seeds))

  (defn expand-neighborhood [self seed-slugs [max-hops 2]]
    "Traverse 1-to-2 hop domain triples around seed entities and attach provenance."
    (setv frontier (set seed-slugs)
          visited (set seed-slugs)
          collected {}
          hop 1)
    (while (and (<= hop max-hops) frontier)
      (setv next-frontier (set))
      (for [slug (sorted frontier)]
        (setv node (get EX slug))
        ;; Outgoing domain edges
        (for [#(s p o) (.triples self.g #(node None None))]
          (when (and (isinstance o URIRef) (not (in p IGNORED_PREDICATES)))
            (setv s-id (local-slug s)
                  p-id (local-slug p)
                  o-id (local-slug o)
                  key #(s-id p-id o-id))
            (when (not (in key collected))
              (setv #(prov inferred?) (lookup-provenance-with-subproperties self.g s-id p-id o-id)
                    c-ids (lfor item prov (get item "chunk_id"))
                    conf (if prov (max (gfor item prov (get item "confidence"))) 0.85))
              (setv (get collected key)
                    (ScoredTriple :subject s-id
                                  :predicate p-id
                                  :object-val o-id
                                  :chunk-ids c-ids
                                  :confidence conf
                                  :hop hop)))
            (when (not (in o-id visited))
              (.add next-frontier o-id))))
        ;; Incoming domain edges
        (for [#(s p o) (.triples self.g #(None None node))]
          (when (and (isinstance s URIRef) (not (in p IGNORED_PREDICATES)))
            (setv s-id (local-slug s)
                  p-id (local-slug p)
                  o-id (local-slug o)
                  key #(s-id p-id o-id))
            (when (not (in key collected))
              (setv #(prov inferred?) (lookup-provenance-with-subproperties self.g s-id p-id o-id)
                    c-ids (lfor item prov (get item "chunk_id"))
                    conf (if prov (max (gfor item prov (get item "confidence"))) 0.85))
              (setv (get collected key)
                    (ScoredTriple :subject s-id
                                  :predicate p-id
                                  :object-val o-id
                                  :chunk-ids c-ids
                                  :confidence conf
                                  :hop hop)))
            (when (not (in s-id visited))
              (.add next-frontier s-id)))))
      (.update visited next-frontier)
      (setv frontier next-frontier
            hop (+ hop 1)))
    (sorted (.values collected)
            :key (fn [st] #(st.hop (- st.confidence) st.subject st.predicate st.object-val))))

  (defn local-search [self query [max-hops 2] [top-k-chunks 4] [token-budget 180]]
    "Perform entity-seeded 1-2 hop graph expansion and hybrid provenance-chunk retrieval."
    (setv seeds (.link-entities self query)
          triples (.expand-neighborhood self seeds :max-hops max-hops)
          q-tokens (set (tokenize query))
          seed-tokens (set (gfor s seeds t (tokenize s) t))
          non-seed-q (- q-tokens seed-tokens)
          ;; Rank triples by non-seed query token overlap, total overlap, hop, and confidence
          ranked-triples
          (sorted triples
                  :key (fn [st]
                         (setv rel-text f"{st.subject} {st.predicate} {st.object-val}"
                               t-toks (set (tokenize rel-text))
                               ns-hit (len (& non-seed-q t-toks))
                               all-hit (len (& q-tokens t-toks)))
                         #((- ns-hit) (- all-hit) st.hop (- st.confidence) st.subject st.predicate)))
          ;; Assemble top triples within 35% of the token budget first
          kept-triples []
          used 0
          triple-budget (int (* token-budget 0.35)))
    (for [st ranked-triples]
      (setv t-cost 6)
      (when (<= (+ used t-cost) triple-budget)
        (.append kept-triples st)
        (setv used (+ used t-cost))))

    ;; Boost chunks referenced via prov:wasDerivedFrom by kept triples
    (setv chunk-boost {}
          kw-scores (dfor #(sim ch) (.score-chunks self.keyword query) ch.chunk-id sim))
    (for [st kept-triples]
      (setv weight (if (= st.hop 1) 0.45 0.35))
      (for [cid st.chunk-ids]
        (setv (get chunk-boost cid)
              (+ (.get chunk-boost cid 0.0) (* weight st.confidence)))))

    (setv combined-chunks [])
    (for [ch self.chunks]
      (setv total (+ (.get kw-scores ch.chunk-id 0.0)
                     (.get chunk-boost ch.chunk-id 0.0)))
      (when (> total 0.0)
        (.append combined-chunks #(total ch))))
    (setv combined-chunks
          (sorted combined-chunks :key (fn [pair] #((- (get pair 0)) (. (get pair 1) chunk-id)))))

    (setv kept-chunks [])
    (for [#(score ch) combined-chunks]
      (when (< (len kept-chunks) top-k-chunks)
        (setv c-cost (estimate-tokens ch.text))
        (when (<= (+ used c-cost) token-budget)
          (.append kept-chunks ch)
          (setv used (+ used c-cost)))))
    (RetrievalContext :mode "graphrag_local"
                      :seed-entities seeds
                      :triples kept-triples
                      :chunks kept-chunks
                      :communities []
                      :tokens-used used
                      :token-budget token-budget))

  (defn build-communities [self]
    "Partition the technical dependency graph into connected-component communities."
    (setv author-preds #{EX.createdBy EX.authoredBy EX.documentedBy EX.developedSuiteIn}
          adj {}
          domain-triples [])
    (for [#(s p o) self.g]
      (when (and (isinstance s URIRef)
                 (isinstance o URIRef)
                 (not (in p IGNORED_PREDICATES))
                 (not (in p author-preds)))
        (setv u (local-slug s)
              v (local-slug o)
              pred (local-slug p))
        (.setdefault adj u (set))
        (.setdefault adj v (set))
        (.add (get adj u) v)
        (.add (get adj v) u)
        (.append domain-triples #(u pred v))))
    (setv domain-triples (sorted (set domain-triples)))

    (setv visited (set)
          communities []
          idx 1)
    (for [start (sorted (.keys adj))]
      (when (not (in start visited))
        (setv comp (set)
              queue [start])
        (while queue
          (setv curr (.pop queue 0))
          (when (not (in curr visited))
            (.add visited curr)
            (.add comp curr)
            (for [nbr (sorted (.get adj curr (set)))]
              (when (not (in nbr visited))
                (.append queue nbr)))))
        (setv members (sorted comp)
              comm-triples (lfor #(u p v) domain-triples
                                 :if (and (in u comp) (in v comp))
                                 #(u p v))
              chunk-ids (set))
        (for [#(u p v) comm-triples]
          (for [item (provenance-for-triple self.g u p v)]
            (.add chunk-ids (get item "chunk_id"))))
        (setv cid f"community_{idx}"
              title (cond
                      (in "kg_rag" comp) "KG Quality & GraphRAG Validation"
                      (in "zvec_rag" comp) "Local Vector RAG Pipeline"
                      True "Symbolic & Neural-Symbolic Graph Systems")
              members-str (.join ", " members)
              triples-str (.join "; " (lfor #(u p v) (cut comm-triples 0 5) f"{u} {p} {v}"))
              summary f"[{cid}: {title}] Entities: {members-str}. Key relations: {triples-str}.")
        (.append communities
          (CommunitySummary :community-id cid
                            :title title
                            :entities members
                            :triples comm-triples
                            :chunk-ids (sorted chunk-ids)
                            :summary-text summary))
        (setv idx (+ idx 1))))
    communities)

  (defn global-search [self query [top-communities 2] [token-budget 180]]
    "Rank community summaries against a broad thematic query and assemble context."
    (setv communities (.build-communities self)
          q-vec (.tfidf-vector self.keyword (tokenize query))
          scored [])
    (for [comm communities]
      (setv c-vec (.tfidf-vector self.keyword (tokenize comm.summary-text))
            sim (.cosine-sim self.keyword q-vec c-vec))
      (.append scored #((+ sim 0.01) comm)))
    (setv ranked (sorted scored :key (fn [pair] #((- (get pair 0)) (. (get pair 1) community-id))))
          selected []
          used 0)
    (for [#(_ comm) (cut ranked 0 top-communities)]
      (setv cost (estimate-tokens comm.summary-text))
      (when (<= (+ used cost) token-budget)
        (.append selected comm)
        (setv used (+ used cost))))
    (RetrievalContext :mode "graphrag_global"
                      :seed-entities []
                      :triples []
                      :chunks []
                      :communities selected
                      :tokens-used used
                      :token-budget token-budget)))
