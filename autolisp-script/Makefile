.PHONY: test

CAD ?= --bricscad
TEST_BACKEND ?= real
TEST_TIMEOUT ?= 30
TEST_RUN_ARGS ?=

ifeq ($(TEST_BACKEND),fake)
TEST_BACKEND_FLAG := --fake-cad
else
TEST_BACKEND_FLAG :=
endif

test:
	./tests/run.sh $(TEST_BACKEND_FLAG) $(TEST_RUN_ARGS) --timeout $(TEST_TIMEOUT) $(CAD)
