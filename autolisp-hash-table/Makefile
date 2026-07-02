# autolisp-hash-table --- table de hachage AutoLISP (au-dessus de autolisp-vector)
#
# Benchmarks : AH_RUN_BENCHMARKS=1 make test   (voir tests/run-tests.lsp)

TEST_SUITE = autolisp-hash-table

TEST_SOURCES = \
	-l ../autolisp-test/test-framework.lsp \
	-l ../autolisp-vector/src/autolisp-vector.lsp \
	-l src/autolisp-hash-table.lsp \
	-l tests/hash-table-tests.lsp \
	-l tests/hash-table-benchmarks.lsp \
	-x '(setq ah-run-benchmarks-flag nil)' \
	-l tests/run-tests.lsp

include ../makefiles/common.mk

.PHONY: docs-pdf clean

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
