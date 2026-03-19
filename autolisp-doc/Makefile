.PHONY: test-ci test test-bricscad docs-pdf clean

test-ci: test

test: test-bricscad

test-bricscad:
	../autolisp-script/autolisp --bricscad \
		../autolisp-test/test-framework.lsp \
		src/autolisp-ref.lsp \
		src/autolisp-doc.lsp \
		tests/doc-tests.lsp \
		tests/run-tests.lsp

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
