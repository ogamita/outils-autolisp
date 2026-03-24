#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUTOLISP_BIN="${AUTOLISP_BIN:-$REPO_ROOT/autolisp-script/autolisp}"
AUTOLISP_KEEP_WORKDIR="${AUTOLISP_KEEP_WORKDIR:-1}"
TMP_DIR="$(mktemp -d /tmp/autolisp-load-errors.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/bad-top.lsp" <<'EOF_TOP'
(defun c:bad-top ()
  (+ 1 2)))
EOF_TOP

cat >"$TMP_DIR/bad-inner.lsp" <<'EOF_INNER'
(defun c:bad-inner ()
  (+ 10 20)))
EOF_INNER

cat >"$TMP_DIR/bad-outer.lsp" <<EOF_OUTER
(load "$TMP_DIR/bad-inner.lsp")
(princ)
EOF_OUTER

cat >"$TMP_DIR/bad-eof.lsp" <<'EOF_EOF'
(defun c:bad-eof ()
  (+ 1 2)
EOF_EOF

cat >"$TMP_DIR/bad-top.input" <<EOF_TOP_INPUT
(load "$TMP_DIR/bad-top.lsp")
(quit)
EOF_TOP_INPUT

cat >"$TMP_DIR/bad-outer.input" <<EOF_OUTER_INPUT
(load "$TMP_DIR/bad-outer.lsp")
(quit)
EOF_OUTER_INPUT

cat >"$TMP_DIR/bad-eof.input" <<EOF_EOF_INPUT
(load "$TMP_DIR/bad-eof.lsp")
(quit)
EOF_EOF_INPUT

run_probe() {
  local name="$1"
  local input_file="$2"
  shift 2

  printf '== %s ==\n' "$name"
  AUTOLISP_KEEP_WORKDIR="$AUTOLISP_KEEP_WORKDIR" "$AUTOLISP_BIN" "$@" -i <"$input_file"
  printf '\n'
}

COMMON_ARGS=(
  --bricscad-macos-mode
  batch
  --bricscad-macos-app
  launch
)

run_probe "bad-top" "$TMP_DIR/bad-top.input" "${COMMON_ARGS[@]}"
run_probe "bad-outer" "$TMP_DIR/bad-outer.input" "${COMMON_ARGS[@]}"
run_probe "bad-eof" "$TMP_DIR/bad-eof.input" "${COMMON_ARGS[@]}"
