#!/bin/sh
# MANIFEST_VERSIONS_CMD hook for scripts/make-manifest.sh.
#
# Prints "name version, name version, …" for everything a release
# ships, on one line: the ALPM library systems (version read from each
# <name>.alpm) and the programs (version read from their own source —
# program versions are an independent axis, version-rules.md R4/R5, so
# dwg-identify may legitimately differ from the release version).
#
# The Makefile exports RELEASED_SYSTEMS so that the manifest lists what
# is actually shipped rather than every system definition in the tree
# (autolisp-defstruct, for one, is not released yet).  With that
# variable unset every *.alpm found is reported.

set -eu

cd "$(dirname "$0")/.."

if [ -n "${RELEASED_SYSTEMS:-}" ] ; then
    alpms=
    for name in $RELEASED_SYSTEMS ; do
        alpms="$alpms $name/$name.alpm"
    done
    alpms="outils-autolisp.alpm $alpms"
else
    alpms="outils-autolisp.alpm $(echo */*.alpm)"
fi

out=

for alpm in $alpms ; do
    [ -f "$alpm" ] || continue
    # The system name is the file's own name by ALPM's lookup rule
    # (<root>/<name>/<name>.alpm), which is more robust than parsing
    # the `name' property out of the quoted list.
    name=$(basename "$alpm" .alpm)
    ver=$( sed -n 's/^ *version  *"\([^"]*\)".*/\1/p' "$alpm" | head -1)
    [ -n "$ver" ] || ver="(unversioned)"
    out="${out:+$out, }$name $ver"
done

# `*version*' is followed by its docstring on the next line, so the
# pattern must not expect the closing paren on this one.
dwg=$(sed -n 's/^(defparameter \*version\* "\([^"]*\)".*/\1/p' \
          dwg-identifier/src/cli.lisp 2>/dev/null | head -1)
[ -n "$dwg" ] && out="${out:+$out, }dwg-identify $dwg"

printf '%s\n' "$out"
