# autolisp-vector --- vecteur AutoLISP indexé par arbre
#
# Benchmarks : AV_RUN_BENCHMARKS=1 make test   (voir tests/run-tests.lsp)

TEST_SUITE = autolisp-vector

TEST_SOURCES = \
	-l ../autolisp-test/test-framework.lsp \
	-l src/autolisp-vector.lsp \
	-l tests/vector-tests.lsp \
	-l tests/vector-benchmarks.lsp \
	-x '(setq av-run-benchmarks-flag nil)' \
	-l tests/run-tests.lsp

include ../makefiles/common.mk

.PHONY: docs-pdf clean

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
