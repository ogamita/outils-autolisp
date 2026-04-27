.PHONY: pdf clean

ORG_FILES := $(wildcard *.org)
PDF_FILES := $(ORG_FILES:.org=.pdf)
TEX_FILES := $(ORG_FILES:.org=.tex)

EMACS ?= emacs

pdf: $(PDF_FILES)

%.pdf: %.org
	$(EMACS) --batch --visit $< --funcall org-latex-export-to-pdf
	rm -f $*.tex

clean:
	rm -f $(PDF_FILES) $(TEX_FILES)
