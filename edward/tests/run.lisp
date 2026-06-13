(in-package #:edward.tests)

(defun run-all-tests ()
  "Run the edward test suite. Signals an error if any test fails (so
`make test' / asdf:test-system exits non-zero on failure)."
  (let ((result (run 'edward-suite)))
    (explain! result)
    (unless (results-status result)
      (error "edward: test failures"))
    t))
