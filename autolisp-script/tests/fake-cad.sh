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
    /B|-B|-b)
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
    *.lsp)
      RUNLSPFILE="$1"
      if [[ ! -f "$RUNLSPFILE" ]]; then
        echo "fake-cad: RUNLSPFILE not found: $RUNLSPFILE" >&2
        exit 2
      fi
      shift
      ;;
    *)
      echo "fake-cad: unexpected argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${RUNLSPFILE:-}" ]]; then
  echo "fake-cad: expected '/b <run-common.lsp>', '/B <run.scr>', '-b <run.scr>' or '<run-common.lsp>'" >&2
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

if [[ -n "${AUTOLISP_FAKE_INVOCATION_FILE:-}" ]]; then
  printf '%s\n' "$RUNLSPFILE" >>"$AUTOLISP_FAKE_INVOCATION_FILE"
fi

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
  local source_file="${1:-$RUNLSPFILE}"
  perl -0ne '
    if (/\(if \(autolisp-run-eval-file 1 "(.*)"\) \(autolisp-note-ok\) \(autolisp-note-fail\)\)/s) {
      my $path = $1;
      $path =~ s/\\"/"/g;
      $path =~ s/\\\\/\\/g;
      open my $fh, "<", $path or exit 2;
      local $/ = undef;
      my $data = <$fh>;
      $data =~ s/\r//g;
      print $data;
      close $fh;
      exit 0;
    }
    exit 1;
  ' "$source_file"
}

extract_req_id() {
  sed -n '1s/^;REQ //p' "$INPFILE" | head -n 1
}

extract_input_form() {
  sed '1d' "$INPFILE" | tr -d '\r'
}

extract_protocol_request_file() {
  perl -0ne '
    if (/\(load "(.*)"\)/s) {
      my $path = $1;
      $path =~ s/\\"/"/g;
      $path =~ s/\\\\/\\/g;
      print $path;
      exit 0;
    }
    exit 1;
  ' "$1"
}

protocol_finish_request() {
  local req_id="$1"
  local rc="$2"
  printf '%s\n' "$rc" >"$STATUSFILE"
  if [[ "$rc" -eq 0 ]]; then
    printf 'DONE %s OK\n' "$req_id" >"$AUTOLISP_PROTOCOL_STATUSFILE"
  else
    printf 'DONE %s FAIL\n' "$req_id" >"$AUTOLISP_PROTOCOL_STATUSFILE"
  fi
}

protocol_emit_eval_result() {
  local form="$1"
  case "$form" in
    "(+ 1 2)")
      cat >"$OUTFILE" <<'EOF'
EVAL (+ 1 2)
RESULT 3
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
      : >"$ERRFILE"
      return 0
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
      return 0
      ;;
    "(progn (print (quote \"Hello World\")) (print \"Hiya!\"))")
      cat >"$OUTFILE" <<'EOF'
EVAL (progn (print (quote "Hello World")) (print "Hiya!"))
<<<AUTOLISP-STDOUT>>>"Hello World"
<<<AUTOLISP-STDOUT>>>"Hiya!"
RESULT Hiya!
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
      : >"$ERRFILE"
      return 0
      ;;
    '(load "loader.lsp")')
      cat >"$OUTFILE" <<'EOF'
EVAL (load "loader.lsp")
RESULT "loader.lsp"
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
      : >"$ERRFILE"
      return 0
      ;;
    "(/ 1 0)")
      cat >"$OUTFILE" <<'EOF'
EVAL (/ 1 0)
TOTAL=1 OK=0 FAIL=1 ERROR=0
EOF
      cat >"$ERRFILE" <<'EOF'
ERROR eval (/ 1 0): divide by zero
EOF
      return 1
      ;;
    "(quit)")
      : >"$OUTFILE"
      : >"$ERRFILE"
      return 88
      ;;
  esac

  printf 'fake-cad: unexpected protocol eval form:\n%s\n' "$form" >&2
  return 5
}

protocol_emit_load_result() {
  local request_file="$1"
  if grep -Eq 'autolisp-run-load 1 ".*/tests/fixtures/main-default\.lsp"' "$request_file"; then
    cat >"$OUTFILE" <<EOF
LOAD $ROOT_DIR/tests/fixtures/main-default.lsp
LOADED $ROOT_DIR/tests/fixtures/main-default.lsp
MAIN C:MAIN
<<<AUTOLISP-STDOUT>>>"From MAIN"
MAIN-RESULT Done
TOTAL=2 OK=2 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    return 0
  fi

  if grep -Eq 'autolisp-run-load 1 ".*/tests/fixtures/main-custom\.lsp"' "$request_file"; then
    cat >"$OUTFILE" <<EOF
LOAD $ROOT_DIR/tests/fixtures/main-custom.lsp
LOADED $ROOT_DIR/tests/fixtures/main-custom.lsp
MAIN C:RUN_BASIC
<<<AUTOLISP-STDOUT>>>"From custom main"
MAIN-RESULT 7
TOTAL=2 OK=2 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    return 0
  fi

  if grep -Eq 'autolisp-run-load 1 ".*/tests/fixtures/load-side-effect\.lsp"' "$request_file"; then
    cat >"$OUTFILE" <<EOF
LOAD $ROOT_DIR/tests/fixtures/load-side-effect.lsp
<<<AUTOLISP-STDOUT>>>"Loaded fixture"
LOADED $ROOT_DIR/tests/fixtures/load-side-effect.lsp
MAIN C:MAIN
MAIN-RESULT OK
TOTAL=2 OK=2 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    return 0
  fi

  printf 'fake-cad: unexpected protocol load request in %s\n' "$request_file" >&2
  return 5
}

run_protocol_batch() {
  local req_id=0 stdin_file request_file eval_form control rc stdin_payload stop_after_request

  require_scr_contains '._COMMANDLINE'
  require_scr_contains '._QUIT _Y'
  require_runlsp_contains '(setq *AUTOLISP_USE_REMOTE_PROTOCOL* 1)'
  require_runlsp_contains '(defun autolisp-request-reset ()'
  require_runlsp_contains '(load *AUTOLISP_PROTOCOL_RUNTIMEFILE*)'

  printf 'READY 0\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
  printf '99\n' >"$STATUSFILE"

  while true; do
    if [[ -f "$AUTOLISP_PROTOCOL_CONTROLFILE" ]]; then
      control="$(tr -d '\r' <"$AUTOLISP_PROTOCOL_CONTROLFILE")"
      rm -f "$AUTOLISP_PROTOCOL_CONTROLFILE"
      case "$control" in
        PING)
          : >"$AUTOLISP_PROTOCOL_HEARTBEATFILE"
          ;;
        SHUTDOWN)
          printf 'STOPPING\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
          printf 'STOPPED\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
          exit 0
          ;;
      esac
    fi

    stdin_file="${AUTOLISP_PROTOCOL_STDINFILE:-}"
    if [[ -n "$stdin_file" && -f "$stdin_file" ]]; then
      req_id=$((req_id + 1))
      printf 'RUNNING %s\n' "$req_id" >"$AUTOLISP_PROTOCOL_STATUSFILE"
      stdin_payload="$(tr -d '\r' <"$stdin_file")"
      stop_after_request=0
      if grep -Fq '*AUTOLISP_PROTOCOL_STOP*' <<<"$stdin_payload"; then
        stop_after_request=1
      fi
      request_file="$(extract_protocol_request_file "$stdin_file" || true)"
      rm -f "$stdin_file"
      if [[ -z "$request_file" || ! -f "$request_file" ]]; then
        echo "fake-cad: invalid protocol request file" >&2
        exit 5
      fi

      if grep -Eq 'autolisp-run-eval-file 1 ".*\.lsp"' "$request_file"; then
        eval_form="$(extract_eval_form "$request_file")"
        if protocol_emit_eval_result "$eval_form"; then
          rc=0
        else
          rc=$?
        fi
        if [[ "$rc" -eq 88 ]]; then
          printf '0\n' >"$STATUSFILE"
          printf 'DONE %s QUIT\n' "$req_id" >"$AUTOLISP_PROTOCOL_STATUSFILE"
          printf 'STOPPED\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
          exit 0
        fi
        protocol_finish_request "$req_id" "$rc"
      elif grep -Eq 'autolisp-run-load 1 ".*tests/fixtures/' "$request_file"; then
        if protocol_emit_load_result "$request_file"; then
          rc=0
        else
          rc=$?
        fi
        protocol_finish_request "$req_id" "$rc"
      else
        echo "fake-cad: unsupported protocol request" >&2
        exit 5
      fi
      if [[ "$stop_after_request" -eq 1 ]]; then
        printf 'STOPPED\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
        exit 0
      fi
      continue
    fi

    sleep 0.05
  done
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
    require_scr_contains '._COMMANDLINE'
    require_scr_contains '._QUIT _Y'
    require_runlsp_contains '(setq *AUTOLISP_QUIT_ON_FINISH* 1)'
    cat >"$OUTFILE" <<'EOF'
EVAL (+ 1 2)
RESULT 3
TOTAL=1 OK=1 FAIL=0 ERROR=0
EOF
    : >"$ERRFILE"
    printf '0\n' >"$STATUSFILE"
    ;;
  protocol_batch)
    run_protocol_batch
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
