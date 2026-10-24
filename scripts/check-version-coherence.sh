#!/bin/sh
# Vérifie les versions de publication sans consulter les références Git.
set -eu
cd "$(dirname "$0")/.."
version=$(tr -d '\r\n' < VERSION)
printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || {
    echo 'FAIL: VERSION doit contenir une version M.m.p' >&2
    exit 1
}
fail=0
for file in outils-autolisp.alpm ./*/*.alpm; do
    [ -f "$file" ] || continue
    actual=$(sed -n 's/^ *version  *"\([^"]*\)".*/\1/p' "$file")
    if [ "$actual" != "$version" ]; then
        printf 'FAIL: %s: %s (attendu: %s)\n' "$file" "$actual" "$version" >&2
        fail=1
    fi
done
for file in autolisp-introspection/VERSION.TXT autolisp-test/VERSION.TXT; do
    actual=$(awk -F= '/^VERSION_MAJOR=/{major=$2} /^VERSION_MINOR=/{minor=$2} /^VERSION_PATCH=/{patch=$2} END {printf "%s.%s.%s", major, minor, patch}' "$file" | tr -d '\r')
    if [ "$actual" != "$version" ]; then
        printf 'FAIL: %s: %s (attendu: %s)\n' "$file" "$actual" "$version" >&2
        fail=1
    fi
done
[ "$fail" -eq 0 ] || exit 1
printf 'Versions de publication cohérentes: %s\n' "$version"
