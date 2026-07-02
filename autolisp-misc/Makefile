# autolisp-misc --- utilitaires divers (fs, format, cat, browser)
#
# Tests pilotés par tests/run-tests.sh (marqueur « TESTS OK »), exécutés sous
# clautolisp (autolisp-script/autolisp est déprécié). Ce sous-projet n'utilise
# pas le framework autolisp-test, d'où un Makefile dédié plutôt que common.mk.

.PHONY: test-ci test test-clautolisp docs-pdf clean

CLAUTOLISP         ?= clautolisp
CLAUTOLISP_DIALECT ?= strict

test-ci: test

test: test-clautolisp

test-clautolisp:
	CLAUTOLISP="$(CLAUTOLISP)" CLAUTOLISP_DIALECT="$(CLAUTOLISP_DIALECT)" ./tests/run-tests.sh

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	$(MAKE) -C docs clean
