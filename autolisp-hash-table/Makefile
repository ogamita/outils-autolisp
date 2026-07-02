# autolisp-hash-table --- table de hachage AutoLISP (au-dessus de autolisp-vector)
#
# Benchmark (table vs a-list) : make benchmark BACKEND=clautolisp|bricscad|autocad

TEST_SUITE = autolisp-hash-table

TEST_SOURCES = \
	-l ../autolisp-test/test-framework.lsp \
	-l ../autolisp-vector/src/autolisp-vector.lsp \
	-l src/autolisp-hash-table.lsp \
	-l tests/hash-table-tests.lsp \
	-l tests/run-tests.lsp

BENCH_SOURCES = \
	-l ../autolisp-vector/src/autolisp-vector.lsp \
	-l src/autolisp-hash-table.lsp \
	-l tests/hash-table-benchmarks.lsp

include ../makefiles/common.mk

.PHONY: docs-pdf clean

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
