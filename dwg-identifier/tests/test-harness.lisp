(in-package #:dwg-identifier.tests)

(def-suite dwg-identifier-suite
  :description "Tests for the dwg-identifier classifier.")

(in-suite dwg-identifier-suite)

(defun run-all-tests ()
  (let ((result (run 'dwg-identifier-suite)))
    (fiveam:explain! result)
    (unless (fiveam:results-status result)
      (error "dwg-identifier tests failed."))
    result))
