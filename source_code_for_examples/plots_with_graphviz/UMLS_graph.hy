#!/usr/bin/env hy
;; UMLS RDF Triple Graph Visualizer
;;
;; Renders a directed graph from tab-separated triple files (subject, object, predicate).
;;
;; Usage:
;;   hy UMLS_graph.hy [OPTIONS] [input_file]
;;
;; Options:
;;   -o, --output NAME    Output file name (default: umls_graph)
;;   -v, --view           Auto-open the generated PDF
;;   -f, --filter PRED    Filter by predicate type (e.g., interacts_with)
;;   -l, --limit N        Limit to first N triples
;;   -e, --engine ENGINE  Layout engine: dot, neato, fdp, circo (default: dot)
;;
;; Examples:
;;   hy UMLS_graph.hy test.triples
;;   hy UMLS_graph.hy -v -l 50 test.triples
;;   hy UMLS_graph.hy --filter isa --engine neato test.triples -o isa_graph

(import sys
        argparse
        graphviz [Digraph])

;; Color palette for predicates (maps predicate types to colors)
(setv PREDICATE-COLORS
  {"isa" "#FF6B6B"              ; red for hierarchy
   "interacts_with" "#4ECDC4"   ; teal for interactions
   "affects" "#45B7D1"          ; blue
   "causes" "#96CEB4"           ; green
   "part_of" "#FFEAA7"          ; yellow
   "location_of" "#DDA0DD"      ; purple
   "treats" "#98D8C8"           ; mint
   "result_of" "#F7DC6F"        ; gold
   "process_of" "#BB8FCE"       ; lavender
   "produces" "#85C1E9"         ; light blue
   "disrupts" "#E74C3C"         ; dark red
   "complicates" "#F39C12"      ; orange
   "manifestation_of" "#1ABC9C" ; turquoise
   "degree_of" "#95A5A6"        ; gray
   "adjacent_to" "#E67E22"})    ; dark orange

(defn get-predicate-color [predicate]
  "Return color for predicate, or default gray if not mapped"
  (.get PREDICATE-COLORS predicate "#CCCCCC"))

(defn parse-triples [filepath limit filter-pred]
  "Parse triple file, return filtered list of (subject object predicate) tuples"
  (with [f (open filepath "r")]
    (setv triples (lfor line (.readlines f)
                        :setv tokens (.split (.strip line))
                        :if (= (len tokens) 3)
                        :setv [subj obj pred] tokens
                        :if (or (not filter-pred) (= pred filter-pred))
                        (tuple [subj obj pred])))
    ;; Apply limit if specified
    (if limit
      (cut triples 0 limit)
      triples)))

(defn build-graph [triples engine]
  "Build graphviz Digraph from list of triples with color-coded edges"
  (setv g (Digraph :comment "UMLS Knowledge Graph"
                   :format "pdf"
                   :engine engine))
  
  ;; Graph-level attributes for better layout (using keyword args)
  (.attr g :rankdir "LR" :splines "true" :overlap "false"
           :fontsize "10" :fontname "Helvetica")
  (.attr g "node" :shape "box" :style "rounded,filled" :fillcolor "#E8F4FD"
           :fontsize "10" :fontname "Helvetica")
  (.attr g "edge" :fontsize "8" :fontcolor "gray40" :fontname "Helvetica"
           :arrowsize "0.7")
  
  ;; Collect unique nodes to avoid duplicate .node() calls
  (setv nodes (set))
  (for [[subj obj pred] triples]
    (.add nodes subj)
    (.add nodes obj)
    ;; Color-code edges by predicate
    (.edge g subj obj :label pred :color (get-predicate-color pred)))
  
  ;; Add all nodes once
  (for [n nodes]
    (.node g n))
  
  ;; Add legend for predicate colors
  (build-legend g)
  
  g)

(defn build-legend [g]
  "Add a legend cluster showing predicate color mappings"
  (with [legend (.subgraph g :name "cluster_legend")]
    (.attr legend :label "Legend" :fontsize "9" :style "filled" :fillcolor "white")
    (for [[pred color] (.items PREDICATE-COLORS)]
      (.node legend (+ "legend_" pred) :label pred :shape "box"
                                        :style "filled" :fillcolor color
                                        :fontsize "8"))))

(defn parse-args []
  "Parse command line arguments"
  (setv parser (argparse.ArgumentParser
                 :description "Visualize UMLS RDF triples as a knowledge graph"
                 :formatter_class argparse.RawDescriptionHelpFormatter))
  
  (.add-argument parser "input_file" :nargs "?" :default "test.triples"
                 :help "Input triples file (default: test.triples)")
  (.add-argument parser "-o" "--output" :default "umls_graph"
                 :help "Output file name without extension (default: umls_graph)")
  (.add-argument parser "-v" "--view" :action "store_true"
                 :help "Open the generated PDF after rendering")
  (.add-argument parser "-f" "--filter" :metavar "PREDICATE"
                 :help "Filter triples by predicate type")
  (.add-argument parser "-l" "--limit" :type int :metavar "N"
                 :help "Limit to first N triples")
  (.add-argument parser "-e" "--engine" :choices ["dot" "neato" "fdp" "circo"]
                 :default "dot"
                 :help "Layout engine (default: dot)")
  
  (.parse_args parser))

(defn main []
  (setv args (parse-args))
  
  (print f"Reading triples from {args.input_file}...")
  
  (try
    (setv triples (parse-triples args.input_file args.limit args.filter))
    (except [e FileNotFoundError]
      (print f"Error: File '{args.input_file}' not found")
      (sys.exit 1))
    (except [e Exception]
      (print f"Error parsing file: {e}")
      (sys.exit 1)))
  
  (when (= (len triples) 0)
    (if args.filter
      (print f"Error: No triples found matching predicate '{args.filter}'")
      (print "Error: No triples found"))
    (sys.exit 1))
  
  ;; Count unique nodes
  (setv subjects (lfor [s o _] triples s))
  (setv objects (lfor [s o _] triples o))
  (setv unique-nodes (.union (set subjects) (set objects)))
  
  (print f"Parsed {(len triples)} triples with {(len unique-nodes)} unique nodes")
  (when args.filter
    (print f"Filtered by predicate: {args.filter}"))
  (when args.limit
    (print f"Limited to first {args.limit} triples"))
  
  (print f"Building graph using {args.engine} layout engine...")
  (setv graph (build-graph triples args.engine))
  
  (print f"Rendering to {args.output}.pdf...")
  (.render graph args.output :view args.view)
  
  (print f"Done! Output: {args.output}.pdf")
  (when args.view
    (print "PDF opened for viewing.")))

(when (= __name__ "__main__")
  (main))