#!/usr/bin/env bash
# run-tests.sh --- lance les tests du sous-projet `autolisp-misc`.
#
# Exécute les scripts de test sous `clautolisp` (autolisp-script/autolisp est
# déprécié) depuis la racine du dépôt outils-autolisp (afin que les chemins
# relatifs `autolisp-misc/src/…` des scripts se résolvent), puis vérifie la
# présence du marqueur `TESTS OK` dans chaque sortie capturée.
#
# Réglages : CLAUTOLISP (binaire, défaut « clautolisp »),
#            CLAUTOLISP_DIALECT (défaut « strict »).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MISC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTILS_ROOT="$(cd "$MISC_ROOT/.." && pwd)"

CLAUTOLISP="${CLAUTOLISP:-clautolisp}"
DIALECT="${CLAUTOLISP_DIALECT:-strict}"

if ! command -v "$CLAUTOLISP" >/dev/null 2>&1; then
  echo "autolisp-misc/tests: clautolisp introuvable: $CLAUTOLISP" >&2
  exit 2
fi

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/autolisp-misc-tests.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

cd "$OUTILS_ROOT"

run_one() { # name  extra_load_args  script
  local name="$1" extra="$2" script="$3"
  echo "autolisp-misc/$name RUN (dialect=$DIALECT)"
  set +e
  # shellcheck disable=SC2086
  "$CLAUTOLISP" --dialect "$DIALECT" -q $extra "$script" \
    >"$tmpdir/$name.out" 2>"$tmpdir/$name.err"
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]] || ! grep -Eq '^[[:space:]]*TESTS OK[[:space:]]*$' "$tmpdir/$name.out"; then
    echo "autolisp-misc/$name KO (rc=$rc)" >&2
    [[ -s "$tmpdir/$name.out" ]] && { echo "--- stdout ---" >&2; cat "$tmpdir/$name.out" >&2; }
    [[ -s "$tmpdir/$name.err" ]] && { echo "--- stderr ---" >&2; cat "$tmpdir/$name.err" >&2; }
    exit 1
  fi
  echo "autolisp-misc/$name OK"
}

run_one fs-tests     ""                                   autolisp-misc/tests/fs-tests.lsp
run_one format-tests "-l autolisp-misc/src/format.lsp"    autolisp-misc/tests/format-tests.lsp
