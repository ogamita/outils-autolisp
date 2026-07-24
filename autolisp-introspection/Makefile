# autolisp-introspection --- photographie et diff des entités

TEST_SUITE = autolisp-introspection

TEST_SOURCES = \
	-l ../autolisp-test/test-framework.lsp \
	-l src/autolisp-introspection.lsp \
	-l ../autolisp-test/test-entites.lsp \
	-l tests/introspection-tests.lsp \
	-l tests/run-tests.lsp

ALFE ?= alfe
CLAUTOLISP_DIALECT ?= strict
TEST_MAIN ?= -x '(C:MAIN)'
UNAME_S ?= $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
CAD_IO_ENCODING ?= MAC-ROMAN
else ifneq (,$(filter MINGW% MSYS% CYGWIN% Windows_NT,$(UNAME_S)))
CAD_IO_ENCODING ?= WINDOWS-1252
else
CAD_IO_ENCODING ?= UTF-8
endif

.PHONY: test-ci test test-clautolisp test-bricscad test-autocad docs-pdf clean

test-ci: test-clautolisp

test: test-clautolisp test-bricscad

# Le modèle d'entités clautolisp est en cours d'implantation. Les tests purs
# tournent déjà via alfe ; EI_CAD_TESTS les complétera dès que entget accepte
# le filtre xdata '("*").
test-clautolisp:
	$(ALFE) -norc --clautolisp --host mock --dialect $(CLAUTOLISP_DIALECT) \
		$(TEST_SOURCES) $(TEST_MAIN) -q --quit

test-bricscad:
	EI_CAD_TESTS=1 $(ALFE) -norc --bricscad --mode batch --timeout 120 \
		-e UTF-8 -E $(CAD_IO_ENCODING) \
		$(TEST_SOURCES) $(TEST_MAIN) -q

test-autocad:
	EI_CAD_TESTS=1 $(ALFE) -norc --autocad --mode batch --timeout 120 \
		-e UTF-8 -E $(CAD_IO_ENCODING) \
		$(TEST_SOURCES) $(TEST_MAIN) -q

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	$(MAKE) -C docs clean
