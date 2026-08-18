# Makefile racine d'outils-autolisp.
#
# Structure : les PHASES de build-rules.md (B1..B10, cf.
# ~/src/public/rules/build-rules.md), et les quatre VERBES définis sur
# chacune.
#
#   libraries      les systèmes ALPM          -> $PREFIX/share/autolisp/
#   programs       dwg-identify (image SBCL)  -> $PREFIX/bin/
#   documentation  manuels org : pdf, html,   -> $PREFIX/share/doc/outils-autolisp/
#                  html paginé, info          -> $PREFIX/share/info/
#
#   build-X   compile ; n'écrit que dans l'arbre de travail.
#   stage-X   construit puis dispose le résultat sous $(STAGE)/X/ EXACTEMENT
#             comme il doit apparaître sous $PREFIX. C'est la seule moitié
#             qui compile.
#   install-X copie $(STAGE)/X/ dans $(DESTDIR)$(PREFIX)/ — et ne compile
#             rien (B2), pour que `sudo make install` ne laisse jamais
#             d'objets appartenant à root dans l'arbre de travail (B3 :
#             la moitié « stage » est relancée sous $SUDO_USER).
#   release-X empaquette depuis le MÊME arbre staged (B7), en .tar.bz2 et
#             en .zip (les utilisateurs Windows n'ont pas tar/bzip2).
#
# Chaque phase est installable seule (B1) : une machine sans Emacs/TeX
# installe quand même les bibliothèques et les programmes.
#
# Rien n'inscrit $PREFIX dans le contenu staged : les systèmes ALPM sont
# relocalisables, alpm.lsp trouve son répertoire de site tout seul.
#
# Les cibles de TEST des sous-projets sont conservées telles quelles
# plus bas (test, test-clautolisp, test-bricscad, test-autocad,
# benchmark) ; elles utilisent clautolisp / alfe via makefiles/common.mk.

PROJECT     = outils-autolisp
VERSION    := $(shell cat VERSION)

PREFIX     ?= /opt/local
DESTDIR    ?=
STAGE       = build/stage
DIST        = dist

EMACS      ?= emacs
EMACSFLAGS  = --batch -Q
MAKEINFO   ?= makeinfo
INSTALL_INFO ?= install-info

# Étiquettes os/arch des artefacts « programs » (mêmes conventions que
# clautolisp : linux/darwin/windows, x86-64/arm64/arm32/x86).
REL_OS   := $(shell uname | tr 'A-Z' 'a-z' | sed -e 's/^mingw.*/windows/' -e 's/^msys.*/windows/' -e 's/^cygwin.*/windows/')
REL_ARCH := $(shell uname -m | tr 'A-Z' 'a-z' \
                | sed -e 's/^x86_64$$/x86-64/' -e 's/^amd64$$/x86-64/' \
                      -e 's/^aarch64$$/arm64/' -e 's/^armv7l$$/arm32/' \
                      -e 's/^armv6l$$/arm32/'  -e 's/^i[3456]86$$/x86/')

# ---------------------------------------------------------------------
# Ce que la version 1.9.0 publie.
# ---------------------------------------------------------------------

# Bibliothèques : les systèmes ALPM installés sous share/autolisp/.
# (autolisp-defstruct n'est pas implémenté, autolisp-script est
#  déprécié, autolisp-macro n'est pas un système : aucun n'est publié.)
LIBRARY_SYSTEMS = \
	autolisp-algetypes \
	autolisp-doc \
	autolisp-formatter \
	autolisp-hash-table \
	autolisp-introspection \
	autolisp-json \
	autolisp-misc \
	autolisp-test \
	autolisp-vector

# Programmes : les sous-projets qui produisent un exécutable.
PROGRAM_SUBPROJECTS = dwg-identifier

# Documentation : un manuel par système publié et par programme.
DOC_COMPONENTS = $(LIBRARY_SYSTEMS) $(PROGRAM_SUBPROJECTS)

DOCDIR      = share/doc/$(PROJECT)
MANIFESTDIR = $(DOCDIR)

# Le hook de versions du manifeste ne doit lister que ce qui est publié.
export RELEASED_SYSTEMS = $(LIBRARY_SYSTEMS)
MANIFEST_ENV = MANIFEST_PROJECT=$(PROJECT) \
               MANIFEST_VERSIONS_CMD=scripts/manifest-versions.sh \
               RELEASED_SYSTEMS="$(LIBRARY_SYSTEMS)"

.PHONY: help all \
	build build-libraries build-programs build-documentation \
	stage stage-libraries stage-programs stage-documentation \
	install install-libraries install-programs install-documentation \
	release release-libraries release-programs release-documentation \
	release-sources uninstall check-versions \
	test test-ci test-clautolisp test-bricscad test-autocad benchmark \
	docs-pdf clean

help:  ## Affiche ce message (les cibles et ce qu'elles font).
	@awk 'BEGIN { FS = ":.*?## "; printf "Usage: make <cible>\n\n" } \
	  /^[a-zA-Z_][a-zA-Z0-9_-]*:.*?## / { printf "  %-24s %s\n", $$1, $$2 }' \
	  $(MAKEFILE_LIST)
	@echo ""
	@echo "  PROJECT=$(PROJECT)  VERSION=$(VERSION)"
	@echo "  PREFIX=$(PREFIX)  DESTDIR=$(DESTDIR)"
	@echo "  cible programs : $(REL_OS)/$(REL_ARCH)"

all: build  ## Construit toutes les phases.

# La documentation est la phase lente (Emacs + TeX) : `build' global
# construit les bibliothèques et les programmes, pas les manuels.
build: build-libraries build-programs  ## Construit bibliothèques et programmes (pas la doc, lente).

# ---------------------------------------------------------------------
# Macros de build-rules.md (B3, B4).
# ---------------------------------------------------------------------

define stage-as-user
if [ "$$(id -u)" != 0 ]; then \
  $(MAKE) $(1) PREFIX="$(PREFIX)" ; \
elif [ -n "$(SUDO_USER)" ] && [ "$(SUDO_USER)" != root ]; then \
  echo "==> staging sous $(SUDO_USER) (on abandonne root pour la moitié qui compile)" ; \
  sudo -H -u "$(SUDO_USER)" $(MAKE) $(1) PREFIX="$(PREFIX)" ; \
else \
  echo "ATTENTION: root sans SUDO_USER ; $(1) va compiler avec les droits root" ; \
  echo "           et laisser des fichiers root dans l'arbre source." ; \
  $(MAKE) $(1) PREFIX="$(PREFIX)" ; \
fi
endef

# tar plutôt que cp : les liens symboliques et les modes doivent
# survivre, et la copie doit fusionner dans un préfixe existant.
define copy-stage
dest="$(DESTDIR)$(PREFIX)" ; \
[ -n "$$dest" ] || { echo "install: PREFIX et DESTDIR sont tous deux vides" >&2 ; exit 1 ; } ; \
[ -d "$(1)" ]   || { echo "install: l'aire de staging $(1) est absente" >&2 ; exit 1 ; } ; \
install -d "$$dest" ; \
tar -C "$(1)" -cf - $(2) . | tar -C "$$dest" --no-same-owner -xf - ; \
echo "installé : $(1)/ -> $$dest/"
endef

# Le manifeste de provenance (B8), écrit au moment du staging pour
# qu'il atteigne $PREFIX par la copie ordinaire et les artefacts de
# release gratuitement.
define stage-manifest
install -d "$(1)/$(MANIFESTDIR)" ; \
$(MANIFEST_ENV) sh scripts/make-manifest.sh $(2) > "$(1)/$(MANIFESTDIR)/manifest-$(2).txt"
endef

# Un artefact = un .tar.bz2 ET un .zip du même arbre staged : les
# utilisateurs Windows n'ont ni tar ni bzip2 sous la main.
#   $(1) répertoire staged   $(2) nom de l'artefact (sans extension)
define package-stage
mkdir -p $(DIST) ; \
[ -d "$(1)" ] || { echo "release: l'aire de staging $(1) est absente" >&2 ; exit 1 ; } ; \
tar -C "$(1)" -cjf "$(DIST)/$(2).tar.bz2" . ; \
( cd "$(1)" && zip -q -r -X "$(CURDIR)/$(DIST)/$(2).zip" . ) ; \
echo "$(DIST)/$(2).tar.bz2" ; \
echo "$(DIST)/$(2).zip"
endef

# ---------------------------------------------------------------------
# Phase « libraries » : les systèmes ALPM.
# ---------------------------------------------------------------------
#
# Un système ALPM est du source AutoLISP : il n'y a rien à compiler, la
# phase build est donc vide. Le staging reproduit sous share/autolisp/
# la structure que l'ALPM attend d'un répertoire enregistré —
#   <racine>/<nom>/<nom>.alpm   et l'ombrelle <racine>/outils-autolisp.alpm
# — de sorte qu'il suffit d'enregistrer $PREFIX/share/autolisp pour que
# (alpm-load-system "autolisp-vector") fonctionne.

build-libraries:  ## (rien à compiler : les systèmes ALPM sont du source AutoLISP).
	@echo "libraries: source AutoLISP, rien à compiler."

stage-libraries:  ## Dispose share/autolisp/<système>/ sous $(STAGE)/libraries/.
	rm -rf $(STAGE)/libraries
	install -d $(STAGE)/libraries/share/autolisp
	install -m 644 outils-autolisp.alpm $(STAGE)/libraries/share/autolisp/
	@set -e ; for s in $(LIBRARY_SYSTEMS) ; do \
	  echo "  $$s" ; \
	  install -d $(STAGE)/libraries/share/autolisp/$$s ; \
	  install -m 644 $$s/$$s.alpm $(STAGE)/libraries/share/autolisp/$$s/ ; \
	  [ -f $$s/$$s.ergo ] && install -m 644 $$s/$$s.ergo $(STAGE)/libraries/share/autolisp/$$s/ || true ; \
	  if [ -d $$s/src ] ; then \
	    install -d $(STAGE)/libraries/share/autolisp/$$s/src ; \
	    install -m 644 $$s/src/*.lsp $(STAGE)/libraries/share/autolisp/$$s/src/ ; \
	  fi ; \
	  for f in $$s/*.lsp ; do \
	    [ -f "$$f" ] && install -m 644 "$$f" $(STAGE)/libraries/share/autolisp/$$s/ || true ; \
	  done ; \
	done
	@$(call stage-manifest,$(STAGE)/libraries,libraries)
	@echo "staged: $(STAGE)/libraries"

install-libraries:  ## Installe share/autolisp/ dans $(DESTDIR)$(PREFIX) (ne compile rien).
	@$(call stage-as-user,stage-libraries)
	@$(call copy-stage,$(STAGE)/libraries)

# ---------------------------------------------------------------------
# Phase « programs » : dwg-identify.
# ---------------------------------------------------------------------
#
# La construction est déléguée au sous-projet (qui connaît sa
# dépendance système clautolisp) ; le staging et l'installation sont
# faits ici, sur l'arbre staged unique.

build-programs:  ## Construit les exécutables (dwg-identify, image SBCL).
	@set -e ; for d in $(PROGRAM_SUBPROJECTS) ; do \
	  echo "== $$d (build) ==" ; \
	  $(MAKE) -C $$d build ; \
	done

stage-programs:  ## Dispose bin/ sous $(STAGE)/programs/.
	$(MAKE) build-programs
	rm -rf $(STAGE)/programs
	install -d $(STAGE)/programs/bin
	install -m 755 dwg-identifier/bin/dwg-identify $(STAGE)/programs/bin/dwg-identify
	@$(call stage-manifest,$(STAGE)/programs,programs)
	@echo "staged: $(STAGE)/programs"

install-programs:  ## Installe bin/ dans $(DESTDIR)$(PREFIX) (ne compile rien).
	@$(call stage-as-user,stage-programs)
	@$(call copy-stage,$(STAGE)/programs)

# ---------------------------------------------------------------------
# Phase « documentation » : un manuel par composant, en quatre formats.
# ---------------------------------------------------------------------
#
# Source unique : <composant>/docs/<composant>--manual.org. On en tire
#
#   .pdf                 par l'export LaTeX d'org (lecture, impression)
#   .info                par makeinfo (lecture dans Emacs / info)
#   --manual.html        page unique (lecture en ligne, impression)
#   html/                une page par section, avec navigation et index
#
# Les trois derniers passent par le MÊME .texi produit par org : les
# formats Info et HTML sont donc structurellement identiques, et les
# renvois d'un manuel à l'autre fonctionnent.
#
# Le nom du fichier Info est <composant>.info et NON
# <composant>--manual.info : l'entrée `dir' produite par
# #+TEXINFO_DIR_TITLE pointe sur (<composant>), donc `info <composant>'
# doit trouver ce nom-là. C'est pourquoi le .texi est exporté par org
# puis passé à makeinfo à la main (#+TEXINFO_FILENAME fixe
# @setfilename ; l'export Info d'org, lui, exigerait le nom de base du
# fichier org).

DOC_BUILD = build/doc

doc-pdfs    = $(foreach c,$(DOC_COMPONENTS),$(DOC_BUILD)/$(c)/$(c)--manual.pdf)
doc-infos   = $(foreach c,$(DOC_COMPONENTS),$(DOC_BUILD)/$(c)/$(c).info)
doc-htmls   = $(foreach c,$(DOC_COMPONENTS),$(DOC_BUILD)/$(c)/$(c)--manual.html)
doc-paged   = $(foreach c,$(DOC_COMPONENTS),$(DOC_BUILD)/$(c)/html/index.html)

# Règles par composant. org exporte à côté du fichier source, donc on
# travaille sur une copie dans build/doc/<composant>/.
define doc-component-rules

$(DOC_BUILD)/$(1)/$(1)--manual.org: $(1)/docs/$(1)--manual.org
	@install -d $(DOC_BUILD)/$(1)
	cp $$< $$@

$(DOC_BUILD)/$(1)/$(1)--manual.texi: $(DOC_BUILD)/$(1)/$(1)--manual.org
	cd $(DOC_BUILD)/$(1) && $(EMACS) $(EMACSFLAGS) $(1)--manual.org \
	    --funcall org-texinfo-export-to-texinfo

$(DOC_BUILD)/$(1)/$(1).info: $(DOC_BUILD)/$(1)/$(1)--manual.texi
	cd $(DOC_BUILD)/$(1) && $(MAKEINFO) --no-split -o $(1).info $(1)--manual.texi

$(DOC_BUILD)/$(1)/$(1)--manual.html: $(DOC_BUILD)/$(1)/$(1)--manual.texi
	cd $(DOC_BUILD)/$(1) && $(MAKEINFO) --html --no-split -o $(1)--manual.html $(1)--manual.texi

$(DOC_BUILD)/$(1)/html/index.html: $(DOC_BUILD)/$(1)/$(1)--manual.texi
	rm -rf $(DOC_BUILD)/$(1)/html
	cd $(DOC_BUILD)/$(1) && $(MAKEINFO) --html -o html $(1)--manual.texi

# En cas d'échec, org ne dit que « See *Org PDF LaTeX Output* », qui
# n'existe pas en mode batch : on affiche le .log de LaTeX, seul endroit
# où figure le \usepackage introuvable ou l'erreur de syntaxe réelle.
$(DOC_BUILD)/$(1)/$(1)--manual.pdf: $(DOC_BUILD)/$(1)/$(1)--manual.org
	cd $(DOC_BUILD)/$(1) && $(EMACS) $(EMACSFLAGS) $(1)--manual.org \
	    --funcall org-latex-export-to-pdf \
	  || { echo "=== $(1)--manual.log ===" ; \
	       tail -60 $(1)--manual.log 2>/dev/null ; false ; }

endef

$(foreach c,$(DOC_COMPONENTS),$(eval $(call doc-component-rules,$(c))))

build-documentation: $(doc-pdfs) $(doc-infos) $(doc-htmls) $(doc-paged)  ## Rend chaque manuel en pdf, info, html et html paginé.
	@echo "documentation: $(words $(DOC_COMPONENTS)) manuels x 4 formats sous $(DOC_BUILD)/"

stage-documentation:  ## Dispose share/doc/outils-autolisp/ et share/info/ sous $(STAGE)/documentation/.
	$(MAKE) build-documentation
	rm -rf $(STAGE)/documentation
	install -d $(STAGE)/documentation/$(DOCDIR)
	install -d $(STAGE)/documentation/share/info
	install -m 644 README.md $(STAGE)/documentation/$(DOCDIR)/
	@set -e ; for c in $(DOC_COMPONENTS) ; do \
	  echo "  $$c" ; \
	  install -d $(STAGE)/documentation/$(DOCDIR)/$$c ; \
	  install -m 644 $$c/docs/$$c--manual.org  $(STAGE)/documentation/$(DOCDIR)/$$c/ ; \
	  install -m 644 $(DOC_BUILD)/$$c/$$c--manual.pdf  $(STAGE)/documentation/$(DOCDIR)/$$c/ ; \
	  install -m 644 $(DOC_BUILD)/$$c/$$c--manual.html $(STAGE)/documentation/$(DOCDIR)/$$c/ ; \
	  install -d $(STAGE)/documentation/$(DOCDIR)/$$c/html ; \
	  install -m 644 $(DOC_BUILD)/$$c/html/*.html $(STAGE)/documentation/$(DOCDIR)/$$c/html/ ; \
	  install -m 644 $(DOC_BUILD)/$$c/$$c.info $(STAGE)/documentation/share/info/ ; \
	done
	@$(call stage-manifest,$(STAGE)/documentation,documentation)
	@echo "staged: $(STAGE)/documentation"

# share/info/dir est un index PARTAGÉ (B5) : la copie staged ne nomme
# que nos manuels, l'installer écraserait les entrées de tous les
# autres paquets. On l'exclut de la copie et on réenregistre chaque
# manuel avec install-info contre le vrai préfixe.
install-documentation:  ## Installe les manuels et les enregistre dans share/info/dir.
	@$(call stage-as-user,stage-documentation)
	@$(call copy-stage,$(STAGE)/documentation,--exclude=./share/info/dir)
	@if command -v $(INSTALL_INFO) >/dev/null 2>&1 ; then \
	  for c in $(DOC_COMPONENTS) ; do \
	    $(INSTALL_INFO) --info-dir="$(DESTDIR)$(PREFIX)/share/info" \
	                    "$(DESTDIR)$(PREFIX)/share/info/$$c.info" || true ; \
	  done ; \
	else \
	  echo "install-info introuvable : les .info sont installés mais pas enregistrés dans share/info/dir" ; \
	fi

# ---------------------------------------------------------------------
# Global.
# ---------------------------------------------------------------------

stage: stage-libraries stage-programs stage-documentation  ## Dispose toutes les phases sous $(STAGE)/.

install: install-libraries install-programs install-documentation  ## Installe toutes les phases dans $(DESTDIR)$(PREFIX).

uninstall:  ## Retire tout ce qu'install a installé (y compris les entrées info).
	-@if command -v $(INSTALL_INFO) >/dev/null 2>&1 ; then \
	  for c in $(DOC_COMPONENTS) ; do \
	    $(INSTALL_INFO) --remove --info-dir="$(DESTDIR)$(PREFIX)/share/info" \
	                    "$(DESTDIR)$(PREFIX)/share/info/$$c.info" 2>/dev/null || true ; \
	  done ; \
	fi
	rm -f "$(DESTDIR)$(PREFIX)/bin/dwg-identify"
	rm -f "$(DESTDIR)$(PREFIX)/share/autolisp/outils-autolisp.alpm"
	@for s in $(LIBRARY_SYSTEMS) ; do \
	  rm -rf "$(DESTDIR)$(PREFIX)/share/autolisp/$$s" ; \
	done
	@for c in $(DOC_COMPONENTS) ; do \
	  rm -f "$(DESTDIR)$(PREFIX)/share/info/$$c.info" ; \
	done
	rm -rf "$(DESTDIR)$(PREFIX)/$(DOCDIR)"
	@echo "désinstallé de $(DESTDIR)$(PREFIX)"

# ---------------------------------------------------------------------
# Release.
# ---------------------------------------------------------------------
#
# Chaque artefact sort du MÊME arbre staged que l'installation (B7) :
# déballer l'artefact et installer donnent le même arbre, et les deux
# ne peuvent pas diverger. Chacun est produit en .tar.bz2 et en .zip.
#
# libraries et documentation ne contiennent aucun code binaire : leurs
# artefacts sont indépendants de la plate-forme et sont produits une
# seule fois, sur un runner Linux. programs, lui, est une image SBCL :
# son artefact porte l'os et l'architecture dans son nom.

release: release-libraries release-programs release-documentation release-sources  ## Empaquette tous les artefacts sous $(DIST)/.

release-libraries: stage-libraries  ## Empaquette les systèmes ALPM (indépendant de la plate-forme).
	@$(call package-stage,$(STAGE)/libraries,$(PROJECT)-$(VERSION)-libraries)

release-documentation: stage-documentation  ## Empaquette les manuels (indépendant de la plate-forme).
	@$(call package-stage,$(STAGE)/documentation,$(PROJECT)-$(VERSION)-documentation)

release-programs: stage-programs  ## Empaquette les exécutables pour $(REL_OS)/$(REL_ARCH).
	@$(call package-stage,$(STAGE)/programs,$(PROJECT)-$(VERSION)-programs-$(REL_OS)-$(REL_ARCH))

# Le seul artefact sans arbre staged : les fichiers suivis par git.
# Il embarque manifest-sources.txt à sa racine, que make-manifest.sh
# relit quand il tourne hors dépôt git — la provenance survit donc au
# passage par l'archive.
release-sources:  ## Empaquette les sources suivies par git (+ manifest-sources.txt).
	@mkdir -p $(DIST) build
	@$(MANIFEST_ENV) sh scripts/make-manifest.sh sources > build/manifest-sources.txt
	git archive --format=tar --prefix=$(PROJECT)-$(VERSION)/ HEAD > build/sources.tar
	tar -rf build/sources.tar --transform 's,^,$(PROJECT)-$(VERSION)/,' \
	    -C build manifest-sources.txt
	bzip2 -c build/sources.tar > $(DIST)/$(PROJECT)-$(VERSION)-sources.tar.bz2
	@rm -rf build/zip && mkdir -p build/zip
	tar -C build/zip -xf build/sources.tar
	( cd build/zip && zip -q -r -X "$(CURDIR)/$(DIST)/$(PROJECT)-$(VERSION)-sources.zip" . )
	@rm -rf build/zip build/sources.tar
	@echo "$(DIST)/$(PROJECT)-$(VERSION)-sources.tar.bz2"
	@echo "$(DIST)/$(PROJECT)-$(VERSION)-sources.zip"

check-versions:  ## Vérifie les invariants de version-rules.md sur les refs git.
	sh scripts/check-versions.sh

# ---------------------------------------------------------------------
# Tests et benchmarks (inchangés).
# ---------------------------------------------------------------------
#
# Les tests utilisent clautolisp / alfe (autolisp-script/autolisp est
# déprécié). Chaque sous-projet fournit test / test-ci / test-clautolisp
# (cf. makefiles/common.mk).

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

# CI / headless : clautolisp pour les libs. (autolisp-script est déprécié.)
test-ci: test-clautolisp  ## Suites headless (CI) : clautolisp.

# Cibles agrégées par moteur (un seul appel lance toute la matrice de
# sous-projets) — utilisées par les jobs CI « un clic » macOS/Windows.
test-clautolisp:  ## Lance toutes les suites sous clautolisp.
	@for d in $(TEST_SUBPROJECTS); do \
		echo "== $$d (clautolisp) =="; \
		$(MAKE) -C $$d test-clautolisp || exit 1; \
	done

test-bricscad:  ## Lance les suites CAO sous BricsCAD (via alfe).
	@for d in $(CAD_SUBPROJECTS); do \
		echo "== $$d (bricscad) =="; \
		$(MAKE) -C $$d test-bricscad || exit 1; \
	done

test-autocad:  ## Lance les suites CAO sous AutoCAD (via alfe).
	@for d in $(CAD_SUBPROJECTS); do \
		echo "== $$d (autocad) =="; \
		$(MAKE) -C $$d test-autocad || exit 1; \
	done

# Local : chaque sous-projet choisit ses moteurs selon uname (clautolisp + CAO).
test:  ## Lance les suites avec les moteurs disponibles sur cette machine.
	@for d in $(TEST_SUBPROJECTS); do \
		echo "== $$d =="; \
		$(MAKE) -C $$d test || exit 1; \
	done

# Benchmark de vitesse agrégé (structure vs liste/a-list). Résultats sur stdout
# ET dans le fichier artefact benchmark-results.txt.
#   make benchmark BACKEND=clautolisp|bricscad|autocad
benchmark:  ## Benchmark agrégé (structure vs liste/a-list) -> benchmark-results.txt.
	@rm -f benchmark-results.txt
	@for d in $(BENCH_SUBPROJECTS); do \
		echo "== $$d (benchmark, BACKEND=$(BACKEND)) =="; \
		$(MAKE) -C $$d benchmark BACKEND=$(BACKEND) BENCH_OUTFILE=$(CURDIR)/$$d-benchmark.txt || exit 1; \
		cat $(CURDIR)/$$d-benchmark.txt >> benchmark-results.txt; \
	done
	@echo "=== benchmark-results.txt ==="; cat benchmark-results.txt

# Compatibilité : ancien nom de la génération des PDF.
docs-pdf: $(doc-pdfs)  ## (obsolète) Alias : ne rend que les PDF des manuels.

clean:  ## Supprime build/ et dist/, puis nettoie les sous-projets.
	rm -rf build $(DIST)
	@for d in $(TEST_SUBPROJECTS) autolisp-script dwg-identifier; do \
		$(MAKE) -C $$d clean || exit 1; \
	done
