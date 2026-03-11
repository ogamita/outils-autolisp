#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOLISP="$ROOT_DIR/autolisp"
FAKE_CAD="$SCRIPT_DIR/fake-cad.sh"
TMP_DIR="$SCRIPT_DIR/tmp"

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

run_case() {
  local name="$1"
  local scenario="$2"
  local expected_stdout="$3"
  local expected_stderr="$4"
  local expected_rc="$5"
  shift 5

  local case_dir stdout_file stderr_file rc_file actual_rc
  case_dir="$(mktemp -d "$TMP_DIR/${name}.XXXXXX")"
  stdout_file="$case_dir/stdout.txt"
  stderr_file="$case_dir/stderr.txt"
  rc_file="$case_dir/rc.txt"

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
    cmd_env+=("AUTOLISP_FAKE_SCENARIO=$scenario")
  fi

  if env "${cmd_env[@]}" \
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

  if ! diff -u "$expected_stdout" "$stdout_file"; then
    echo "$name KO" >&2
    echo "FAIL $name: stdout mismatch" >&2
    failures=$((failures + 1))
    echo "workdir: $case_dir/workdir" >&2
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo "expected stdout: $expected_stdout" >&2
      echo "actual stdout: $stdout_file" >&2
      [[ -s "$stderr_file" ]] && echo "--- stderr ---" >&2 && cat "$stderr_file" >&2
    fi
    return
  fi

  if ! diff -u "$expected_stderr" "$stderr_file"; then
    echo "$name KO" >&2
    echo "FAIL $name: stderr mismatch" >&2
    failures=$((failures + 1))
    echo "workdir: $case_dir/workdir" >&2
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo "expected stderr: $expected_stderr" >&2
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

if [[ "$failures" -ne 0 ]]; then
  echo "Tests failed: $failures" >&2
  exit 1
fi

echo "All tests passed for ${CAD_ARGS[*]}"
