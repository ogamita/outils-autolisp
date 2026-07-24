# dwg-identifier — identify the SNCF application that produced a DWG/DXF.
#
# A Common-Lisp subproject built on the clautolisp drawing library.
# clautolisp ships as a git submodule of outils-autolisp under
# third-party/clautolisp; its CL systems (clautolisp/drawing and
# clautolisp/drawing-dwg) are made discoverable by adding the submodule's
# Lisp directory to quicklisp's local-projects (see the ASD macro below).
# CLAUTOLISP defaults to the in-repo submodule, derived as a path relative
# to this Makefile; override it to point at another checkout if needed.
#
# After cloning outils-autolisp, populate the submodule (and its nested
# libredwg) once with, from the repo root:
#   git submodule update --init --recursive third-party/clautolisp
# DWG reading additionally needs the libredwg C shim — see build-libredwg.

CLAUTOLISP    ?= $(CURDIR)/../third-party/clautolisp
CLAUTOLISP_CL := $(CLAUTOLISP)/clautolisp
HERE_ASD      := $(CURDIR)/dwg-identifier.asd
SBCL          ?= sbcl
ARGS          ?=

# Build / install locations.
PREFIX        ?= /usr/local
DESTDIR       ?=
BUILD_DIR     ?= $(CURDIR)/bin
EXE           := $(BUILD_DIR)/dwg-identify

# GNU Make under Git Bash exposes MSYS paths (/c/Users/...), while the native
# Windows SBCL expects Windows paths.  cygpath -m keeps forward slashes, which
# are accepted by both Common Lisp pathnames and Unix-like shells.
ifeq ($(OS),Windows_NT)
lisp_path = $(shell cygpath -am "$(1)")
ASDF_ENCODING_SETUP = (setf sb-impl::*default-external-format* (list :utf-8 :newline :crlf) asdf:*default-encoding* :default)
else
lisp_path = $(1)
ASDF_ENCODING_SETUP = (values)
endif

CLAUTOLISP_CL_LISP := $(call lisp_path,$(CLAUTOLISP_CL))
HERE_ASD_LISP      := $(call lisp_path,$(HERE_ASD))
EXE_LISP           := $(call lisp_path,$(EXE))

QL  = (let ((q (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))) (when (probe-file q) (load q)))
# Make clautolisp's ASDF systems (clautolisp/drawing and
# clautolisp/drawing-dwg) discoverable from the in-repo submodule: add its
# Lisp directory to quicklisp's local-projects (when quicklisp is present)
# and to ASDF's central registry (fallback), then load our own system
# definition. find-symbol keeps this readable even without quicklisp.
ASD = (require :asdf) $(ASDF_ENCODING_SETUP) (let ((d (truename "$(CLAUTOLISP_CL_LISP)/"))) (let ((ql (find-package :ql))) (when ql (let ((lpd (find-symbol "*LOCAL-PROJECT-DIRECTORIES*" ql)) (reg (find-symbol "REGISTER-LOCAL-PROJECTS" ql))) (when (and lpd reg) (pushnew d (symbol-value lpd) :test (function equal)) (funcall reg))))) (pushnew d asdf:*central-registry* :test (function equal))) (asdf:load-asd (pathname "$(HERE_ASD_LISP)"))

.PHONY: help build install test test-ci run build-libredwg docs-pdf clean

help:
	@echo "dwg-identifier targets:"
	@echo "  make build                build the dwg-identify executable (SBCL image) into $(BUILD_DIR)"
	@echo "  make install [PREFIX=...] install dwg-identify into \$$(DESTDIR)\$$(PREFIX)/bin (now: $(PREFIX))"
	@echo "  make test                 run the unit tests (no libredwg needed)"
	@echo "  make build-libredwg       build the libredwg shim in clautolisp (needed for .dwg)"
	@echo "  make run ARGS='f.dwg ...'  classify drawings (DWG needs build-libredwg first)"
	@echo "  Override CLAUTOLISP=/path/to/clautolisp if needed (now: $(CLAUTOLISP))"

# Build the dwg-identify executable: an SBCL image whose toplevel is
# dwg-identifier::%toplevel (parses -h/--help -V/--version -v/--verbose
# [--json] dwgfile... and exits with main's status). :save-runtime-options
# keeps SBCL from interpreting our -V/--version/--help itself.
build: $(EXE)

$(EXE): dwg-identifier.asd $(wildcard src/*.lisp)
	@mkdir -p "$(BUILD_DIR)"
	$(SBCL) --noinform --no-userinit --non-interactive \
		--eval '$(QL)' \
		--eval '(when (find-package :ql) (ql:quickload (list "cffi") :silent t))' \
		--eval '(progn $(ASD))' \
		--eval '(asdf:load-system "dwg-identifier")' \
		--eval '(sb-ext:save-lisp-and-die "$(EXE_LISP)" :executable t :save-runtime-options t :toplevel (function dwg-identifier::%toplevel))'
	@echo "built $(EXE)"

# Install the executable to $(DESTDIR)$(PREFIX)/bin/dwg-identify.
install: build
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 755 "$(EXE)" "$(DESTDIR)$(PREFIX)/bin/dwg-identify"
	@echo "installed $(DESTDIR)$(PREFIX)/bin/dwg-identify"

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
	@rm -rf "$(BUILD_DIR)"
