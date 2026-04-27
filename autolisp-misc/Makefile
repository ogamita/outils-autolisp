.PHONY: test-ci test test-bricscad test-bricscad-macos-batch test-bricscad-macos-osascript-attach docs-pdf clean

UNAME_S := $(shell uname -s)

TEST_TIMEOUT ?= 60

ifeq ($(UNAME_S),Darwin)
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
	./tests/run-tests.sh --bricscad $(BRICSCAD_MACOS_BATCH_ARGS) --timeout $(TEST_TIMEOUT)

test-bricscad-macos-osascript-attach:
	./tests/run-tests.sh --bricscad $(BRICSCAD_MACOS_OSASCRIPT_ATTACH_ARGS) --timeout $(TEST_TIMEOUT)
else
test-bricscad:
	./tests/run-tests.sh --bricscad --timeout $(TEST_TIMEOUT)
endif

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	$(MAKE) -C docs clean
