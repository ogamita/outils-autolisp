# autolisp-algetypes --- petits types algébriques pour AutoLISP

TEST_SUITE = autolisp-algetypes

TEST_SOURCES = \
	-l ../autolisp-test/test-framework.lsp \
	-l src/autolisp-algetypes.lsp \
	-l tests/algetypes-tests.lsp \
	-l tests/run-tests.lsp

include ../makefiles/common.mk

.PHONY: docs-pdf clean

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
