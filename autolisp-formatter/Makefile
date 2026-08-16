# autolisp-formatter --- formateur / pretty-printer AutoLISP écrit en AutoLISP

TEST_SUITE = autolisp-formatter

FMT_SOURCES = \
	-l src/fmt-util.lsp \
	-l src/fmt-scanner.lsp \
	-l src/fmt-parser.lsp \
	-l src/fmt-options.lsp \
	-l src/fmt-io.lsp \
	-l src/fmt-case.lsp \
	-l src/fmt-rules.lsp \
	-l src/fmt-printer.lsp \
	-l src/fmt-main.lsp

TEST_SOURCES = \
	-l ../autolisp-test/test-framework.lsp \
	$(FMT_SOURCES) \
	-l tests/scanner-tests.lsp \
	-l tests/parser-tests.lsp \
	-l tests/printer-tests.lsp \
	-l tests/options-tests.lsp \
	-l tests/corpus-tests.lsp \
	-l tests/run-tests.lsp

include ../makefiles/common.mk

.PHONY: docs-pdf format clean

docs-pdf:
	$(MAKE) -C docs pdf

# Formate les fichiers passés en FILES, sur place.
#   make format FILES="chemin/vers/fichier.lsp"
format:
	./scripts/autolisp-format --in-place $(FILES)

clean:
	@true
