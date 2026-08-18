#!/bin/sh
# One-shot helper: replace the "## Tags et branches" section of
# README.md (up to, but not including, "### Jalons 1.0") with the file
# given as argument.
#
#   sh scripts/splice-readme.sh NEW-SECTION.md
#
# Kept in the tree because the section it rewrites is the one that has
# to be revisited at every change of release convention.

set -eu

cd "$(dirname "$0")/.."
new=$1

start=$(grep -n '^## Tags et branches$' README.md | head -1 | cut -d: -f1)
end=$(grep -n '^### Jalons 1\.0$'        README.md | head -1 | cut -d: -f1)

[ -n "$start" ] && [ -n "$end" ] || { echo "splice-readme: section introuvable" >&2 ; exit 1 ; }

{
    head -n $((start - 1)) README.md
    cat "$new"
    printf '\n'
    tail -n +"$end" README.md
} > README.md.new

mv README.md.new README.md
echo "README.md: section « Tags et branches » remplacée (lignes $start..$((end - 1)))"
