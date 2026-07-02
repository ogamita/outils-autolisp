# autolisp-json --- lecture/écriture JSON en AutoLISP

TEST_SUITE = autolisp-json

# strict lit les littéraux accentués en multi-octets (≠ vrai CAO Unicode) : 2 tests
# unicode échouent alors ((equal "é" (chr 233)) => nil). Cf. issue clautolisp
# « strict-string-byte-vs-char ». En attendant, json tourne en lax.
CLAUTOLISP_DIALECT = lax

TEST_SOURCES = \
	-l ../autolisp-test/test-framework.lsp \
	-l src/autolisp-json.lsp \
	-l tests/json-tests.lsp \
	-l tests/run-tests.lsp

include ../makefiles/common.mk

.PHONY: docs-pdf clean

docs-pdf:
	$(MAKE) -C docs pdf

clean:
	@true
