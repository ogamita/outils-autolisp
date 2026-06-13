# edward — dump and transfer the EPURE application data stored in DWG/DXF.
#
# A Common-Lisp subproject built on the clautolisp drawing library and the
# sibling dwg-identifier subproject. clautolisp ships as a git submodule of
# outils-autolisp under third-party/clautolisp; its CL systems
# (clautolisp/drawing and clautolisp/drawing-dwg) and dwg-identifier are made
# discoverable by adding their directories to quicklisp's local-projects and
# ASDF's central registry (see the ASD macro below). CLAUTOLISP defaults to
# the in-repo submodule; override it to point at another checkout if needed.
#
# After cloning outils-autolisp, populate the submodule (and its nested
# libredwg) once with, from the repo root:
#   git submodule update --init --recursive third-party/clautolisp
# DWG reading additionally needs the libredwg C shim — see build-libredwg.

CLAUTOLISP    ?= $(CURDIR)/../third-party/clautolisp
CLAUTOLISP_CL := $(CLAUTOLISP)/clautolisp
DWGID_DIR     := $(CURDIR)/../dwg-identifier
HERE_ASD      := $(CURDIR)/edward.asd
DWGID_ASD     := $(DWGID_DIR)/dwg-identifier.asd
SBCL          ?= sbcl
ARGS          ?=

# Build / install locations.
PREFIX        ?= /usr/local
DESTDIR       ?=
BUILD_DIR     ?= $(CURDIR)/bin
EXE           := $(BUILD_DIR)/edward

QL  = (let ((q (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))) (when (probe-file q) (load q)))
# Make clautolisp's ASDF systems and the sibling dwg-identifier discoverable:
# add the clautolisp Lisp directory to quicklisp's local-projects (when
# quicklisp is present) and both directories to ASDF's central registry, then
# load the relevant ASD files. find-symbol keeps this readable without quicklisp.
ASD = (require :asdf) \
  (let ((d (truename "$(CLAUTOLISP_CL)/"))) \
    (let ((ql (find-package :ql))) \
      (when ql (let ((lpd (find-symbol "*LOCAL-PROJECT-DIRECTORIES*" ql)) (reg (find-symbol "REGISTER-LOCAL-PROJECTS" ql))) \
        (when (and lpd reg) (pushnew d (symbol-value lpd) :test (function equal)) (funcall reg))))) \
    (pushnew d asdf:*central-registry* :test (function equal))) \
  (pushnew (truename "$(DWGID_DIR)/") asdf:*central-registry* :test (function equal)) \
  (asdf:load-asd "$(DWGID_ASD)") \
  (asdf:load-asd "$(HERE_ASD)")

.PHONY: help build install test test-ci run build-libredwg docs-pdf clean

help:
	@echo "edward targets:"
	@echo "  make build                build the edward executable (SBCL image) into $(BUILD_DIR)"
	@echo "  make install [PREFIX=...] install edward into \$$(DESTDIR)\$$(PREFIX)/bin (now: $(PREFIX))"
	@echo "  make test                 run the unit tests (synthetic DXF; no libredwg needed)"
	@echo "  make build-libredwg       build the libredwg shim in clautolisp (needed for .dwg)"
	@echo "  make run ARGS='dump f.dwg' run edward (DWG needs build-libredwg first)"
	@echo "  Override CLAUTOLISP=/path/to/clautolisp if needed (now: $(CLAUTOLISP))"

build: $(EXE)

$(EXE): edward.asd $(wildcard src/*.lisp)
	@mkdir -p "$(BUILD_DIR)"
	$(SBCL) --noinform --no-userinit --non-interactive \
		--eval '$(QL)' \
		--eval '(when (find-package :ql) (ql:quickload (list "cffi") :silent t))' \
		--eval '(progn $(ASD))' \
		--eval '(asdf:load-system "edward")' \
		--eval '(sb-ext:save-lisp-and-die "$(EXE)" :executable t :save-runtime-options t :toplevel (function edward::%toplevel))'
	@echo "built $(EXE)"

install: build
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 755 "$(EXE)" "$(DESTDIR)$(PREFIX)/bin/edward"
	@echo "installed $(DESTDIR)$(PREFIX)/bin/edward"

build-libredwg:
	$(MAKE) -C $(CLAUTOLISP)/clautolisp build-libredwg

test:
	$(SBCL) --noinform --no-userinit --non-interactive \
		--eval '$(QL)' \
		--eval '(when (find-package :ql) (ql:quickload (list "fiveam" "cffi") :silent t))' \
		--eval '(progn $(ASD))' \
		--eval '(asdf:test-system "edward")'

test-ci: test

run:
	@$(SBCL) --noinform --no-userinit --non-interactive \
		--eval '$(QL)' \
		--eval '(when (find-package :ql) (ql:quickload (list "cffi") :silent t))' \
		--eval '(progn $(ASD))' \
		--eval '(asdf:load-system "edward")' \
		--eval '(uiop:quit (edward:main (remove "" (uiop:split-string "$(ARGS)" :separator " ") :test (function string=))))'

docs-pdf:
	$(MAKE) -C docs pdf 2>/dev/null || true

clean:
	@rm -rf "$(BUILD_DIR)"
