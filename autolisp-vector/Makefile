# autolisp-vector --- vecteur AutoLISP indexé par arbre
#
# Benchmark (vecteur vs liste) : make benchmark BACKEND=clautolisp|bricscad|autocad

TEST_SUITE = autolisp-vector

TEST_SOURCES = \
	-l ../autolisp-test/test-framework.lsp \
	-l src/autolisp-vector.lsp \
	-l tests/vector-tests.lsp \
	-l tests/run-tests.lsp

BENCH_SOURCES = \
	-l src/autolisp-vector.lsp \
	-l tests/vector-benchmarks.lsp

include ../makefiles/common.mk

.PHONY: docs-pdf clean

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
