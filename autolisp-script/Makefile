.PHONY: test test-fakecad test-bricscad test-autocad clean

CAD ?= --bricscad
TEST_TIMEOUT ?= 30
TEST_RUN_ARGS ?=


test: test-fakecad test-bricscad test-autocad

test-fakecad:
	./tests/run.sh --fake-cad $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) --bricscad
	./tests/run.sh --fake-cad $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) --autocad

test-bricscad:
	./tests/run.sh $(TEST_BACKEND_FLAG) $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) --bricscad

test-autocad:
	./tests/run.sh $(TEST_BACKEND_FLAG) $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) --autocad


clean:
	- rm -rf tests/tmp .autolisp-runs
	- mkdir -p tests/tmp .autolisp-runs
