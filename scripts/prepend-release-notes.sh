#!/bin/sh
# Insert a new version section at the top of RELEASE_NOTES.org, just
# after the front matter and before the newest existing section.
#
#   sh scripts/prepend-release-notes.sh SECTION.org
#
# The notes are newest-first, so a new version goes above every other
# `* ' heading.

set -eu

cd "$(dirname "$0")/.."
new=$1

first=$(grep -n '^\* ' RELEASE_NOTES.org | head -1 | cut -d: -f1)
[ -n "$first" ] || { echo "prepend-release-notes: aucune section trouvée" >&2 ; exit 1 ; }

{
    head -n $((first - 1)) RELEASE_NOTES.org
    cat "$new"
    tail -n +"$first" RELEASE_NOTES.org
} > RELEASE_NOTES.org.new

mv RELEASE_NOTES.org.new RELEASE_NOTES.org
echo "RELEASE_NOTES.org: nouvelle section insérée avant la ligne $first"
