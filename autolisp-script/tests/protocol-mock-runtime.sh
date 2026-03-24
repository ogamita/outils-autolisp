#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/autolisp-remote-io.sh"

form_complete() {
  local form="$1"
  perl -e '
my $s = shift;
my ($depth, $in_string, $escape, $in_comment, $started) = (0, 0, 0, 0, 0);
foreach my $ch (split //, $s) {
  if ($in_comment) {
    $in_comment = 0 if $ch eq "\n";
    next;
  }
  if ($in_string) {
    $started = 1;
    if ($escape) {
      $escape = 0;
      next;
    }
    if ($ch eq "\\") {
      $escape = 1;
      next;
    }
    if ($ch eq "\"") {
      $in_string = 0;
    }
    next;
  }
  if ($ch eq ";") {
    $in_comment = 1;
    next;
  }
  if ($ch =~ /\s/) {
    next;
  }
  $started = 1;
  if ($ch eq "\"") {
    $in_string = 1;
    next;
  }
  if ($ch eq "(") {
    $depth++;
    next;
  }
  if ($ch eq ")") {
    $depth-- if $depth > 0;
    next;
  }
}
exit(($started && !$in_string && !$in_comment && $depth == 0) ? 0 : 1);
' -- "$form"
}

queue=()

handle_control() {
  local control=""

  [[ -f "$AUTOLISP_PROTOCOL_CONTROLFILE" ]] || return 1
  control="$(cat "$AUTOLISP_PROTOCOL_CONTROLFILE")"
  rm -f "$AUTOLISP_PROTOCOL_CONTROLFILE"

  case "$control" in
    SHUTDOWN)
      printf 'STOPPING\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
      printf 'STOPPED\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
      exit 0
      ;;
    PING)
      date +%s >"$AUTOLISP_PROTOCOL_HEARTBEATFILE"
      return 0
      ;;
  esac

  return 1
}

queue_stdin() {
  local line
  [[ -f "$AUTOLISP_PROTOCOL_STDINFILE" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    queue+=("$line")
  done <"$AUTOLISP_PROTOCOL_STDINFILE"
  rm -f "$AUTOLISP_PROTOCOL_STDINFILE"
}

next_line() {
  while [[ ${#queue[@]} -eq 0 ]]; do
    handle_control || true
    queue_stdin
    if [[ ${#queue[@]} -eq 0 ]]; then
      printf 'WAITING-INPUT\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
      sleep 0.05
    fi
  done

  NEXT_LINE_VALUE="${queue[0]}"
  if [[ ${#queue[@]} -gt 1 ]]; then
    queue=("${queue[@]:1}")
  else
    queue=()
  fi
}

autolisp_protocol_init_session "${1:?missing workdir}"
autolisp_protocol_export_session
autolisp_protocol_reset_session
printf 'READY\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"

while true; do
  handle_control || true

  next_line
  line="$NEXT_LINE_VALUE"
  printf 'RUNNING\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
  printf 'LINE %s\n' "$line" >>"$AUTOLISP_PROTOCOL_STDOUTFILE"

  form=""
  while ! form_complete "$form"; do
    next_line
    next="$NEXT_LINE_VALUE"
    if [[ -z "$form" ]]; then
      form="$next"
    else
      form+=$'\n'"$next"
    fi
  done

  printf 'FORM %s\n' "$form" >>"$AUTOLISP_PROTOCOL_STDOUTFILE"
  printf 'STDERR done\n' >>"$AUTOLISP_PROTOCOL_STDERRFILE"
  printf 'READY\n' >"$AUTOLISP_PROTOCOL_STATUSFILE"
done
