# autolisp-doc --- API documentation / describe / apropos pour AutoLISP

TEST_SUITE = autolisp-doc

TEST_SOURCES = \
	-l ../autolisp-test/test-framework.lsp \
	-l src/autolisp-ref.lsp \
	-l src/autolisp-doc.lsp \
	-l tests/doc-tests.lsp \
	-l tests/run-tests.lsp

include ../makefiles/common.mk

.PHONY: docs-pdf clean

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
