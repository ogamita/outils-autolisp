# dwg-identifier — identify the SNCF application that produced a DWG/DXF.
#
# A Common-Lisp subproject built on the clautolisp drawing library
# (its clautolisp/drawing and clautolisp/drawing-dwg systems).
#
# clautolisp is a required SYSTEM dependency (it is no longer vendored
# as a submodule): a complete clautolisp installation under
# CLAUTOLISP_PREFIX (default /opt/local) must provide
#
#   $(CLAUTOLISP_PREFIX)/share/common-lisp/source/clautolisp/  CL sources
#   $(CLAUTOLISP_PREFIX)/lib/clautolisp/<os>/<arch>/           libredwg + shim
#
# Both come from a clautolisp release "libraries" artefact (or a
# clautolisp checkout's release-libraries staging). The executable is
# built against those installed sources, so at run time the drawing-dwg
# CFFI loader derives the native-library directory from them (see
# drawing-dwg/source/bindings.lisp): the installed dwg-identify depends
# only on CLAUTOLISP_PREFIX, never on a source checkout.
#
# Developers hacking on clautolisp itself can instead point
# CLAUTOLISP_SOURCES at the clautolisp/ Lisp directory of a checkout,
# e.g. `make CLAUTOLISP_SOURCES=$$HOME/works/clautolisp/clautolisp`;
# the executable then looks for the shim in that checkout's dev tree —
# build it there first (`make build-libredwg` forwards when possible),
# or set CLAUTOLISP_DWG_LIBDIR at run time.

CLAUTOLISP_PREFIX  ?= /opt/local
CLAUTOLISP_SOURCES_DEFAULT := $(CLAUTOLISP_PREFIX)/share/common-lisp/source/clautolisp
CLAUTOLISP_SOURCES ?= $(CLAUTOLISP_SOURCES_DEFAULT)
HERE_ASD           := $(CURDIR)/dwg-identifier.asd
SBCL               ?= sbcl
ARGS               ?=

# Build / install locations. PREFIX follows the clautolisp convention
# (/opt/local) so the binary lands beside the libraries it uses.
PREFIX        ?= /opt/local
DESTDIR       ?=
BUILD_DIR     ?= $(CURDIR)/bin
EXE           := $(BUILD_DIR)/dwg-identify

# os/arch/extension tags as in clautolisp's Makefile (REL_OS/REL_ARCH)
# — used only to diagnose the native DWG codec location.
REL_OS   := $(shell uname | tr 'A-Z' 'a-z' | sed -e 's/^mingw.*/windows/' -e 's/^msys.*/windows/' -e 's/^cygwin.*/windows/')
REL_ARCH := $(shell uname -m | tr 'A-Z' 'a-z' | sed -e 's/^x86_64$$/x86-64/' -e 's/^amd64$$/x86-64/' -e 's/^aarch64$$/arm64/')
ifeq ($(REL_OS),darwin)
  SHIM_EXT := dylib
else ifeq ($(REL_OS),windows)
  SHIM_EXT := dll
else
  SHIM_EXT := so
endif
# The shim location the built executable will probe at run time: the
# installed libdir when built against the installed sources (the CFFI
# loader derives the prefix from them), the checkout's dev tree when
# built against a CLAUTOLISP_SOURCES override (no fallback to a prefix).
SHIM_LIBDIR    := $(CLAUTOLISP_PREFIX)/lib/clautolisp/$(REL_OS)/$(REL_ARCH)
ifeq ($(CLAUTOLISP_SOURCES),$(CLAUTOLISP_SOURCES_DEFAULT))
  SHIM := $(SHIM_LIBDIR)/clal_dwg.$(SHIM_EXT)
else
  SHIM := $(CLAUTOLISP_SOURCES)/drawing-dwg/source/clal_dwg.$(SHIM_EXT)
endif

QL  = (let ((q (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))) (when (probe-file q) (load q)))
# Make clautolisp's ASDF systems (clautolisp/drawing and
# clautolisp/drawing-dwg — secondary systems of clautolisp.asd)
# discoverable from the installed source tree (or the
# CLAUTOLISP_SOURCES override) via ASDF's central registry, then load
# our own system definition. quicklisp's local-projects is NOT used
# for this: its indexer writes a system-index.txt into the registered
# directory, which fails on a root-owned system installation.
ASD = (require :asdf) (pushnew (truename "$(CLAUTOLISP_SOURCES)/") asdf:*central-registry* :test (function equal)) (asdf:load-asd "$(HERE_ASD)")

.PHONY: help build install test test-ci run check-clautolisp build-libredwg docs-pdf clean

help:
	@echo "dwg-identifier targets:"
	@echo "  make build                build the dwg-identify executable (SBCL image) into $(BUILD_DIR)"
	@echo "  make install [PREFIX=...] install dwg-identify into \$$(DESTDIR)\$$(PREFIX)/bin (now: $(PREFIX))"
	@echo "  make test                 run the unit tests (no libredwg needed)"
	@echo "  make check-clautolisp     verify the required clautolisp installation"
	@echo "  make run ARGS='f.dwg ...'  classify drawings"
	@echo ""
	@echo "clautolisp is a required system dependency:"
	@echo "  CLAUTOLISP_PREFIX  = $(CLAUTOLISP_PREFIX)"
	@echo "  CLAUTOLISP_SOURCES = $(CLAUTOLISP_SOURCES)"
	@echo "  native DWG codec   = $(SHIM)"
	@echo "Override CLAUTOLISP_PREFIX for another install location, or"
	@echo "CLAUTOLISP_SOURCES to build against a clautolisp checkout."

# Fail early, with an actionable message, when the required clautolisp
# installation is absent. The native DWG codec is only a warning: DXF
# reading needs no shim, and the CLAUTOLISP_SOURCES override finds it
# in the checkout's dev tree instead.
check-clautolisp:
	@if [ ! -f "$(CLAUTOLISP_SOURCES)/clautolisp.asd" ]; then \
	  echo "error: clautolisp CL sources not found: $(CLAUTOLISP_SOURCES)/clautolisp.asd" ; \
	  echo "dwg-identifier requires a system installation of clautolisp (sources +" ; \
	  echo "native libraries). Install a clautolisp release under $(CLAUTOLISP_PREFIX)," ; \
	  echo "or override CLAUTOLISP_PREFIX=/path/to/prefix, or point" ; \
	  echo "CLAUTOLISP_SOURCES=/path/to/checkout/clautolisp at a clautolisp checkout." ; \
	  exit 1 ; \
	fi
	@if [ ! -f "$(SHIM)" ]; then \
	  echo "warning: native DWG codec not found ($(SHIM))" ; \
	  echo "warning: .dwg files will not be readable (DXF still is); install the" ; \
	  echo "warning: clautolisp native libraries (or, against a checkout, build" ; \
	  echo "warning: them with \`make build-libredwg\`), or set CLAUTOLISP_DWG_LIBDIR." ; \
	fi
	@echo "clautolisp: $(CLAUTOLISP_SOURCES)"

# Build the dwg-identify executable: an SBCL image whose toplevel is
# dwg-identifier::%toplevel (parses -h/--help -V/--version -v/--verbose
# [--json] dwgfile... and exits with main's status). :save-runtime-options
# keeps SBCL from interpreting our -V/--version/--help itself.
build: check-clautolisp $(EXE)

$(EXE): dwg-identifier.asd $(wildcard src/*.lisp)
	@mkdir -p "$(BUILD_DIR)"
	$(SBCL) --noinform --no-userinit --non-interactive \
		--eval '$(QL)' \
		--eval '(when (find-package :ql) (ql:quickload (list "cffi") :silent t))' \
		--eval '(progn $(ASD))' \
		--eval '(asdf:load-system "dwg-identifier")' \
		--eval '(sb-ext:save-lisp-and-die "$(EXE)" :executable t :save-runtime-options t :toplevel (function dwg-identifier::%toplevel))'
	@echo "built $(EXE)"

# Install the executable to $(DESTDIR)$(PREFIX)/bin/dwg-identify. The
# clautolisp it was built against stays a runtime dependency (sources
# for provenance, native libraries for DWG), so it must remain
# installed under CLAUTOLISP_PREFIX.
install: build
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 755 "$(EXE)" "$(DESTDIR)$(PREFIX)/bin/dwg-identify"
	@echo "installed $(DESTDIR)$(PREFIX)/bin/dwg-identify"

# The shim ships with the clautolisp installation; this target only
# forwards to a checkout when CLAUTOLISP_SOURCES points at one.
build-libredwg:
	@if [ -f "$(CLAUTOLISP_SOURCES)/Makefile" ]; then \
	  $(MAKE) -C "$(CLAUTOLISP_SOURCES)" build-libredwg ; \
	else \
	  echo "build-libredwg: the native DWG codec ships with the clautolisp" ; \
	  echo "installation (expected: $(INSTALLED_SHIM));" ; \
	  echo "install the clautolisp native libraries, or build against a checkout" ; \
	  echo "with CLAUTOLISP_SOURCES=/path/to/checkout/clautolisp." ; \
	  exit 1 ; \
	fi

test: check-clautolisp
	$(SBCL) --noinform --no-userinit --non-interactive \
		--eval '$(QL)' \
		--eval '(when (find-package :ql) (ql:quickload (list "fiveam" "cffi") :silent t))' \
		--eval '(progn $(ASD))' \
		--eval '(asdf:test-system "dwg-identifier")'

test-ci: test

run: check-clautolisp
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
