.PHONY: pdf clean

ORG_FILES := $(wildcard *.org)
PDF_FILES := $(ORG_FILES:.org=.pdf)

pdf: $(PDF_FILES)

%.pdf: %.org
	pandoc $< -o $@

clean:
	rm -f $(PDF_FILES)
