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
declare -a CURRENT_CAD_ARGS=()
CURRENT_SUITE_LABEL=""

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

find_macos_bricscad_app() {
  ls -1d /Applications/BricsCAD*.app 2>/dev/null | head -n 1 || true
}

find_macos_bricscad_cli() {
  if [[ -n "${BRICSCAD_EXE:-}" && -f "${BRICSCAD_EXE}" ]]; then
    printf '%s\n' "$BRICSCAD_EXE"
    return 0
  fi

  local app
  app="$(find_macos_bricscad_app)"
  if [[ -n "$app" && -x "$app/Contents/MacOS/bricscad" ]]; then
    printf '%s\n' "$app/Contents/MacOS/bricscad"
    return 0
  fi

  return 1
}

find_mode_arg() {
  local i
  for ((i = 0; i < ${#CAD_ARGS[@]}; i++)); do
    if [[ "${CAD_ARGS[$i]}" == "--mode" && $((i + 1)) -lt ${#CAD_ARGS[@]} ]]; then
      printf '%s\n' "${CAD_ARGS[$((i + 1))]}"
      return 0
    fi
  done
  return 1
}

find_backend_arg() {
  local i
  for ((i = 0; i < ${#CAD_ARGS[@]}; i++)); do
    if [[ "${CAD_ARGS[$i]}" == "--backend" && $((i + 1)) -lt ${#CAD_ARGS[@]} ]]; then
      printf '%s\n' "${CAD_ARGS[$((i + 1))]}"
      return 0
    fi
  done
  return 1
}

macos_bricscad_running() {
  local app appname
  app="$(find_macos_bricscad_app)"
  [[ -n "$app" ]] || return 1
  appname="$(basename "$app" .app)"
  /usr/bin/osascript - "$appname" <<'OSA' >/dev/null 2>&1
on run argv
  set appName to item 1 of argv
  tell application "System Events"
    if exists process appName then
      return
    end if
  end tell
  error number 1
end run
OSA
}

prompt_for_bricscad_launch() {
  local app appname
  app="$(find_macos_bricscad_app)"
  appname="$(basename "${app:-BricsCAD.app}" .app)"

  if macos_bricscad_running; then
    return 0
  fi

  if [[ -t 0 && -t 1 ]]; then
    echo "tests/run.sh: BricsCAD doit etre lance pour le mode automation attach." >&2
    echo "tests/run.sh: Ouvre \"$appname\", verifie le workspace \"2D Drafting\", puis appuie sur Entree pour continuer (Ctrl-C pour annuler)." >&2
    read -r
    if macos_bricscad_running; then
      return 0
    fi
  fi

  echo "tests/run.sh: BricsCAD n'est pas lance. Relance apres avoir ouvert \"$appname\", ou utilise --mode batch." >&2
  return 1
}

CAD_MODE_ARG="$(find_mode_arg || true)"
CAD_BACKEND_ARG="$(find_backend_arg || true)"

detect_engine_exe() {
  case "$ENGINE_FLAG" in
    --bricscad)
      if [[ -n "${BRICSCAD_EXE:-}" && -f "${BRICSCAD_EXE}" ]]; then
        printf '%s\n' "$BRICSCAD_EXE"
        return 0
      fi
      if [[ "$IS_MACOS" -eq 1 && "${CAD_MODE_ARG:-auto}" != "automation" ]]; then
        find_macos_bricscad_cli
        return $?
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

BRICSCAD_MACOS_EFFECTIVE_TEST_MODE="${CAD_MODE_ARG:-}"
if [[ "$ENGINE_FLAG" == "--bricscad" && "$IS_MACOS" -eq 1 ]]; then
  if [[ -z "$BRICSCAD_MACOS_EFFECTIVE_TEST_MODE" || "$BRICSCAD_MACOS_EFFECTIVE_TEST_MODE" == "auto" ]]; then
    if [[ -n "$DETECTED_ENGINE_EXE" ]]; then
      BRICSCAD_MACOS_EFFECTIVE_TEST_MODE="batch"
    else
      BRICSCAD_MACOS_EFFECTIVE_TEST_MODE="automation"
    fi
  fi
fi

USE_BRICSCAD_MACOS_PROTOCOL_TESTS=0
if [[ "$ENGINE_FLAG" == "--bricscad" && "$IS_MACOS" -eq 1 && "$USE_FAKE_CAD" -eq 1 ]]; then
  case "$BRICSCAD_MACOS_EFFECTIVE_TEST_MODE" in
    batch|automation)
      USE_BRICSCAD_MACOS_PROTOCOL_TESTS=1
      ;;
  esac
fi

CURRENT_CAD_ARGS=("${CAD_ARGS[@]}")
if [[ "$ENGINE_FLAG" == "--bricscad" && "$IS_MACOS" -eq 1 ]]; then
  CURRENT_SUITE_LABEL="macos/${BRICSCAD_MACOS_EFFECTIVE_TEST_MODE:-auto}"
  if [[ "$BRICSCAD_MACOS_EFFECTIVE_TEST_MODE" == "automation" ]]; then
    CURRENT_SUITE_LABEL+="/${CAD_BACKEND_ARG:-launch}"
  fi
fi
if [[ "$ENGINE_FLAG" == "--bricscad" && "$IS_MACOS" -eq 1 && "$USE_FAKE_CAD" -ne 1 ]]; then
  if [[ "$BRICSCAD_MACOS_EFFECTIVE_TEST_MODE" == "batch" && -z "$DETECTED_ENGINE_EXE" ]]; then
    echo "tests/run.sh: mode batch demande mais aucun executable BricsCAD CLI n'a ete trouve." >&2
    echo "tests/run.sh: Definis BRICSCAD_EXE ou installe BricsCAD dans /Applications." >&2
    exit 2
  fi
  if [[ "$BRICSCAD_MACOS_EFFECTIVE_TEST_MODE" == "automation" && "${CAD_BACKEND_ARG:-launch}" == "attach" ]]; then
    prompt_for_bricscad_launch || exit 2
  fi
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

select_cad_workdir_root() {
  local name="$1"
  local case_dir="$2"
  if [[ "$ENGINE_FLAG" == "--bricscad" && "$IS_MACOS" -eq 1 && "$USE_FAKE_CAD" -ne 1 && "$BRICSCAD_MACOS_EFFECTIVE_TEST_MODE" == "batch" ]]; then
    mktemp -d "${TMPDIR:-/tmp}/autolisp-test-${name}.XXXXXX"
  else
    printf '%s\n' "$case_dir/workdir"
  fi
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

  local case_dir stdout_file stderr_file rc_file actual_rc cad_workdir_root
  local expected_stdout_file expected_stderr_file
  case_dir="$(mktemp -d "$TMP_DIR/${name}.XXXXXX")"
  stdout_file="$case_dir/stdout.txt"
  stderr_file="$case_dir/stderr.txt"
  rc_file="$case_dir/rc.txt"
  expected_stdout_file="$case_dir/expected.stdout"
  expected_stderr_file="$case_dir/expected.stderr"
  cad_workdir_root="$(select_cad_workdir_root "$name" "$case_dir")"

  materialize_expected "$expected_stdout" "$expected_stdout_file"
  materialize_expected "$expected_stderr" "$expected_stderr_file"

  if [[ -n "$CURRENT_SUITE_LABEL" ]]; then
    echo "$name RUN suite=$CURRENT_SUITE_LABEL engine=$ENGINE_FLAG exe=${DETECTED_ENGINE_EXE:-fallback-ui} timeout=${RUN_TIMEOUT}s"
  else
    echo "$name RUN engine=$ENGINE_FLAG exe=${DETECTED_ENGINE_EXE:-fallback-ui} timeout=${RUN_TIMEOUT}s"
  fi

  declare -a cmd_env=(
    "AUTOLISP_WORKDIR=$cad_workdir_root"
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
    if [[ "$ENGINE_FLAG" == "--bricscad" && "$IS_MACOS" -eq 1 && "$BRICSCAD_MACOS_EFFECTIVE_TEST_MODE" == "automation" ]]; then
      cmd_env+=("AUTOLISP_FAKE_PROFILE_OPTIONAL=1")
    fi
  fi

  env_vars=("${cmd_env[@]}")
  if [[ ${#case_env[@]} -gt 0 ]]; then
    env_vars+=("${case_env[@]}")
  fi

  if env "${env_vars[@]}" \
    perl -e 'alarm shift @ARGV; exec @ARGV' "$((RUN_TIMEOUT + 5))" \
    "$AUTOLISP" "${CURRENT_CAD_ARGS[@]}" --timeout "$RUN_TIMEOUT" "$@" >"$stdout_file" 2>"$stderr_file"
  then
    actual_rc=0
  else
    actual_rc=$?
  fi
  printf '%s\n' "$actual_rc" >"$rc_file"

  if [[ "$actual_rc" -ne "$expected_rc" ]]; then
    echo "$name KO" >&2
    echo "FAIL $name: expected rc=$expected_rc got rc=$actual_rc" >&2
    echo "workdir: $cad_workdir_root" >&2
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
    echo "workdir: $cad_workdir_root" >&2
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
    echo "workdir: $cad_workdir_root" >&2
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
  local expected_fake_invocations=""

  while [[ $# -gt 1 && "$1" == "--env" ]]; do
    case_env+=("$2")
    shift 2
  done
  if [[ $# -gt 1 && "$1" == "--expect-fake-invocations" ]]; then
    expected_fake_invocations="$2"
    shift 2
  fi

  local case_dir stdout_file stderr_file rc_file actual_rc cad_workdir_root
  local expected_stdout_file expected_stderr_file fake_invocation_file actual_fake_invocations
  case_dir="$(mktemp -d "$TMP_DIR/${name}.XXXXXX")"
  stdout_file="$case_dir/stdout.txt"
  stderr_file="$case_dir/stderr.txt"
  rc_file="$case_dir/rc.txt"
  expected_stdout_file="$case_dir/expected.stdout"
  expected_stderr_file="$case_dir/expected.stderr"
  fake_invocation_file="$case_dir/fake-invocations.txt"
  cad_workdir_root="$(select_cad_workdir_root "$name" "$case_dir")"

  materialize_expected "$expected_stdout" "$expected_stdout_file"
  materialize_expected "$expected_stderr" "$expected_stderr_file"

  if [[ -n "$CURRENT_SUITE_LABEL" ]]; then
    echo "$name RUN suite=$CURRENT_SUITE_LABEL engine=$ENGINE_FLAG exe=${DETECTED_ENGINE_EXE:-fallback-ui} timeout=${RUN_TIMEOUT}s"
  else
    echo "$name RUN engine=$ENGINE_FLAG exe=${DETECTED_ENGINE_EXE:-fallback-ui} timeout=${RUN_TIMEOUT}s"
  fi

  declare -a cmd_env=(
    "AUTOLISP_WORKDIR=$cad_workdir_root"
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
      "AUTOLISP_FAKE_INVOCATION_FILE=$fake_invocation_file"
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
    "$AUTOLISP" "${CURRENT_CAD_ARGS[@]}" --timeout "$RUN_TIMEOUT" "$@" <"$stdin_fixture" >"$stdout_file" 2>"$stderr_file"
  then
    actual_rc=0
  else
    actual_rc=$?
  fi
  printf '%s\n' "$actual_rc" >"$rc_file"

  if [[ "$actual_rc" -ne "$expected_rc" ]]; then
    echo "$name KO" >&2
    echo "FAIL $name: expected rc=$expected_rc got rc=$actual_rc" >&2
    echo "workdir: $cad_workdir_root" >&2
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
    echo "workdir: $cad_workdir_root" >&2
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
    echo "workdir: $cad_workdir_root" >&2
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo "expected stderr: $expected_stderr_file" >&2
      echo "actual stderr: $stderr_file" >&2
    fi
    return
  fi

  if [[ -n "$expected_fake_invocations" ]]; then
    actual_fake_invocations=0
    if [[ -f "$fake_invocation_file" ]]; then
      actual_fake_invocations="$(wc -l <"$fake_invocation_file" 2>/dev/null || echo 0)"
      actual_fake_invocations="${actual_fake_invocations//[[:space:]]/}"
    fi
    if [[ "$actual_fake_invocations" != "$expected_fake_invocations" ]]; then
      echo "$name KO" >&2
      echo "FAIL $name: expected fake CAD invocations=$expected_fake_invocations got $actual_fake_invocations" >&2
      failures=$((failures + 1))
      echo "workdir: $cad_workdir_root" >&2
      return
    fi
  fi

  echo "$name OK"
}

run_standard_cases() {
  if [[ "$USE_BRICSCAD_MACOS_PROTOCOL_TESTS" -eq 1 ]]; then
    run_case \
      "eval_prints" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/eval_prints.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      -x '(progn (print (quote "Hello World")) (print "Hiya!"))'

    run_case \
      "eval_no_output" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/eval_no_output.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      -x '(+ 1 2)'

    run_case \
      "eval_prints_verbose" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/eval_prints_verbose.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      -x '(progn (print (quote "Hello World")) (print "Hiya!"))' \
      --verbose

    run_case \
      "eval_no_output_quiet" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/eval_no_output.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      -x '(+ 1 2)' \
      --quiet

    run_case \
      "eval_error" \
      "protocol_batch" \
      "/dev/null" \
      "$SCRIPT_DIR/expected/eval_error.stderr" \
      1 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      -x '(/ 1 0)'

    run_case \
      "eval_error_verbose" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/eval_error_verbose.stdout" \
      "$SCRIPT_DIR/expected/eval_error.stderr" \
      1 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      -x '(/ 1 0)' \
      --verbose

    run_case \
      "eval_error_quiet" \
      "protocol_batch" \
      "/dev/null" \
      "$SCRIPT_DIR/expected/eval_error.stderr" \
      1 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      -x '(/ 1 0)' \
      --quiet
  else
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
  fi

  if [[ "$ENGINE_FLAG" == "--bricscad" && "$USE_FAKE_CAD" -eq 1 && "$BRICSCAD_MACOS_EFFECTIVE_TEST_MODE" == "batch" ]]; then
    run_case \
      "macos_batch_quit" \
      "macos_batch_quit" \
      "$SCRIPT_DIR/expected/eval_no_output.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=off \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      -x '(+ 1 2)'

    run_case \
      "macos_batch_profile" \
      "macos_batch_quit" \
      "$SCRIPT_DIR/expected/eval_no_output.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=off \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=Lisp \
      --bricscad-macos-profile Lisp \
      -x '(+ 1 2)'

    run_case \
      "macos_batch_protocol_eval" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/eval_no_output.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      -x '(+ 1 2)'

    run_case \
      "macos_batch_protocol_load" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/load_side_effect.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      "$SCRIPT_DIR/fixtures/load-side-effect.lsp"
  fi

  if [[ "$USE_BRICSCAD_MACOS_PROTOCOL_TESTS" -eq 1 ]]; then
    run_case \
      "eval_load_string" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/eval_load_string.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      -x '(load "loader.lsp")'

    run_case \
      "eval_get_new_guid" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/eval_get_new_guid.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      -x '(get_new_guid)'

    run_case \
      "load_main_default" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/load_main_default.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      "$SCRIPT_DIR/fixtures/main-default.lsp" \
      --main C:MAIN

    run_case \
      "load_main_default_verbose" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/load_main_default_verbose.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      "$SCRIPT_DIR/fixtures/main-default.lsp" \
      --main C:MAIN \
      --verbose

    run_case \
      "load_main_custom" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/load_main_custom.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      "$SCRIPT_DIR/fixtures/main-custom.lsp" \
      --main C:RUN_BASIC

    run_case \
      "load_side_effect" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/load_side_effect.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      "$SCRIPT_DIR/fixtures/load-side-effect.lsp"

    run_case \
      "load_then_eval" \
      "protocol_batch" \
      "$SCRIPT_DIR/expected/load_then_eval.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --env AUTOLISP_FAKE_EXPECT_PROFILE=lisp \
      "$SCRIPT_DIR/fixtures/load-side-effect.lsp" \
      -x '(+ 1 2)'

  else
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
      "$SCRIPT_DIR/fixtures/main-default.lsp" \
      --main C:MAIN

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
  fi
}

run_interactive_cases() {
  if [[ "$ENGINE_FLAG" == "--bricscad" && "$IS_MACOS" -eq 1 && "$BRICSCAD_MACOS_EFFECTIVE_TEST_MODE" != "auto" ]]; then
    run_stdin_case \
      "version" \
      "protocol_batch" \
      "/dev/null" \
      "$SCRIPT_DIR/expected/version.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --expect-fake-invocations 0 \
      --version

    run_stdin_case \
      "interactive_repl" \
      "protocol_batch" \
      "$SCRIPT_DIR/fixtures/interactive-input.lsp" \
      "$SCRIPT_DIR/expected/interactive_repl.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --expect-fake-invocations 1 \
      --interactive

    run_stdin_case \
      "interactive_repl_verbose" \
      "protocol_batch" \
      "$SCRIPT_DIR/fixtures/interactive-input.lsp" \
      "$SCRIPT_DIR/expected/interactive_repl_verbose.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --expect-fake-invocations 1 \
      --interactive \
      --verbose

    run_stdin_case \
      "interactive_quit" \
      "protocol_batch" \
      "$SCRIPT_DIR/fixtures/interactive-quit-input.lsp" \
      "$SCRIPT_DIR/expected/interactive_quit.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --expect-fake-invocations 1 \
      --interactive

    run_stdin_case \
      "interactive_quit_quiet" \
      "protocol_batch" \
      "$SCRIPT_DIR/fixtures/interactive-quit-input.lsp" \
      "$SCRIPT_DIR/expected/interactive_quit_quiet.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --expect-fake-invocations 1 \
      --interactive \
      --quiet

    run_stdin_case \
      "interactive_load" \
      "protocol_batch" \
      "$SCRIPT_DIR/fixtures/interactive-load-input.lsp" \
      "$SCRIPT_DIR/expected/interactive_load.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --expect-fake-invocations 1 \
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

  if [[ "$USE_BRICSCAD_MACOS_PROTOCOL_TESTS" -eq 1 ]]; then
    run_stdin_case \
      "interactive_batch_repl" \
      "protocol_batch" \
      "$SCRIPT_DIR/fixtures/interactive-input.lsp" \
      "$SCRIPT_DIR/expected/interactive_repl.stdout" \
      "$SCRIPT_DIR/expected/empty.stderr" \
      0 \
      --env AUTOLISP_OS=Darwin \
      --env BRICSCAD_MACOS_MODE=batch \
      --env AUTOLISP_REMOTE_IO_MODE=on \
      --interactive
  fi
}

run_standard_cases
run_interactive_cases

if [[ "$failures" -ne 0 ]]; then
  echo "Tests failed: $failures" >&2
  exit 1
fi

echo "All tests passed for ${CAD_ARGS[*]}"
