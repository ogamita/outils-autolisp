# common.mk --- Cibles de test partagées des sous-projets outils-autolisp.
#
# (Dossier « makefiles/ » au pluriel : sur un système de fichiers insensible à
#  la casse comme macOS, « makefile/ » entrerait en collision avec « Makefile ».)
#
# Un sous-projet définit ses variables PUIS inclut ce fichier :
#
#   TEST_SUITE   = autolisp-foo                 # nom de la suite (informatif)
#   TEST_SOURCES = \                            # séquence de chargement complète
#       -l ../autolisp-test/test-framework.lsp \
#       -l src/autolisp-foo.lsp \
#       -l tests/foo-tests.lsp \
#       -l tests/run-tests.lsp
#   # CLAUTOLISP_DIALECT = lax                   # optionnel (défaut : strict)
#   include ../makefiles/common.mk
#
# Moteurs (autolisp-script/autolisp est DÉPRÉCIÉ, remplacé par alfe/clautolisp) :
#   - test-clautolisp : binaire `clautolisp` en direct, headless (CI). Le code de
#     sortie passe par (C:MAIN) -> autolisp-set-status puis (quit).
#   - test-bricscad / test-autocad : via `alfe` (bootstrap file-IPC -> STATUSFILE).
#
# On favorise `--dialect strict` (portable AutoCAD ∩ BricsCAD) ; run-tests bascule
# temporairement en lax uniquement autour de autolisp-set-status (cf. t:set-status
# dans autolisp-test/test-framework.lsp).
# Rapport JUnit (GitLab) : facultatif. Avec JUNIT_DIR=<répertoire absolu>, chaque
# cible de test écrit AUSSI $(JUNIT_DIR)/$(TEST_SUITE)-<moteur>.xml (variable
# d'environnement AUTOLISP_TEST_JUNIT lue par le framework). Sans JUNIT_DIR, rien
# ne change. Ex. :  make test-clautolisp JUNIT_DIR=$PWD/junit
# Benchmarks (vector/hash-table) : AV_RUN_BENCHMARKS / AH_RUN_BENCHMARKS=1 sur la
# cible test (les run-tests.lsp consultent ces variables d'environnement).

UNAME_S := $(shell uname -s)

CLAUTOLISP         ?= clautolisp
ALFE               ?= alfe
CLAUTOLISP_DIALECT ?= strict
TEST_MAIN          ?= -x '(C:MAIN)'

ifeq ($(UNAME_S),Linux)
TEST_TARGETS ?= test-clautolisp
else
ifeq ($(UNAME_S),Darwin)
TEST_TARGETS ?= test-clautolisp test-bricscad
else
TEST_TARGETS ?= test-clautolisp test-bricscad test-autocad
endif
endif

# Benchmark : un sous-projet définit BENCH_SOURCES (les -l à charger, le fichier
# de bench définit (C:BENCH)). Lancé via :  make benchmark BACKEND=clautolisp|bricscad|autocad
# (autolisp = alias d'autocad). Sortie sur stdout + fichier $BENCH_OUTFILE.
BACKEND       ?= clautolisp
BENCH_DIALECT ?= lax
BENCH_OUTFILE ?= $(CURDIR)/benchmark.txt

JUNIT_DIR ?=

# $(call junit-env,<moteur>) : préfixe de commande shell qui expose le dossier
# du sous-projet et, si demandé, crée JUNIT_DIR puis exporte le rapport JUnit.
# AUTOLISP_TEST_PROJECT_DIR permet aux tests exécutés par un CAD natif de
# retrouver leurs fixtures sans dépendre du répertoire courant du processus.
junit-env = $(if $(JUNIT_DIR),mkdir -p "$(JUNIT_DIR)" && )AUTOLISP_TEST_PROJECT_DIR="$(CURDIR)" $(if $(JUNIT_DIR),AUTOLISP_TEST_JUNIT="$(JUNIT_DIR)/$(TEST_SUITE)-$(1).xml")

# accoreconsole résout les -l relatifs depuis son propre répertoire et alfe
# 2.2.80 ne signale pas l'échec du LOAD. Les chemins absolus sont portables
# aussi pour BricsCAD et évitent ce faux succès AutoCAD.
CAD_TEST_SOURCES = $(subst -l ,-l $(CURDIR)/,$(TEST_SOURCES))

.PHONY: test-ci test test-clautolisp test-bricscad test-autocad benchmark

test-ci: test

test: $(TEST_TARGETS)

test-clautolisp:
	$(call junit-env,clautolisp) $(CLAUTOLISP) -norc --dialect $(CLAUTOLISP_DIALECT) -q $(TEST_SOURCES) $(TEST_MAIN) -x '(quit)'

test-bricscad:
	$(call junit-env,bricscad) $(ALFE) -norc --bricscad --mode batch -Esource UTF-8 $(CAD_TEST_SOURCES) $(TEST_MAIN) -q

test-autocad:
	$(call junit-env,autocad) $(ALFE) -norc --autocad --mode batch -Esource UTF-8 $(CAD_TEST_SOURCES) $(TEST_MAIN) -q

ifeq ($(BACKEND),clautolisp)
BENCH_CMD = $(CLAUTOLISP) --dialect $(BENCH_DIALECT) -q $(BENCH_SOURCES) -x '(C:BENCH)' -x '(quit)'
else ifeq ($(BACKEND),bricscad)
BENCH_CMD = $(ALFE) -norc --bricscad --mode batch $(BENCH_SOURCES) -x '(C:BENCH)' -q
else ifeq ($(filter $(BACKEND),autocad autolisp),$(BACKEND))
BENCH_CMD = $(ALFE) -norc --autocad --mode batch $(BENCH_SOURCES) -x '(C:BENCH)' -q
else
BENCH_CMD = @echo "BACKEND inconnu: $(BACKEND) (clautolisp|bricscad|autocad|autolisp)"; false
endif

benchmark:
	BENCH_OUTFILE="$(BENCH_OUTFILE)" $(BENCH_CMD)
