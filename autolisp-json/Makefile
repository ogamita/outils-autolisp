.PHONY: test-ci test test-bricscad test-bricscad-macos-batch test-bricscad-macos-osascript-attach docs-pdf clean

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
# autolisp >= 1.0.60 : --mode {automation,batch} (+ --backend {attach,launch}).
# (Anciennement --bricscad-macos-mode batch / --bricscad-macos-mode osascript.)
BRICSCAD_MACOS_BATCH_ARGS := --mode batch
BRICSCAD_MACOS_OSASCRIPT_ATTACH_ARGS := --mode automation --backend attach
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
		src/autolisp-json.lsp \
		tests/json-tests.lsp \
		tests/run-tests.lsp

test-bricscad-macos-osascript-attach:
	../autolisp-script/autolisp --bricscad $(BRICSCAD_MACOS_OSASCRIPT_ATTACH_ARGS) \
		../autolisp-test/test-framework.lsp \
		src/autolisp-json.lsp \
		tests/json-tests.lsp \
		tests/run-tests.lsp
else
test-bricscad:
	../autolisp-script/autolisp --bricscad \
		../autolisp-test/test-framework.lsp \
		src/autolisp-json.lsp \
		tests/json-tests.lsp \
		tests/run-tests.lsp
endif

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
