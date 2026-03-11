.PHONY: test

CAD ?= --bricscad
TEST_BACKEND ?= real

ifeq ($(TEST_BACKEND),fake)
TEST_BACKEND_FLAG := --fake-cad
else
TEST_BACKEND_FLAG :=
endif

test:
	./tests/run.sh $(TEST_BACKEND_FLAG) $(CAD)
