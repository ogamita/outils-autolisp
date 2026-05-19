#!/usr/bin/env bash
#
# test-autocad-com.sh -- smoke test manuel du pont COM AutoCAD (Windows).
#
# Windows-only, AutoCAD installe, execution manuelle. NE PAS brancher
# dans la cible CI : le test ouvre une fenetre acad.exe visible et n'a
# de sens que sur une station equipee.
#
# Verifie que :
#   1. cscript.exe est disponible ;
#   2. AUTOCAD_EXE est defini ou trouvable, ou le registre COM declare
#      AutoCAD.Application via HKCR\AutoCAD.Application\CurVer ;
#   3. `autolisp --autocad --mode automation -x '(princ "hello-from-autocad-com")' --quit`
#      sort en 0 et stdout contient la chaine attendue ;
#   4. (optionnel, si --with-attach passe) une seconde execution avec
#      --mode automation --backend attach reussit.
#
# Usage:
#   tests/test-autocad-com.sh           # mode launch (cree une instance)
#   tests/test-autocad-com.sh --with-attach   # ajoute le test d'attache

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOLISP="$ROOT_DIR/autolisp"

WITH_ATTACH=0
for arg in "$@"; do
  case "$arg" in
    --with-attach) WITH_ATTACH=1 ;;
    *) echo "Unknown argument: $arg" >&2 ; exit 2 ;;
  esac
done

skip() {
  echo "SKIP: $*" >&2
  exit 77
}

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *) skip "Windows-only test (current platform: $(uname -s))." ;;
esac

cscript_path=""
if command -v cscript >/dev/null 2>&1; then
  cscript_path="$(command -v cscript)"
elif [[ -x /c/Windows/System32/cscript.exe ]]; then
  cscript_path="/c/Windows/System32/cscript.exe"
fi
[[ -n "$cscript_path" ]] || skip "cscript.exe introuvable."

autocad_found=0
if [[ -n "${AUTOCAD_EXE:-}" && -f "${AUTOCAD_EXE}" ]]; then
  autocad_found=1
elif compgen -G "/c/Program Files/Autodesk/AutoCAD */acad.exe" >/dev/null 2>&1; then
  autocad_found=1
elif command -v reg.exe >/dev/null 2>&1 \
     && reg.exe query 'HKCR\AutoCAD.Application\CurVer' >/dev/null 2>&1; then
  autocad_found=1
fi
[[ "$autocad_found" -eq 1 ]] || skip "AutoCAD non detecte (ni AUTOCAD_EXE, ni install par defaut, ni ProgID dans le registre)."

run_smoke() {
  local label="$1"
  shift
  echo "=== $label ==="
  local stdout_file stderr_file rc
  stdout_file="$(mktemp -t autolisp-com-out-XXXXXX)"
  stderr_file="$(mktemp -t autolisp-com-err-XXXXXX)"
  set +e
  "$AUTOLISP" "$@" \
      -x '(princ "hello-from-autocad-com")' \
      --quit \
      >"$stdout_file" 2>"$stderr_file"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL: rc=$rc" >&2
    echo "--- stdout ---" >&2 ; cat "$stdout_file" >&2
    echo "--- stderr ---" >&2 ; cat "$stderr_file" >&2
    rm -f "$stdout_file" "$stderr_file"
    return 1
  fi
  if ! grep -q 'hello-from-autocad-com' "$stdout_file"; then
    echo "FAIL: 'hello-from-autocad-com' absent de stdout" >&2
    echo "--- stdout ---" >&2 ; cat "$stdout_file" >&2
    rm -f "$stdout_file" "$stderr_file"
    return 1
  fi
  echo "OK"
  rm -f "$stdout_file" "$stderr_file"
}

run_smoke "Smoke: --autocad --mode automation (launch par defaut)" \
  --autocad --mode automation

if [[ "$WITH_ATTACH" -eq 1 ]]; then
  run_smoke "Smoke: --autocad --mode automation --backend attach" \
    --autocad --mode automation --backend attach
fi

echo "All AutoCAD COM smoke tests passed."
