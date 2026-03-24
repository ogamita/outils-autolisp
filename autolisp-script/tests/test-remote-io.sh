#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$ROOT_DIR/lib/autolisp-remote-io.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $label" >&2
    echo "expected: [$expected]" >&2
    echo "actual:   [$actual]" >&2
    exit 1
  fi
}

wait_until_idle() {
  local timeout="$1"
  local status=""

  while [[ "$timeout" -gt 0 ]]; do
    status="$(autolisp_protocol_read_status)"
    case "$status" in
      READY|WAITING-INPUT)
        return 0
        ;;
    esac
    sleep 1
    timeout=$((timeout - 1))
  done

  return 1
}

wait_until_file_contains() {
  local file="$1"
  local needle="$2"
  local timeout="$3"

  while [[ "$timeout" -gt 0 ]]; do
    if [[ -f "$file" ]] && grep -Fq "$needle" "$file"; then
      return 0
    fi
    sleep 1
    timeout=$((timeout - 1))
  done

  return 1
}

workdir="$(mktemp -d "${TMPDIR:-/tmp}/autolisp-remote-io.XXXXXX")"
trap 'rm -rf "$workdir"' EXIT

autolisp_protocol_init_session "$workdir"
autolisp_protocol_export_session

bash "$SCRIPT_DIR/protocol-mock-runtime.sh" "$workdir" &
runtime_pid=$!
trap 'kill "$runtime_pid" 2>/dev/null || true; rm -rf "$workdir"' EXIT

wait_until_idle 5 || fail "runtime did not reach an idle state"

autolisp_protocol_send_stdin $'alpha\n'
sleep 1
autolisp_protocol_send_stdin $'(list 1\n2)\n'
wait_until_file_contains "$AUTOLISP_PROTOCOL_STDOUTFILE" "FORM (list 1" 5 || fail "runtime did not complete the first protocol sequence"

stdout_block="$(cat "$AUTOLISP_PROTOCOL_STDOUTFILE")"
stderr_block="$(cat "$AUTOLISP_PROTOCOL_STDERRFILE")"
assert_eq "$stdout_block" $'LINE alpha\nFORM (list 1\n2)' "stdout for first protocol sequence"
assert_eq "$stderr_block" $'STDERR done' "stderr for first protocol sequence"

: >"$AUTOLISP_PROTOCOL_STDOUTFILE"
: >"$AUTOLISP_PROTOCOL_STDERRFILE"

autolisp_protocol_send_stdin $'beta\n'
sleep 1
autolisp_protocol_send_stdin $'42\n'
wait_until_file_contains "$AUTOLISP_PROTOCOL_STDOUTFILE" "FORM 42" 5 || fail "runtime did not complete the second protocol sequence"

stdout_block="$(cat "$AUTOLISP_PROTOCOL_STDOUTFILE")"
stderr_block="$(cat "$AUTOLISP_PROTOCOL_STDERRFILE")"
assert_eq "$stdout_block" $'LINE beta\nFORM 42' "stdout for second protocol sequence"
assert_eq "$stderr_block" $'STDERR done' "stderr for second protocol sequence"

autolisp_protocol_send_control "PING"
sleep 1
[[ -s "$AUTOLISP_PROTOCOL_HEARTBEATFILE" ]] || fail "heartbeat file was not written after PING"

autolisp_protocol_send_control "SHUTDOWN"
autolisp_protocol_wait_for_status "STOPPED" 5 || fail "runtime did not stop cleanly"
wait "$runtime_pid"

echo "remote-io protocol tests passed"
