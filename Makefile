# Makefile racine --- cibles agrégées des sous-projets outils-autolisp.
#
# Les tests utilisent désormais clautolisp / alfe (autolisp-script/autolisp est
# déprécié). Chaque sous-projet fournit test / test-ci / test-clautolisp
# (cf. makefiles/common.mk) ; autolisp-script garde son backend fake-CAD.

# Sous-projets basés sur le framework autolisp-test (+ misc, harnais shell).
TEST_SUBPROJECTS = \
	autolisp-vector \
	autolisp-hash-table \
	autolisp-json \
	autolisp-doc \
	autolisp-misc

DOCS_SUBPROJECTS = \
	autolisp-script \
	autolisp-vector \
	autolisp-hash-table \
	autolisp-json \
	autolisp-formatter \
	autolisp-misc \
	autolisp-doc

.PHONY: test-ci test test-clautolisp docs-pdf clean

# CI / headless : clautolisp pour les libs, backend fake-CAD pour autolisp-script.
test-ci: test-clautolisp
	$(MAKE) -C autolisp-script test-fakecad TEST_TIMEOUT=10

test-clautolisp:
	@for d in $(TEST_SUBPROJECTS); do \
		echo "== $$d (clautolisp) =="; \
		$(MAKE) -C $$d test-clautolisp || exit 1; \
	done

# Local : chaque sous-projet choisit ses moteurs selon uname (clautolisp + CAO).
test:
	@for d in $(TEST_SUBPROJECTS); do \
		echo "== $$d =="; \
		$(MAKE) -C $$d test || exit 1; \
	done

docs-pdf:
	@for d in $(DOCS_SUBPROJECTS); do $(MAKE) -C $$d docs-pdf || exit 1; done

clean:
	@for d in $(TEST_SUBPROJECTS) autolisp-formatter autolisp-script; do \
		$(MAKE) -C $$d clean || exit 1; \
	done
