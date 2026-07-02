# autolisp-script est DÉPRÉCIÉ (remplacé par alfe, projet clautolisp).
# Ses tests sont inhibés ; les cibles de test sont des no-op.

.PHONY: test-ci test test-fakecad test-bricscad test-autocad docs-pdf clean

DEPRECATED_MSG = autolisp-script est deprecated (remplace par alfe) : tests inhibes.

test-ci test test-fakecad test-bricscad test-autocad:
	@echo "$(DEPRECATED_MSG)"

EMACS ?= emacs

docs-pdf: autolisp-examples.pdf
	$(MAKE) -C docs pdf

autolisp-examples.pdf: autolisp-examples.org
	$(EMACS) --batch --visit $< --funcall org-latex-export-to-pdf
	rm -f autolisp-examples.tex

clean:
	- rm -rf tests/tmp .autolisp-runs
	- mkdir -p tests/tmp .autolisp-runs
