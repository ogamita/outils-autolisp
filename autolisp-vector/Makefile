.PHONY: test-ci test test-bricscad bench-bricscad docs-pdf clean

test-ci: test

test: test-bricscad

test-bricscad:
	../autolisp-script/autolisp --bricscad \
		../autolisp-test/test-framework.lsp \
		src/autolisp-vector.lsp \
		tests/vector-tests.lsp \
		tests/vector-benchmarks.lsp \
		-x '(setq av-run-benchmarks-flag nil)' \
		$(if $(AV_RUN_BENCHMARKS),-x '(setq av-run-benchmarks-flag T)',) \
		tests/run-tests.lsp

bench-bricscad:
	../autolisp-script/autolisp --bricscad --timeout 600 \
		../autolisp-test/test-framework.lsp \
		src/autolisp-vector.lsp \
		tests/vector-tests.lsp \
		tests/vector-benchmarks.lsp \
		-x '(setq av-run-benchmarks-flag nil)' \
		-x '(setq av-run-benchmarks-flag T)' \
		tests/run-tests.lsp

docs-pdf:
	$(MAKE) -C doc pdf

clean:
	@echo "autolisp-vector: nothing to clean yet"
