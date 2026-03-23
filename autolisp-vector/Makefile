.PHONY: test-ci test test-bricscad test-bricscad-macos-batch test-bricscad-macos-osascript-attach bench-bricscad docs-pdf clean

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
BRICSCAD_MACOS_BATCH_ARGS := --bricscad-macos-mode batch
BRICSCAD_MACOS_OSASCRIPT_ATTACH_ARGS := --bricscad-macos-mode osascript --bricscad-macos-app attach
else
BRICSCAD_MACOS_BATCH_ARGS :=
BRICSCAD_MACOS_OSASCRIPT_ATTACH_ARGS :=
endif

test-ci: test

test: test-bricscad

ifeq ($(UNAME_S),Darwin)
test-bricscad:
	$(MAKE) test-bricscad-macos-batch
	$(MAKE) test-bricscad-macos-osascript-attach

test-bricscad-macos-batch:
	../autolisp-script/autolisp --bricscad $(BRICSCAD_MACOS_BATCH_ARGS) \
		../autolisp-test/test-framework.lsp \
		src/autolisp-vector.lsp \
		tests/vector-tests.lsp \
		tests/vector-benchmarks.lsp \
		-x '(setq av-run-benchmarks-flag nil)' \
		$(if $(AV_RUN_BENCHMARKS),-x '(setq av-run-benchmarks-flag T)',) \
		tests/run-tests.lsp

test-bricscad-macos-osascript-attach:
	../autolisp-script/autolisp --bricscad $(BRICSCAD_MACOS_OSASCRIPT_ATTACH_ARGS) \
		../autolisp-test/test-framework.lsp \
		src/autolisp-vector.lsp \
		tests/vector-tests.lsp \
		tests/vector-benchmarks.lsp \
		-x '(setq av-run-benchmarks-flag nil)' \
		$(if $(AV_RUN_BENCHMARKS),-x '(setq av-run-benchmarks-flag T)',) \
		tests/run-tests.lsp
else
test-bricscad:
	../autolisp-script/autolisp --bricscad \
		../autolisp-test/test-framework.lsp \
		src/autolisp-vector.lsp \
		tests/vector-tests.lsp \
		tests/vector-benchmarks.lsp \
		-x '(setq av-run-benchmarks-flag nil)' \
		$(if $(AV_RUN_BENCHMARKS),-x '(setq av-run-benchmarks-flag T)',) \
		tests/run-tests.lsp
endif

bench-bricscad:
	../autolisp-script/autolisp --bricscad $(BRICSCAD_MACOS_BATCH_ARGS) --timeout 600 \
		../autolisp-test/test-framework.lsp \
		src/autolisp-vector.lsp \
		tests/vector-tests.lsp \
		tests/vector-benchmarks.lsp \
		-x '(setq av-run-benchmarks-flag nil)' \
		-x '(setq av-run-benchmarks-flag T)' \
		tests/run-tests.lsp

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
