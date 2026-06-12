;;;; dwg-identifier — identify the originating SNCF application of a DWG/DXF.
;;;;
;;;; A Common-Lisp tool (the first ASDF subproject of outils-autolisp)
;;;; built on the clautolisp drawing library: it reads a drawing with
;;;; clautolisp.drawing (DXF natively, DWG via clautolisp/drawing-dwg +
;;;; libredwg) and classifies it by the application appids it carries —
;;;; SCHMS, SCHME, SCHMIEUX, PV, and the EPURE umbrella.
;;;;
;;;; clautolisp is not installed yet (its drawing layer is unreleased),
;;;; so it ships as a git submodule of outils-autolisp under
;;;; third-party/clautolisp; the Makefile makes its systems discoverable
;;;; by adding the submodule's Lisp directory to quicklisp's local-projects
;;;; (see the Makefile / README). Once clautolisp ships, this becomes a
;;;; plain dependency.

(asdf:defsystem "dwg-identifier"
  :description "Identify the SNCF application (SCHMS / SCHME / SCHMIEUX / PV / EPURE) that produced a DWG/DXF drawing."
  :author "Pascal Bourguignon"
  :license "AGPL-3.0"
  :depends-on ("clautolisp/drawing" "clautolisp/drawing-dwg" "uiop")
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "classify")
   (:file "cli"))
  :in-order-to ((asdf:test-op (asdf:test-op "dwg-identifier/tests")))
  :perform (asdf:test-op (op system)
                         (declare (ignore op system))
                         :success))

(asdf:defsystem "dwg-identifier/tests"
  :description "Tests for dwg-identifier."
  :author "Pascal Bourguignon"
  :license "AGPL-3.0"
  :depends-on ("dwg-identifier" "fiveam")
  :pathname "tests"
  :serial t
  :components
  ((:file "package")
   (:file "test-harness")
   (:file "classify-tests")
   (:file "run"))
  :perform (asdf:test-op (op system)
                         (declare (ignore op system))
                         (uiop:symbol-call :dwg-identifier.tests :run-all-tests)))
