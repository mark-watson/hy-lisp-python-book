;; NSK: a neural-symbolic knowledge graph engine.
;;
;;   (import nsk [Graph use-graph])
;;   (require nsk [ask rule])

(import nsk.terms [Var Neural show unify resolve to-keyword to-term to-pattern])
(import nsk.store [Graph current-graph use-graph])
(import nsk.query [QueryResult run-query prove saturate])
(import nsk.neural [config infer ingest text-to-triples])
(require nsk.query [ask rule])

(setv __version__ "1.0.0")
