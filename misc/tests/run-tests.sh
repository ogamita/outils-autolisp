#!/usr/bin/env bash
# run-tests.sh --- lance les tests du sous-projet `misc`.
#
# Invoque `../autolisp-script/autolisp` sur les scripts de test du
# sous-projet `misc` depuis la racine du dépôt outils-autolisp (afin
# que les chemins relatifs `misc/src/…` présents dans les scripts se
# résolvent) puis vérifie dans chaque sortie capturée la présence du
# marqueur `TESTS OK`.
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

tests=(
  "misc/tests/fs-tests.lsp"
  "misc/tests/format-tests.lsp"
)

cd "$OUTILS_ROOT"

for test_script in "${tests[@]}"; do
  test_name="$(basename "$test_script" .lsp)"
  echo "misc/$test_name RUN args=$*"
  run_script="$test_script"

  if [[ "$test_script" == "misc/tests/format-tests.lsp" ]]; then
    run_script="$tmpdir/$test_name-wrapper.lsp"
    cat >"$run_script" <<'EOF'
(load "misc/src/format.lsp")
(load "misc/tests/format-tests.lsp")
EOF
  fi

  set +e
  "$AUTOLISP" "$@" "$run_script" \
    >"$tmpdir/$test_name.stdout.log" 2>"$tmpdir/$test_name.stderr.log"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    echo "misc/$test_name KO (autolisp rc=$rc)" >&2
    [[ -s "$tmpdir/$test_name.stdout.log" ]] && { echo "--- stdout ---" >&2; cat "$tmpdir/$test_name.stdout.log" >&2; }
    [[ -s "$tmpdir/$test_name.stderr.log" ]] && { echo "--- stderr ---" >&2; cat "$tmpdir/$test_name.stderr.log" >&2; }
    exit "$rc"
  fi

  if grep -Eq '^[[:space:]]*TESTS OK[[:space:]]*$' "$tmpdir/$test_name.stdout.log"; then
    echo "misc/$test_name OK"
  else
    echo "misc/$test_name KO (marqueur 'TESTS OK' absent)" >&2
    [[ -s "$tmpdir/$test_name.stdout.log" ]] && { echo "--- stdout ---" >&2; cat "$tmpdir/$test_name.stdout.log" >&2; }
    [[ -s "$tmpdir/$test_name.stderr.log" ]] && { echo "--- stderr ---" >&2; cat "$tmpdir/$test_name.stderr.log" >&2; }
    exit 1
  fi
done
