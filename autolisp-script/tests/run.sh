#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOLISP="$ROOT_DIR/autolisp"
FAKE_CAD="$SCRIPT_DIR/fake-cad.sh"
TMP_DIR="$SCRIPT_DIR/tmp"

OS="$(uname -s || true)"
IS_WINDOWS=0
case "$OS" in
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
esac
IS_MACOS=0
case "$OS" in
  Darwin) IS_MACOS=1 ;;
esac

mkdir -p "$TMP_DIR"

VERBOSE=0
USE_FAKE_CAD=0
RUN_TIMEOUT="${TEST_TIMEOUT:-30}"
declare -a CAD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    --fake-cad)
      USE_FAKE_CAD=1
      shift
      ;;
    --timeout)
      RUN_TIMEOUT="${2:?missing value after --timeout}"
      shift 2
      ;;
    *)
      CAD_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#CAD_ARGS[@]} -eq 0 ]]; then
  CAD_ARGS=(--bricscad)
fi

ENGINE_FLAG=""
for arg in "${CAD_ARGS[@]}"; do
  case "$arg" in
    --bricscad|--autocad)
      ENGINE_FLAG="$arg"
      ;;
  esac
done

if [[ -z "$ENGINE_FLAG" ]]; then
  echo "tests/run.sh: pass --bricscad or --autocad" >&2
  exit 2
fi

case "$ENGINE_FLAG" in
  --bricscad) ENGINE_EXE_VAR="BRICSCAD_EXE" ;;
  --autocad) ENGINE_EXE_VAR="AUTOCAD_EXE" ;;
esac

detect_engine_exe() {
  case "$ENGINE_FLAG" in
    --bricscad)
      if [[ -n "${BRICSCAD_EXE:-}" && -f "${BRICSCAD_EXE}" ]]; then
        printf '%s\n' "$BRICSCAD_EXE"
        return 0
      fi
      ;;
    --autocad)
      if [[ -n "${AUTOCAD_EXE:-}" && -f "${AUTOCAD_EXE}" ]]; then
        printf '%s\n' "$AUTOCAD_EXE"
        return 0
      fi
      ;;
  esac
  return 1
}

DETECTED_ENGINE_EXE=""
if [[ "$USE_FAKE_CAD" -eq 1 ]]; then
  DETECTED_ENGINE_EXE="$FAKE_CAD"
else
  DETECTED_ENGINE_EXE="$(detect_engine_exe || true)"
fi

failures=0

to_windows_path() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p"
  elif [[ "$p" =~ ^/([a-zA-Z])/(.*)$ ]]; then
    local drive rest
    drive="${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"
    rest="${rest//\//\\}"
    printf '%s:\\%s' "${drive^^}" "$rest"
  else
    printf '%s' "$p"
  fi
}

to_lisp_path() {
  local p="$1"
  p="${p//\\//}"
  printf '%s' "$p"
}

materialize_expected() {
  local src="$1"
  local dst="$2"
  local expected_root="$ROOT_DIR"
  if [[ "$IS_WINDOWS" -eq 1 ]]; then
    expected_root="$(to_lisp_path "$(to_windows_path "$ROOT_DIR")")"
  fi
  sed \
    -e "s|@ROOT_DIR@|$expected_root|g" \
    "$src" >"$dst"
}

run_case() {
  local name="$1"
  local scenario="$2"
  local expected_stdout="$3"
  local expected_stderr="$4"
  local expected_rc="$5"
  shift 5
  local -a case_env=()
  local -a env_vars=()

  while [[ $# -gt 1 && "$1" == "--env" ]]; do
    case_env+=("$2")
    shift 2
  done

  local case_dir stdout_file stderr_file rc_file actual_rc
  local expected_stdout_file expected_stderr_file
  case_dir="$(mktemp -d "$TMP_DIR/${name}.XXXXXX")"
  stdout_file="$case_dir/stdout.txt"
  stderr_file="$case_dir/stderr.txt"
  rc_file="$case_dir/rc.txt"
  expected_stdout_file="$case_dir/expected.stdout"
  expected_stderr_file="$case_dir/expected.stderr"

  materialize_expected "$expected_stdout" "$expected_stdout_file"
  materialize_expected "$expected_stderr" "$expected_stderr_file"

  echo "$name RUN engine=$ENGINE_FLAG exe=${DETECTED_ENGINE_EXE:-fallback-ui} timeout=${RUN_TIMEOUT}s"

  declare -a cmd_env=(
    "AUTOLISP_WORKDIR=$case_dir/workdir"
    "AUTOLISP_KEEP_WORKDIR=1"
    "AUTOLISP_VERBOSE=0"
  )

  if [[ -n "$DETECTED_ENGINE_EXE" ]]; then
    cmd_env+=(
      "$ENGINE_EXE_VAR=$DETECTED_ENGINE_EXE"
    )
  fi

  if [[ "$USE_FAKE_CAD" -eq 1 ]]; then
    cmd_env+=(
      "AUTOLISP_FAKE_SCENARIO=$scenario"
      "BRICSCAD_COM_MODE=off"
      "AUTOCAD_COM_MODE=off"
    )
  fi

  env_vars=("${cmd_env[@]}")
  if [[ ${#case_env[@]} -gt 0 ]]; then
    env_vars+=("${case_env[@]}")
  fi

  if env "${env_vars[@]}" \
    perl -e 'alarm shift @ARGV; exec @ARGV' "$((RUN_TIMEOUT + 5))" \
    "$AUTOLISP" "${CAD_ARGS[@]}" --timeout "$RUN_TIMEOUT" "$@" >"$stdout_file" 2>"$stderr_file"
  then
    actual_rc=0
  else
    actual_rc=$?
  fi
  printf '%s\n' "$actual_rc" >"$rc_file"

  if [[ "$actual_rc" -ne "$expected_rc" ]]; then
    echo "$name KO" >&2
    echo "FAIL $name: expected rc=$expected_rc got rc=$actual_rc" >&2
    echo "workdir: $case_dir/workdir" >&2
    if [[ "$actual_rc" -eq 142 ]]; then
      echo "FAIL $name: shell timeout exceeded (${RUN_TIMEOUT}s + guard)" >&2
    fi
    if [[ "$VERBOSE" -eq 1 ]]; then
      [[ -s "$stdout_file" ]] && echo "--- stdout ---" >&2 && cat "$stdout_file" >&2
      [[ -s "$stderr_file" ]] && echo "--- stderr ---" >&2 && cat "$stderr_file" >&2
    fi
    failures=$((failures + 1))
    return
  fi

  if ! diff -u "$expected_stdout_file" "$stdout_file"; then
    echo "$name KO" >&2
    echo "FAIL $name: stdout mismatch" >&2
    failures=$((failures + 1))
    echo "workdir: $case_dir/workdir" >&2
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo "expected stdout: $expected_stdout_file" >&2
      echo "actual stdout: $stdout_file" >&2
      [[ -s "$stderr_file" ]] && echo "--- stderr ---" >&2 && cat "$stderr_file" >&2
    fi
    return
  fi

  if ! diff -u "$expected_stderr_file" "$stderr_file"; then
    echo "$name KO" >&2
    echo "FAIL $name: stderr mismatch" >&2
    failures=$((failures + 1))
    echo "workdir: $case_dir/workdir" >&2
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo "expected stderr: $expected_stderr_file" >&2
      echo "actual stderr: $stderr_file" >&2
    fi
    return
  fi

  echo "$name OK"
}

run_stdin_case() {
  local name="$1"
  local scenario="$2"
  local stdin_fixture="$3"
  local expected_stdout="$4"
  local expected_stderr="$5"
  local expected_rc="$6"
  shift 6
  local -a case_env=()
  local -a env_vars=()

  while [[ $# -gt 1 && "$1" == "--env" ]]; do
    case_env+=("$2")
    shift 2
  done

  local case_dir stdout_file stderr_file rc_file actual_rc
  local expected_stdout_file expected_stderr_file
  case_dir="$(mktemp -d "$TMP_DIR/${name}.XXXXXX")"
  stdout_file="$case_dir/stdout.txt"
  stderr_file="$case_dir/stderr.txt"
  rc_file="$case_dir/rc.txt"
  expected_stdout_file="$case_dir/expected.stdout"
  expected_stderr_file="$case_dir/expected.stderr"

  materialize_expected "$expected_stdout" "$expected_stdout_file"
  materialize_expected "$expected_stderr" "$expected_stderr_file"

  echo "$name RUN engine=$ENGINE_FLAG exe=${DETECTED_ENGINE_EXE:-fallback-ui} timeout=${RUN_TIMEOUT}s"

  declare -a cmd_env=(
    "AUTOLISP_WORKDIR=$case_dir/workdir"
    "AUTOLISP_KEEP_WORKDIR=1"
    "AUTOLISP_VERBOSE=0"
  )

  if [[ -n "$DETECTED_ENGINE_EXE" ]]; then
    cmd_env+=(
      "$ENGINE_EXE_VAR=$DETECTED_ENGINE_EXE"
    )
  fi

  if [[ "$USE_FAKE_CAD" -eq 1 ]]; then
    cmd_env+=(
      "AUTOLISP_FAKE_SCENARIO=$scenario"
      "BRICSCAD_COM_MODE=off"
      "AUTOCAD_COM_MODE=off"
    )
  fi

  env_vars=("${cmd_env[@]}")
  if [[ ${#case_env[@]} -gt 0 ]]; then
    env_vars+=("${case_env[@]}")
  fi

  if env "${env_vars[@]}" \
    perl -e 'alarm shift @ARGV; exec @ARGV' "$((RUN_TIMEOUT + 5))" \
    "$AUTOLISP" "${CAD_ARGS[@]}" --timeout "$RUN_TIMEOUT" "$@" <"$stdin_fixture" >"$stdout_file" 2>"$stderr_file"
  then
    actual_rc=0
  else
    actual_rc=$?
  fi
  printf '%s\n' "$actual_rc" >"$rc_file"

  if [[ "$actual_rc" -ne "$expected_rc" ]]; then
    echo "$name KO" >&2
    echo "FAIL $name: expected rc=$expected_rc got rc=$actual_rc" >&2
    echo "workdir: $case_dir/workdir" >&2
    if [[ "$actual_rc" -eq 142 ]]; then
      echo "FAIL $name: shell timeout exceeded (${RUN_TIMEOUT}s + guard)" >&2
    fi
    if [[ "$VERBOSE" -eq 1 ]]; then
      [[ -s "$stdout_file" ]] && echo "--- stdout ---" >&2 && cat "$stdout_file" >&2
      [[ -s "$stderr_file" ]] && echo "--- stderr ---" >&2 && cat "$stderr_file" >&2
    fi
    failures=$((failures + 1))
    return
  fi

  if ! diff -u "$expected_stdout_file" "$stdout_file"; then
    echo "$name KO" >&2
    echo "FAIL $name: stdout mismatch" >&2
    failures=$((failures + 1))
    echo "workdir: $case_dir/workdir" >&2
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo "expected stdout: $expected_stdout_file" >&2
      echo "actual stdout: $stdout_file" >&2
      [[ -s "$stderr_file" ]] && echo "--- stderr ---" >&2 && cat "$stderr_file" >&2
    fi
    return
  fi

  if ! diff -u "$expected_stderr_file" "$stderr_file"; then
    echo "$name KO" >&2
    echo "FAIL $name: stderr mismatch" >&2
    failures=$((failures + 1))
    echo "workdir: $case_dir/workdir" >&2
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo "expected stderr: $expected_stderr_file" >&2
      echo "actual stderr: $stderr_file" >&2
    fi
    return
  fi

  echo "$name OK"
}

run_case \
  "eval_prints" \
  "eval_prints" \
  "$SCRIPT_DIR/expected/eval_prints.stdout" \
  "$SCRIPT_DIR/expected/empty.stderr" \
  0 \
  -x '(progn (print (quote "Hello World")) (print "Hiya!"))'

run_case \
  "eval_no_output" \
  "eval_no_output" \
  "$SCRIPT_DIR/expected/eval_no_output.stdout" \
  "$SCRIPT_DIR/expected/empty.stderr" \
  0 \
  -x '(+ 1 2)'

if [[ "$ENGINE_FLAG" == "--bricscad" ]]; then
  run_case \
    "macos_batch_quit" \
    "macos_batch_quit" \
    "$SCRIPT_DIR/expected/eval_no_output.stdout" \
    "$SCRIPT_DIR/expected/empty.stderr" \
    0 \
    --env AUTOLISP_OS=Darwin \
    --env BRICSCAD_MACOS_MODE=batch \
    -x '(+ 1 2)'

  run_case \
    "macos_batch_profile" \
    "macos_batch_quit" \
    "$SCRIPT_DIR/expected/eval_no_output.stdout" \
    "$SCRIPT_DIR/expected/empty.stderr" \
    0 \
    --env AUTOLISP_OS=Darwin \
    --env BRICSCAD_MACOS_MODE=batch \
    --env AUTOLISP_FAKE_EXPECT_PROFILE=Lisp \
    --bricscad-macos-profile Lisp \
    -x '(+ 1 2)'
fi

run_case \
  "eval_load_string" \
  "eval_load_string" \
  "$SCRIPT_DIR/expected/eval_load_string.stdout" \
  "$SCRIPT_DIR/expected/empty.stderr" \
  0 \
  -x '(load "loader.lsp")'

run_case \
  "load_main_default" \
  "load_main_default" \
  "$SCRIPT_DIR/expected/load_main_default.stdout" \
  "$SCRIPT_DIR/expected/empty.stderr" \
  0 \
  "$SCRIPT_DIR/fixtures/main-default.lsp"

run_case \
  "load_main_custom" \
  "load_main_custom" \
  "$SCRIPT_DIR/expected/load_main_custom.stdout" \
  "$SCRIPT_DIR/expected/empty.stderr" \
  0 \
  "$SCRIPT_DIR/fixtures/main-custom.lsp" \
  --main C:RUN_BASIC

run_case \
  "load_side_effect" \
  "load_side_effect" \
  "$SCRIPT_DIR/expected/load_side_effect.stdout" \
  "$SCRIPT_DIR/expected/empty.stderr" \
  0 \
  "$SCRIPT_DIR/fixtures/load-side-effect.lsp"

if [[ "$ENGINE_FLAG" == "--bricscad" && "$IS_MACOS" -eq 1 ]]; then
  run_stdin_case \
    "interactive_repl" \
    "interactive_batch" \
    "$SCRIPT_DIR/fixtures/interactive-input.lsp" \
    "$SCRIPT_DIR/expected/interactive_repl.stdout" \
    "$SCRIPT_DIR/expected/empty.stderr" \
    0 \
    --env AUTOLISP_OS=Darwin \
    --env BRICSCAD_MACOS_MODE=batch \
    --interactive
else
  run_stdin_case \
    "interactive_repl" \
    "interactive_expr" \
    "$SCRIPT_DIR/fixtures/interactive-input.lsp" \
    "$SCRIPT_DIR/expected/interactive_repl.stdout" \
    "$SCRIPT_DIR/expected/empty.stderr" \
    0 \
    --interactive
fi

if [[ "$ENGINE_FLAG" == "--bricscad" ]]; then
  run_stdin_case \
    "interactive_batch_repl" \
    "interactive_batch" \
    "$SCRIPT_DIR/fixtures/interactive-input.lsp" \
    "$SCRIPT_DIR/expected/interactive_repl.stdout" \
    "$SCRIPT_DIR/expected/empty.stderr" \
    0 \
    --env AUTOLISP_OS=Darwin \
    --env BRICSCAD_MACOS_MODE=batch \
    --interactive
fi

if [[ "$failures" -ne 0 ]]; then
  echo "Tests failed: $failures" >&2
  exit 1
fi

echo "All tests passed for ${CAD_ARGS[*]}"
