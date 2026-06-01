;;;; main.hy — Combined runner for all symbolic math smoke tests
;;;;

(import data)
(import differentiation)
(import integration)

(defn main []
  (print "=========================================================")
  (print "=== RUNNING ALL SYMBOLIC MATH SMOKE TESTS IN HY ===")
  (print "=========================================================")
  (data.run-smoke-test)
  (differentiation.run-smoke-test)
  (integration.run-smoke-test))

(when (= __name__ "__main__")
  (main))
