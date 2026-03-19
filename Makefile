.PHONY: test-ci test-bricscad bench-bricscad docs-pdf

test-ci:
	$(MAKE) -C autolisp-script     test-ci
	$(MAKE) -C autolisp-vector     test-ci
	$(MAKE) -C autolisp-hash-table test-ci

test-bricscad:
	$(MAKE) -C autolisp-script     test-bricscad
	$(MAKE) -C autolisp-vector     test-bricscad
	$(MAKE) -C autolisp-hash-table test-bricscad

bench-bricscad:
	$(MAKE) -C autolisp-vector     bench-bricscad
	$(MAKE) -C autolisp-hash-table bench-bricscad

docs-pdf:
	$(MAKE) -C autolisp-script     docs-pdf
	$(MAKE) -C autolisp-vector     docs-pdf
	$(MAKE) -C autolisp-hash-table docs-pdf
	$(MAKE) -C autolisp-formatter  docs-pdf

clean:
	$(MAKE) -C autolisp-script     clean
	$(MAKE) -C autolisp-vector     clean
	$(MAKE) -C autolisp-hash-table clean
	$(MAKE) -C autolisp-formatter  clean

