#!/bin/sh
# Report, per documented component, whether all four rendered formats
# are present under build/doc/ and how big each one is.
#
#   sh scripts/check-docs.sh
#
# A development aid for the documentation phase: `make
# build-documentation' fails loudly on a missing target, but a manual
# that renders to a nearly-empty PDF or a single HTML page usually
# means org silently dropped its body, which only a size check shows.

set -eu

cd "$(dirname "$0")/.."

status=0

for dir in build/doc/*/ ; do
    [ -d "$dir" ] || continue
    c=$(basename "$dir")
    pdf="$dir$c--manual.pdf"
    info="$dir$c.info"
    html="$dir$c--manual.html"
    pages=$(ls "$dir"html/*.html 2>/dev/null | wc -l | tr -d ' ')

    missing=
    for f in "$pdf" "$info" "$html" ; do
        [ -s "$f" ] || missing="$missing $(basename "$f")"
    done
    [ "$pages" -gt 0 ] || missing="$missing html/"

    printf '%-24s pdf:%-7s info:%-7s html:%-7s pages:%s%s\n' \
        "$c" \
        "$(du -h "$pdf"  2>/dev/null | cut -f1)" \
        "$(du -h "$info" 2>/dev/null | cut -f1)" \
        "$(du -h "$html" 2>/dev/null | cut -f1)" \
        "$pages" \
        "${missing:+  MISSING:$missing}"
    [ -z "$missing" ] || status=1
done

exit $status
