.PHONY: test-ci test-bricscad bench-bricscad

test-ci:
	$(MAKE) -C autolisp-script test-ci
	$(MAKE) -C autolisp-vector test-ci

test-bricscad:
	$(MAKE) -C autolisp-script test-bricscad
	$(MAKE) -C autolisp-vector test-bricscad

bench-bricscad:
	$(MAKE) -C autolisp-vector bench-bricscad
