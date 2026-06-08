# dwg-identifier — identify the SNCF application that produced a DWG/DXF.
#
# A Common-Lisp subproject built on the clautolisp drawing library.
# clautolisp is not installed yet, so its ASDF systems are made known by
# loading clautolisp.asd explicitly. Override CLAUTOLISP if your checkout
# lives elsewhere.

CLAUTOLISP    ?= $(HOME)/src/public/clautolisp
CLAUTOLISP_ASD := $(CLAUTOLISP)/clautolisp/clautolisp.asd
HERE_ASD      := $(CURDIR)/dwg-identifier.asd
SBCL          ?= sbcl
ARGS          ?=

QL  = (let ((q (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))) (when (probe-file q) (load q)))
ASD = (require :asdf) (asdf:load-asd "$(CLAUTOLISP_ASD)") (asdf:load-asd "$(HERE_ASD)")

.PHONY: help test test-ci run build-libredwg docs-pdf clean

help:
	@echo "dwg-identifier targets:"
	@echo "  make test                 run the unit tests (no libredwg needed)"
	@echo "  make build-libredwg       build the libredwg shim in clautolisp (needed for .dwg)"
	@echo "  make run ARGS='f.dwg ...'  classify drawings (DWG needs build-libredwg first)"
	@echo "  Override CLAUTOLISP=/path/to/clautolisp if needed (now: $(CLAUTOLISP))"

# The libredwg shim lives in clautolisp; DWG reading needs it (DXF does not).
build-libredwg:
	$(MAKE) -C $(CLAUTOLISP)/clautolisp build-libredwg

test:
	$(SBCL) --noinform --no-userinit --non-interactive \
		--eval '$(QL)' \
		--eval '(when (find-package :ql) (ql:quickload (list "fiveam" "cffi") :silent t))' \
		--eval '(progn $(ASD))' \
		--eval '(asdf:test-system "dwg-identifier")'

test-ci: test

run:
	@$(SBCL) --noinform --no-userinit --non-interactive \
		--eval '$(QL)' \
		--eval '(when (find-package :ql) (ql:quickload (list "cffi") :silent t))' \
		--eval '(progn $(ASD))' \
		--eval '(asdf:load-system "dwg-identifier")' \
		--eval '(uiop:quit (dwg-identifier:main (remove "" (uiop:split-string "$(ARGS)" :separator " ") :test (function string=))))'

docs-pdf:
	$(MAKE) -C docs pdf 2>/dev/null || true

clean:
	@true
