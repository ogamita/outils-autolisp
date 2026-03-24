#!/usr/bin/env bash
set -euo pipefail

autolisp_protocol_init_session() {
  local workdir="$1"

  AUTOLISP_PROTOCOL_DIR="$workdir/protocol"
  AUTOLISP_PROTOCOL_STATUSFILE="$AUTOLISP_PROTOCOL_DIR/status.txt"
  AUTOLISP_PROTOCOL_STDINFILE="$AUTOLISP_PROTOCOL_DIR/stdin.txt"
  AUTOLISP_PROTOCOL_STDOUTFILE="$AUTOLISP_PROTOCOL_DIR/stdout.txt"
  AUTOLISP_PROTOCOL_STDERRFILE="$AUTOLISP_PROTOCOL_DIR/stderr.txt"
  AUTOLISP_PROTOCOL_CONTROLFILE="$AUTOLISP_PROTOCOL_DIR/control.txt"
  AUTOLISP_PROTOCOL_HEARTBEATFILE="$AUTOLISP_PROTOCOL_DIR/heartbeat.txt"
  AUTOLISP_PROTOCOL_READFILE="$AUTOLISP_PROTOCOL_DIR/read-buffer.lsp"
  AUTOLISP_PROTOCOL_INFOFILE="$AUTOLISP_PROTOCOL_DIR/runtime-info.txt"

  mkdir -p "$AUTOLISP_PROTOCOL_DIR"
}

autolisp_protocol_export_session() {
  export \
    AUTOLISP_PROTOCOL_DIR \
    AUTOLISP_PROTOCOL_STATUSFILE \
    AUTOLISP_PROTOCOL_STDINFILE \
    AUTOLISP_PROTOCOL_STDOUTFILE \
    AUTOLISP_PROTOCOL_STDERRFILE \
    AUTOLISP_PROTOCOL_CONTROLFILE \
    AUTOLISP_PROTOCOL_HEARTBEATFILE \
    AUTOLISP_PROTOCOL_READFILE \
    AUTOLISP_PROTOCOL_INFOFILE
}

autolisp_protocol_reset_session() {
  : >"$AUTOLISP_PROTOCOL_STDOUTFILE"
  : >"$AUTOLISP_PROTOCOL_STDERRFILE"
  printf 'BOOTING\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
  rm -f \
    "$AUTOLISP_PROTOCOL_STDINFILE" \
    "$AUTOLISP_PROTOCOL_CONTROLFILE" \
    "$AUTOLISP_PROTOCOL_HEARTBEATFILE" \
    "$AUTOLISP_PROTOCOL_INFOFILE"
}

autolisp_protocol_write_atomic_file() {
  local target="$1"
  local content="$2"
  local tmp

  tmp="${target}.tmp.$$.$RANDOM"
  printf '%s' "$content" >"$tmp"
  mv "$tmp" "$target"
}

autolisp_protocol_wait_until_slot_free() {
  local target="$1"
  local timeout="${2:-10}"

  while [[ "$timeout" -gt 0 ]]; do
    if [[ ! -e "$target" ]]; then
      return 0
    fi
    sleep 1
    timeout=$((timeout - 1))
  done

  return 1
}

autolisp_protocol_send_stdin() {
  autolisp_protocol_wait_until_slot_free "$AUTOLISP_PROTOCOL_STDINFILE" 10
  autolisp_protocol_write_atomic_file "$AUTOLISP_PROTOCOL_STDINFILE" "$1"
}

autolisp_protocol_send_control() {
  autolisp_protocol_wait_until_slot_free "$AUTOLISP_PROTOCOL_CONTROLFILE" 10
  autolisp_protocol_write_atomic_file "$AUTOLISP_PROTOCOL_CONTROLFILE" "$1"
}

autolisp_protocol_read_status() {
  if [[ -f "$AUTOLISP_PROTOCOL_STATUSFILE" ]]; then
    awk 'NF{line=$0} END{print line}' "$AUTOLISP_PROTOCOL_STATUSFILE" 2>/dev/null || true
  fi
}

autolisp_protocol_wait_for_status() {
  local expected="$1"
  local timeout="$2"
  local current

  while [[ "$timeout" -gt 0 ]]; do
    current="$(autolisp_protocol_read_status)"
    if [[ "$current" == "$expected" ]]; then
      return 0
    fi
    sleep 1
    timeout=$((timeout - 1))
  done

  return 1
}

autolisp_protocol_wait_for_status_prefix() {
  local prefix="$1"
  local timeout="$2"
  local current

  while [[ "$timeout" -gt 0 ]]; do
    current="$(autolisp_protocol_read_status)"
    if [[ "$current" == "$prefix" || "$current" == "$prefix "* ]]; then
      return 0
    fi
    sleep 1
    timeout=$((timeout - 1))
  done

  return 1
}
