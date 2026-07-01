.PHONY: test-ci test test-bricscad test-bricscad-macos-batch test-bricscad-macos-osascript-attach docs-pdf clean

UNAME_S := $(shell uname -s)

# Runner : alfe (AutoLISP front-end). autolisp-script/autolisp est déprécié.
ALFE ?= alfe

# Sources chargées dans l'ordre, puis la suite est lancée par (C:MAIN).
TEST_SOURCES := \
	-l ../autolisp-test/test-framework.lsp \
	-l src/autolisp-json.lsp \
	-l tests/json-tests.lsp \
	-l tests/run-tests.lsp \
	-x '(C:MAIN)'

ifeq ($(UNAME_S),Darwin)
# alfe sur macOS : --mode {automation,batch} (+ --backend {attach,launch}).
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
	$(ALFE) -norc --bricscad $(BRICSCAD_MACOS_BATCH_ARGS) $(TEST_SOURCES) -q

test-bricscad-macos-osascript-attach:
	$(ALFE) -norc --bricscad $(BRICSCAD_MACOS_OSASCRIPT_ATTACH_ARGS) $(TEST_SOURCES) -q
else
test-bricscad:
	$(ALFE) -norc --bricscad $(TEST_SOURCES) -q
endif

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
