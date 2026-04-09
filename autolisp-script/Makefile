.PHONY: test-ci test-fakecad test-bricscad test-bricscad-macos-batch test-bricscad-macos-automation-attach test-autocad docs-pdf clean

CAD ?= --bricscad
TEST_BACKEND ?= real
TEST_TIMEOUT ?= 30
TEST_RUN_ARGS ?=

ifeq ($(TEST_BACKEND),fake)
TEST_TARGETS := test-fakecad
else ifeq ($(TEST_BACKEND),real)
TEST_TARGETS := test-bricscad test-autocad
else
TEST_TARGETS := test-$(TEST_BACKEND)
endif

test-ci: $(TEST_TARGETS)

test-fakecad:
	./tests/run.sh --fake-cad $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) --bricscad
	./tests/run.sh --fake-cad $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) --autocad

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
test-bricscad:
	$(MAKE) test-bricscad-macos-batch
	$(MAKE) test-bricscad-macos-automation-attach

test-bricscad-macos-batch:
	./tests/run.sh $(TEST_BACKEND_FLAG) $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) --bricscad --mode batch

test-bricscad-macos-automation-attach:
	./tests/run.sh $(TEST_BACKEND_FLAG) $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) --bricscad --mode automation --backend attach
else
test-bricscad:
	./tests/run.sh $(TEST_BACKEND_FLAG) $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) --bricscad
endif

test-autocad:
	./tests/run.sh $(TEST_BACKEND_FLAG) $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) --autocad

docs-pdf:
	pandoc autolisp-examples.org -o autolisp-examples.pdf


clean:
	- rm -rf tests/tmp .autolisp-runs
	- mkdir -p tests/tmp .autolisp-runs
