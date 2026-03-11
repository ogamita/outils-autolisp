#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || "$1" != "/b" ]]; then
  echo "fake-cad: expected '/b <run-common.lsp>'" >&2
  exit 2
fi

RUNLSPFILE="$2"
SCENARIO="${AUTOLISP_FAKE_SCENARIO:-}"
OUTFILE="${OUTFILE:?missing OUTFILE}"
ERRFILE="${ERRFILE:?missing ERRFILE}"
STATUSFILE="${STATUSFILE:?missing STATUSFILE}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

require_runlsp_contains() {
  local needle="$1"
  if ! grep -Fq "$needle" "$RUNLSPFILE"; then
    printf 'fake-cad: missing expected form in %s: %s\n' "$RUNLSPFILE" "$needle" >&2
    exit 3
  fi
}

require_runlsp_regex() {
  local pattern="$1"
  if ! grep -Eq "$pattern" "$RUNLSPFILE"; then
    printf 'fake-cad: missing expected pattern in %s: %s\n' "$RUNLSPFILE" "$pattern" >&2
    exit 3
  fi
}

case "$SCENARIO" in
  eval_prints)
    require_runlsp_contains '(if (autolisp-run-eval 1 "(progn (print (quote \"Hello World\")) (print \"Hiya!\"))") (autolisp-note-ok) (autolisp-note-fail))'
    require_runlsp_contains '(defun print (obj)'
    require_runlsp_contains '(defun autolisp-stdout-prefix ()'
    cat >"$OUTFILE" <<'EOF'
EVAL (progn (print (quote "Hello World")) (print "Hiya!"))
<<<AUTOLISP-STDOUT>>>"Hello World"
<<<AUTOLISP-STDOUT>>>"Hiya!"
RESULT Hiya!
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    printf '0\n' >"$STATUSFILE"
    ;;
  eval_no_output)
    require_runlsp_contains '(if (autolisp-run-eval 1 "(+ 1 2)") (autolisp-note-ok) (autolisp-note-fail))'
    require_runlsp_contains '(defun print (obj)'
    cat >"$OUTFILE" <<'EOF'
EVAL (+ 1 2)
RESULT 3
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    printf '0\n' >"$STATUSFILE"
    ;;
  load_main_default)
    require_runlsp_regex 'autolisp-run-load 1 ".*/tests/fixtures/main-default\.lsp"'
    require_runlsp_contains '(if (= *AUTOLISP_FAIL* 0) (if (autolisp-run-main 2 "C:MAIN") (autolisp-note-ok) (autolisp-note-fail)))'
    cat >"$OUTFILE" <<EOF
LOAD $ROOT_DIR/tests/fixtures/main-default.lsp
LOADED $ROOT_DIR/tests/fixtures/main-default.lsp
MAIN C:MAIN
<<<AUTOLISP-STDOUT>>>"From MAIN"
MAIN-RESULT Done
TOTAL=2 OK=2 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    printf '0\n' >"$STATUSFILE"
    ;;
  load_main_custom)
    require_runlsp_regex 'autolisp-run-load 1 ".*/tests/fixtures/main-custom\.lsp"'
    require_runlsp_contains '(if (= *AUTOLISP_FAIL* 0) (if (autolisp-run-main 2 "C:RUN_BASIC") (autolisp-note-ok) (autolisp-note-fail)))'
    cat >"$OUTFILE" <<EOF
LOAD $ROOT_DIR/tests/fixtures/main-custom.lsp
LOADED $ROOT_DIR/tests/fixtures/main-custom.lsp
MAIN C:RUN_BASIC
<<<AUTOLISP-STDOUT>>>"From custom main"
MAIN-RESULT 7
TOTAL=2 OK=2 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    printf '0\n' >"$STATUSFILE"
    ;;
  load_side_effect)
    require_runlsp_regex 'autolisp-run-load 1 ".*/tests/fixtures/load-side-effect\.lsp"'
    require_runlsp_contains '(if (= *AUTOLISP_FAIL* 0) (if (autolisp-run-main 2 "C:MAIN") (autolisp-note-ok) (autolisp-note-fail)))'
    cat >"$OUTFILE" <<EOF
LOAD $ROOT_DIR/tests/fixtures/load-side-effect.lsp
<<<AUTOLISP-STDOUT>>>"Loaded fixture"
LOADED $ROOT_DIR/tests/fixtures/load-side-effect.lsp
MAIN C:MAIN
MAIN-RESULT OK
TOTAL=2 OK=2 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    printf '0\n' >"$STATUSFILE"
    ;;
  *)
    printf 'fake-cad: unknown AUTOLISP_FAKE_SCENARIO: %s\n' "$SCENARIO" >&2
    exit 4
    ;;
esac
