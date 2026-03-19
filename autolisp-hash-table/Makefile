.PHONY: test-ci test test-bricscad bench-bricscad docs-pdf clean

test-ci: test

test: test-bricscad

test-bricscad:
	../autolisp-script/autolisp --bricscad \
		../autolisp-test/test-framework.lsp \
		../autolisp-vector/src/autolisp-vector.lsp \
		src/autolisp-hash-table.lsp \
		tests/hash-table-tests.lsp \
		tests/hash-table-benchmarks.lsp \
		-x '(setq ah-run-benchmarks-flag nil)' \
		$(if $(AH_RUN_BENCHMARKS),-x '(setq ah-run-benchmarks-flag T)',) \
		tests/run-tests.lsp

bench-bricscad:
	../autolisp-script/autolisp --bricscad --timeout 600 \
		../autolisp-test/test-framework.lsp \
		../autolisp-vector/src/autolisp-vector.lsp \
		src/autolisp-hash-table.lsp \
		tests/hash-table-tests.lsp \
		tests/hash-table-benchmarks.lsp \
		tests/run-benchmarks.lsp

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
