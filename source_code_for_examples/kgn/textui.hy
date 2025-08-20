(defn select-entities [people places organizations]
  (setv all-entities (+ people places organizations))
  (print "Please select entities from the list below:")
  (for [[i entity] (enumerate all-entities 1)]
    (print f"  {i}. {entity}"))
  (print "")

  (setv selected-entities [])
  (setv raw-input (input "Enter the numbers of the entities you want to process, separated by commas (e.g., 1, 3): "))

  (if raw-input
    (do
      (setv selected-indices (lfor x (.split raw-input ",") (- (int x) 1)))
      (print selected-entities)
      (for [idx selected-indices]
        (if (and (>= idx 0) (< idx (len all-entities)))
            (do
              (print idx)
              (print (get all-entities idx))
              (.append selected-entities (get all-entities idx)))
            [])))
    [])
  selected-entities)

(defn get-query []
  (input "Enter a list of entities: "))
