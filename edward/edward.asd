;;;; edward — read, dump (JSON) and transfer the application data that the
;;;; SNCF EPURE applications (SCHMS/SCHME/SCHMIEUX/PV) store inside DWG/DXF
;;;; drawings.
;;;;
;;;; A Common-Lisp subproject of outils-autolisp, built — like its sibling
;;;; dwg-identifier — on the clautolisp drawing library: clautolisp reads the
;;;; drawing (DXF natively, DWG via clautolisp/drawing-dwg + libredwg) into a
;;;; backend-independent value; edward extracts/decodes the stored data and,
;;;; in v2, transfers it between drawings.
;;;;
;;;; clautolisp ships as a git submodule of outils-autolisp under
;;;; third-party/clautolisp; the Makefile makes its systems discoverable by
;;;; adding the submodule's Lisp directory to quicklisp's local-projects (see
;;;; the Makefile / README). dwg-identifier (the sibling subproject) is reused
;;;; for APPID-table classification; it is made discoverable the same way.

(asdf:defsystem "edward"
  :description "Read, dump (JSON) and transfer the EPURE application data stored in DWG/DXF drawings."
  :author "Pascal Bourguignon"
  :license "AGPL-3.0"
  :depends-on ("clautolisp/drawing" "clautolisp/drawing-dwg" "dwg-identifier" "uiop")
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "dwg-access")
   (:file "json")
   (:file "model")
   (:file "codec-xdata")
   (:file "dump")
   (:file "cli"))
  :in-order-to ((asdf:test-op (asdf:test-op "edward/tests")))
  :perform (asdf:test-op (op system)
                         (declare (ignore op system))
                         :success))

(asdf:defsystem "edward/tests"
  :description "Tests for edward."
  :author "Pascal Bourguignon"
  :license "AGPL-3.0"
  :depends-on ("edward" "fiveam")
  :pathname "tests"
  :serial t
  :components
  ((:file "package")
   (:file "test-harness")
   (:file "json-tests")
   (:file "codec-tests")
   (:file "dump-tests")
   (:file "run"))
  :perform (asdf:test-op (op system)
                         (declare (ignore op system))
                         (uiop:symbol-call :edward.tests :run-all-tests)))
