#!/bin/sh
# Stamp the release version into every ALPM system definition.
#
#   sh scripts/stamp-alpm-version.sh [version]
#
# Default version: the contents of the VERSION file at the top of the
# work tree.  Each *.alpm gets a `version "M.m.d"' property right after
# its `name' property (replaced in place if it already has one).
#
# The ALPM systems of this repository are released as a unit, so they
# all carry the release version (version-rules.md R4/R5: a component
# changed within a series carries that series' M.m).

set -eu

cd "$(dirname "$0")/.."
version=${1:-$(cat VERSION)}

for f in outils-autolisp.alpm ./*/*.alpm ; do
    [ -f "$f" ] || continue
    if grep -q '^ *version  *"' "$f" ; then
        perl -i -pe 's/^( *)version( +)"[^"]*"/${1}version${2}"'"$version"'"/' "$f"
    else
        # Keep the file's own line endings (this repository stores the
        # AutoLISP sources and system definitions with CRLF).
        perl -i -0pe 's/^( *'"'"'?\(name +"[^"]*")(\r?\n)/${1}${2}   version     "'"$version"'"${2}/m' "$f"
    fi
    printf '%s: %s\n' "$f" "$(sed -n 's/^ *version  *"\([^"]*\)".*/\1/p' "$f")"
done
