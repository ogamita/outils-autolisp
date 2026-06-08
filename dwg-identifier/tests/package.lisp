(defpackage #:dwg-identifier.tests
  (:use #:cl)
  (:local-nicknames (#:dwg #:clautolisp.drawing)
                    (#:id #:dwg-identifier))
  (:import-from #:fiveam
                #:def-suite #:in-suite #:test #:is #:run #:explain! #:results-status))
