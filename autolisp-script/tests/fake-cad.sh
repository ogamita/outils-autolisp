#!/usr/bin/env bash
set -euo pipefail

PROFILE_NAME="${AUTOLISP_FAKE_EXPECT_PROFILE:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -P)
      if [[ $# -lt 2 ]]; then
        echo "fake-cad: missing value after -P" >&2
        exit 2
      fi
      ACTUAL_PROFILE="$2"
      shift 2
      ;;
    /b)
      if [[ $# -lt 2 ]]; then
        echo "fake-cad: missing value after /b" >&2
        exit 2
      fi
      RUNLSPFILE="$2"
      shift 2
      ;;
    /B|-b)
      if [[ $# -lt 2 ]]; then
        echo "fake-cad: missing value after $1" >&2
        exit 2
      fi
      SCRFILE="$2"
      if [[ ! -f "$SCRFILE" ]]; then
        echo "fake-cad: SCRFILE not found: $SCRFILE" >&2
        exit 2
      fi
      RUNLSPFILE="$(tr -d '\r' <"$SCRFILE" | sed -n 's/^(load "\(.*\)")/\1/p' | head -n 1)"
      if [[ -z "$RUNLSPFILE" || ! -f "$RUNLSPFILE" ]]; then
        echo "fake-cad: could not resolve run-common.lsp from $SCRFILE" >&2
        exit 2
      fi
      shift 2
      ;;
    *)
      echo "fake-cad: unexpected argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${RUNLSPFILE:-}" ]]; then
  echo "fake-cad: expected '/b <run-common.lsp>', '/B <run.scr>' or '-b <run.scr>'" >&2
  exit 2
fi

if [[ -n "$PROFILE_NAME" && "${ACTUAL_PROFILE:-}" != "$PROFILE_NAME" ]]; then
  echo "fake-cad: expected profile '$PROFILE_NAME', got '${ACTUAL_PROFILE:-}'" >&2
  exit 2
fi
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

require_scr_contains() {
  local needle="$1"
  if [[ -z "${SCRFILE:-}" ]]; then
    printf 'fake-cad: SCRFILE is not set\n' >&2
    exit 3
  fi
  if ! grep -Fq "$needle" "$SCRFILE"; then
    printf 'fake-cad: missing expected script command in %s: %s\n' "$SCRFILE" "$needle" >&2
    exit 3
  fi
}

extract_eval_form() {
  perl -0ne '
    if (/\(if \(autolisp-run-eval-file 1 "(.*)"\) \(autolisp-note-ok\) \(autolisp-note-fail\)\)/s) {
      my $path = $1;
      $path =~ s/\\"/"/g;
      $path =~ s/\\\\/\\/g;
      open my $fh, "<", $path or exit 2;
      local $/ = undef;
      print <$fh>;
      close $fh;
      exit 0;
    }
    exit 1;
  ' "$RUNLSPFILE"
}

extract_req_id() {
  sed -n '1s/^;REQ //p' "$INPFILE" | head -n 1
}

extract_input_form() {
  sed '1d' "$INPFILE" | tr -d '\r'
}

case "$SCENARIO" in
  eval_prints)
    require_runlsp_regex '\(if \(autolisp-run-eval-file 1 ".*eval-1\.lsp"\) \(autolisp-note-ok\) \(autolisp-note-fail\)\)'
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
    require_runlsp_regex '\(if \(autolisp-run-eval-file 1 ".*eval-1\.lsp"\) \(autolisp-note-ok\) \(autolisp-note-fail\)\)'
    require_runlsp_contains '(defun print (obj)'
    cat >"$OUTFILE" <<'EOF'
EVAL (+ 1 2)
RESULT 3
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    printf '0\n' >"$STATUSFILE"
    ;;
  macos_batch_quit)
    require_scr_contains '(command "_QUIT" "_Y")'
    require_runlsp_contains '(setq *AUTOLISP_QUIT_ON_FINISH* 0)'
    cat >"$OUTFILE" <<'EOF'
EVAL (+ 1 2)
RESULT 3
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    printf '0\n' >"$STATUSFILE"
    ;;
  eval_load_string)
    require_runlsp_regex '\(if \(autolisp-run-eval-file 1 ".*eval-1\.lsp"\) \(autolisp-note-ok\) \(autolisp-note-fail\)\)'
    if [[ "$(extract_eval_form)" != '(load "loader.lsp")' ]]; then
      printf 'fake-cad: expected (load "loader.lsp"), got:\n' >&2
      extract_eval_form >&2 || true
      exit 5
    fi
    cat >"$OUTFILE" <<'EOF'
EVAL (load "loader.lsp")
RESULT "loader.lsp"
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
  interactive_expr)
    case "$(extract_eval_form)" in
      "(+ 1 2)")
        cat >"$OUTFILE" <<'EOF'
EVAL (+ 1 2)
RESULT 3
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
        : >"$ERRFILE"
        printf '0\n' >"$STATUSFILE"
        ;;
      $'(progn\n  (print "Hi")\n  (* 2 5))')
        cat >"$OUTFILE" <<'EOF'
EVAL (progn
  (print "Hi")
  (* 2 5))
<<<AUTOLISP-STDOUT>>>"Hi"
RESULT 10
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
        : >"$ERRFILE"
        printf '0\n' >"$STATUSFILE"
        ;;
      "(/ 1 0)")
        cat >"$OUTFILE" <<'EOF'
EVAL (/ 1 0)
TOTAL=1 OK=0 FAIL=1 ERROR=0
EOF
        cat >"$ERRFILE" <<'EOF'
ERROR eval (/ 1 0): divide by zero
EOF
        printf '1\n' >"$STATUSFILE"
        ;;
      *)
        printf 'fake-cad: unexpected interactive expression in %s:\n' "$RUNLSPFILE" >&2
        extract_eval_form >&2 || true
        exit 5
        ;;
    esac
    ;;
  interactive_batch)
    if [[ "${INPFILE:-}" == "" ]]; then
      echo "fake-cad: missing INPFILE for interactive batch" >&2
      exit 5
    fi
    require_runlsp_contains '(setq *AUTOLISP_INPFILE*'
    printf 'READY 0\n' >"$STATUSFILE"
    while true; do
      while [[ ! -f "$INPFILE" ]]; do
        sleep 0.05
      done
      req_id="$(extract_req_id)"
      form="$(extract_input_form)"
      case "$form" in
        "(+ 1 2)")
          cat >"$OUTFILE" <<'EOF'
EVAL (+ 1 2)
RESULT 3
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
          : >"$ERRFILE"
          rm -f "$INPFILE"
          printf 'READY %s\n' "$req_id" >"$STATUSFILE"
          ;;
        $'(progn\n  (print "Hi")\n  (* 2 5))')
          cat >"$OUTFILE" <<'EOF'
EVAL (progn
  (print "Hi")
  (* 2 5))
<<<AUTOLISP-STDOUT>>>"Hi"
RESULT 10
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
          : >"$ERRFILE"
          rm -f "$INPFILE"
          printf 'READY %s\n' "$req_id" >"$STATUSFILE"
          ;;
        "(/ 1 0)")
          cat >"$OUTFILE" <<'EOF'
EVAL (/ 1 0)
TOTAL=1 OK=0 FAIL=1 ERROR=0
EOF
          cat >"$ERRFILE" <<'EOF'
ERROR eval (/ 1 0): divide by zero
EOF
          rm -f "$INPFILE"
          printf 'READY %s\n' "$req_id" >"$STATUSFILE"
          ;;
        "'__AUTOLISP_QUIT__")
          rm -f "$INPFILE"
          printf 'STOP %s\n' "$req_id" >"$STATUSFILE"
          exit 0
          ;;
        *)
          printf 'fake-cad: unexpected interactive batch form:\n%s\n' "$form" >&2
          exit 5
          ;;
      esac
    done
    ;;
  *)
    printf 'fake-cad: unknown AUTOLISP_FAKE_SCENARIO: %s\n' "$SCENARIO" >&2
    exit 4
    ;;
esac
