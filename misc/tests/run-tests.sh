#!/usr/bin/env bash
# run-tests.sh --- lance les tests du sous-projet `misc`.
#
# Invoque `../autolisp-script/autolisp` sur `misc/tests/fs-tests.lsp`
# depuis la racine du dépôt outils-autolisp (afin que les chemins
# relatifs `misc/src/…` présents dans le script de test se résolvent)
# puis vérifie dans la sortie capturée la présence du marqueur
# `TESTS OK` produit par `fs-tests.lsp`.
#
# Les arguments passés à ce script (par exemple `--bricscad`, `--mode
# batch`, `--timeout 60`) sont transmis tels quels à `autolisp`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MISC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTILS_ROOT="$(cd "$MISC_ROOT/.." && pwd)"
AUTOLISP="$OUTILS_ROOT/autolisp-script/autolisp"

if [[ ! -x "$AUTOLISP" ]]; then
  echo "misc/tests: autolisp introuvable ou non exécutable: $AUTOLISP" >&2
  exit 2
fi

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/misc-fs-tests.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

echo "misc/fs-tests RUN args=$*"

cd "$OUTILS_ROOT"

set +e
"$AUTOLISP" "$@" misc/tests/fs-tests.lsp \
  >"$tmpdir/stdout.log" 2>"$tmpdir/stderr.log"
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  echo "misc/fs-tests KO (autolisp rc=$rc)" >&2
  [[ -s "$tmpdir/stdout.log" ]] && { echo "--- stdout ---" >&2; cat "$tmpdir/stdout.log" >&2; }
  [[ -s "$tmpdir/stderr.log" ]] && { echo "--- stderr ---" >&2; cat "$tmpdir/stderr.log" >&2; }
  exit "$rc"
fi

if grep -Eq '^[[:space:]]*TESTS OK[[:space:]]*$' "$tmpdir/stdout.log"; then
  echo "misc/fs-tests OK"
  exit 0
fi

echo "misc/fs-tests KO (marqueur 'TESTS OK' absent)" >&2
[[ -s "$tmpdir/stdout.log" ]] && { echo "--- stdout ---" >&2; cat "$tmpdir/stdout.log" >&2; }
[[ -s "$tmpdir/stderr.log" ]] && { echo "--- stderr ---" >&2; cat "$tmpdir/stderr.log" >&2; }
exit 1
