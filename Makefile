.PHONY: test-ci test-bricscad test-bricscad-macos-batch test-bricscad-macos-osascript-attach bench-bricscad docs-pdf

UNAME_S := $(shell uname -s)

test-ci:
	$(MAKE) -C autolisp-script     test-ci
	$(MAKE) -C autolisp-vector     test-ci
	$(MAKE) -C autolisp-hash-table test-ci
	$(MAKE) -C autolisp-misc       test-ci

ifeq ($(UNAME_S),Darwin)
test-bricscad:
	$(MAKE) test-bricscad-macos-batch
	$(MAKE) test-bricscad-macos-osascript-attach

test-bricscad-macos-batch:
	$(MAKE) -C autolisp-script     test-bricscad-macos-batch
	$(MAKE) -C autolisp-vector     test-bricscad-macos-batch
	$(MAKE) -C autolisp-hash-table test-bricscad-macos-batch
	$(MAKE) -C autolisp-misc       test-bricscad-macos-batch

test-bricscad-macos-osascript-attach:
	$(MAKE) -C autolisp-script     test-bricscad-macos-osascript-attach
	$(MAKE) -C autolisp-vector     test-bricscad-macos-osascript-attach
	$(MAKE) -C autolisp-hash-table test-bricscad-macos-osascript-attach
	$(MAKE) -C autolisp-misc       test-bricscad-macos-osascript-attach
else
test-bricscad:
	$(MAKE) -C autolisp-script     test-bricscad
	$(MAKE) -C autolisp-vector     test-bricscad
	$(MAKE) -C autolisp-hash-table test-bricscad
	$(MAKE) -C autolisp-misc       test-bricscad
endif

bench-bricscad:
	$(MAKE) -C autolisp-vector     bench-bricscad
	$(MAKE) -C autolisp-hash-table bench-bricscad

docs-pdf:
	$(MAKE) -C autolisp-script     docs-pdf
	$(MAKE) -C autolisp-vector     docs-pdf
	$(MAKE) -C autolisp-hash-table docs-pdf
	$(MAKE) -C autolisp-formatter  docs-pdf
	$(MAKE) -C autolisp-misc       docs-pdf
	$(MAKE) -C autolisp-doc        docs-pdf

clean:
	$(MAKE) -C autolisp-script     clean
	$(MAKE) -C autolisp-vector     clean
	$(MAKE) -C autolisp-hash-table clean
	$(MAKE) -C autolisp-formatter  clean
	$(MAKE) -C autolisp-misc       clean
