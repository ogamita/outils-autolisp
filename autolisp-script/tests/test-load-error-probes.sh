#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPECTED_FILE="$SCRIPT_DIR/expected/load_error_probes.stdout"
ACTUAL_FILE="$(mktemp /tmp/autolisp-load-error-probes.actual.XXXXXX)"
NORMALIZED_FILE="$(mktemp /tmp/autolisp-load-error-probes.normalized.XXXXXX)"

cleanup() {
  rm -f "$ACTUAL_FILE" "$NORMALIZED_FILE"
}
trap cleanup EXIT

AUTOLISP_KEEP_WORKDIR=0 "$SCRIPT_DIR/probe-load-errors.sh" >"$ACTUAL_FILE" 2>&1

sed \
  -e 's#/tmp/autolisp-load-errors\.[A-Za-z0-9]*/#/tmp/autolisp-load-errors.TMPDIR/#g' \
  -e 's/pid=[0-9][0-9]*/pid=PID/g' \
  "$ACTUAL_FILE" >"$NORMALIZED_FILE"

diff -u "$EXPECTED_FILE" "$NORMALIZED_FILE"
