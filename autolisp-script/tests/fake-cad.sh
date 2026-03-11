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

require_runlsp_contains() {
  local needle="$1"
  if ! grep -Fq "$needle" "$RUNLSPFILE"; then
    printf 'fake-cad: missing expected form in %s: %s\n' "$RUNLSPFILE" "$needle" >&2
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
  *)
    printf 'fake-cad: unknown AUTOLISP_FAKE_SCENARIO: %s\n' "$SCENARIO" >&2
    exit 4
    ;;
esac
