(defpackage #:edward.tests
  (:use #:cl)
  (:local-nicknames (#:dwg #:clautolisp.drawing))
  ;; Import fiveam selectively (not :use) — fiveam exports its own
  ;; RUN-ALL-TESTS, which would collide with ours under :use.
  (:import-from #:fiveam
                #:def-suite #:in-suite #:test #:is #:run #:explain! #:results-status)
  (:export #:run-all-tests #:edward-suite))
