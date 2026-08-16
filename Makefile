# Makefile racine --- cibles agrégées des sous-projets outils-autolisp.
#
# Les tests utilisent désormais clautolisp / alfe (autolisp-script/autolisp est
# déprécié). Chaque sous-projet fournit test / test-ci / test-clautolisp
# (cf. makefiles/common.mk) ; autolisp-script garde son backend fake-CAD.

# Sous-projets basés sur le framework autolisp-test (+ misc, harnais shell).
TEST_SUBPROJECTS = \
	autolisp-algetypes \
	autolisp-vector \
	autolisp-hash-table \
	autolisp-introspection \
	autolisp-json \
	autolisp-formatter \
	autolisp-doc \
	autolisp-misc

# Sous-projets qui exposent des cibles CAO (common.mk : test-bricscad /
# test-autocad). misc en est exclu (harnais shell, clautolisp seulement).
CAD_SUBPROJECTS = \
	autolisp-algetypes \
	autolisp-vector \
	autolisp-hash-table \
	autolisp-introspection \
	autolisp-json \
	autolisp-formatter \
	autolisp-doc

# Sous-projets avec un benchmark de vitesse (structure vs liste/a-list).
BENCH_SUBPROJECTS = \
	autolisp-vector \
	autolisp-hash-table

BACKEND ?= clautolisp

DOCS_SUBPROJECTS = \
	autolisp-script \
	autolisp-algetypes \
	autolisp-vector \
	autolisp-hash-table \
	autolisp-introspection \
	autolisp-json \
	autolisp-formatter \
	autolisp-misc \
	autolisp-doc

.PHONY: test-ci test test-clautolisp test-bricscad test-autocad benchmark install docs-pdf clean

# CI / headless : clautolisp pour les libs. (autolisp-script est déprécié.)
test-ci: test-clautolisp

# Cibles agrégées par moteur (un seul appel lance toute la matrice de
# sous-projets) — utilisées par les jobs CI « un clic » macOS/Windows.
test-clautolisp:
	@for d in $(TEST_SUBPROJECTS); do \
		echo "== $$d (clautolisp) =="; \
		$(MAKE) -C $$d test-clautolisp || exit 1; \
	done

test-bricscad:
	@for d in $(CAD_SUBPROJECTS); do \
		echo "== $$d (bricscad) =="; \
		$(MAKE) -C $$d test-bricscad || exit 1; \
	done

test-autocad:
	@for d in $(CAD_SUBPROJECTS); do \
		echo "== $$d (autocad) =="; \
		$(MAKE) -C $$d test-autocad || exit 1; \
	done

# Local : chaque sous-projet choisit ses moteurs selon uname (clautolisp + CAO).
test:
	@for d in $(TEST_SUBPROJECTS); do \
		echo "== $$d =="; \
		$(MAKE) -C $$d test || exit 1; \
	done

# Benchmark de vitesse agrégé (structure vs liste/a-list). Résultats sur stdout
# ET dans le fichier artefact benchmark-results.txt.
#   make benchmark BACKEND=clautolisp|bricscad|autocad
benchmark:
	@rm -f benchmark-results.txt
	@for d in $(BENCH_SUBPROJECTS); do \
		echo "== $$d (benchmark, BACKEND=$(BACKEND)) =="; \
		$(MAKE) -C $$d benchmark BACKEND=$(BACKEND) BENCH_OUTFILE=$(CURDIR)/$$d-benchmark.txt || exit 1; \
		cat $(CURDIR)/$$d-benchmark.txt >> benchmark-results.txt; \
	done
	@echo "=== benchmark-results.txt ==="; cat benchmark-results.txt

# Installation des exécutables des sous-projets (aujourd'hui : dwg-identifier).
# clautolisp est une dépendance système requise de dwg-identifier
# (installation complète sous CLAUTOLISP_PREFIX, /opt/local par défaut) ;
# PREFIX / DESTDIR / CLAUTOLISP_PREFIX sont transmis.
INSTALL_SUBPROJECTS = dwg-identifier

install:
	@for d in $(INSTALL_SUBPROJECTS); do \
		echo "== $$d (install) =="; \
		$(MAKE) -C $$d install || exit 1; \
	done

docs-pdf:
	@for d in $(DOCS_SUBPROJECTS); do $(MAKE) -C $$d docs-pdf || exit 1; done

clean:
	@for d in $(TEST_SUBPROJECTS) autolisp-script dwg-identifier; do \
		$(MAKE) -C $$d clean || exit 1; \
	done
