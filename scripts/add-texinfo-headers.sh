#!/bin/sh
# Ensure every <component>/docs/<component>--manual.org carries the
# Texinfo metadata the Info build needs.
#
#   sh scripts/add-texinfo-headers.sh
#
# Four keywords, all consumed by org-texinfo's exporter:
#
#   TEXINFO_FILENAME      the manual's own name for itself (@setfilename).
#                         It MUST match the installed file name, because
#                         the dir entry below points at it: with a
#                         mismatch, `info <component>' finds the dir
#                         entry and then fails to open the manual.
#   TEXINFO_DIR_CATEGORY  the section of share/info/dir the manual
#   TEXINFO_DIR_TITLE     is registered under by install-info, and the
#   TEXINFO_DIR_DESC      line it appears as.
#
# Without them a manual lands under "Misc" with a useless entry.
#
# Idempotent, key by key: a keyword already present is left as it is,
# only the missing ones are inserted. The org sources of this
# repository are stored with CRLF (AGENTS.md, .gitattributes), so each
# inserted line takes the line ending the file's front matter uses.

set -eu

cd "$(dirname "$0")/.."

for org in */docs/*--manual.org ; do
    [ -f "$org" ] || continue
    component=$(basename "$org" | sed 's/--manual\.org$//')
    desc=$(sed -n 's/^ *description *"\([^"]*\)".*/\1/p' \
               "$component/$component.alpm" 2>/dev/null | head -1)
    [ -n "$desc" ] || desc="Manuel utilisateur de $component"

    added=
    for key in TEXINFO_FILENAME TEXINFO_DIR_CATEGORY TEXINFO_DIR_TITLE TEXINFO_DIR_DESC ; do
        grep -q "^#+$key:" "$org" && continue
        case $key in
            TEXINFO_FILENAME)     value="$component.info" ;;
            TEXINFO_DIR_CATEGORY) value="outils-autolisp" ;;
            TEXINFO_DIR_TITLE)    value="$component: ($component)" ;;
            TEXINFO_DIR_DESC)     value="$desc" ;;
        esac
        # Insert after the last #+KEYWORD: line of the front matter.
        # $2 holds that line's ending (Perl keeps the final iteration
        # of a capture inside a repeated group), so the inserted line
        # gets the SAME ending as its neighbours.
        #
        # [^\r\n] and not [^\n]: a greedy [^\n]* eats the \r of a CRLF
        # line, leaving (\r?\n) to capture a bare \n and producing a
        # file with MIXED endings. Emacs then decodes it as unix, every
        # line keeps a literal \r, and org stops recognising
        # `#+end_src' — silently exporting every source block as plain
        # text. That failure shows up only in the rendered manual, so:
        # do not "simplify" this character class.
        KEY="$key" VALUE="$value" perl -i -0pe '
            my $k = $ENV{KEY};
            my $v = $ENV{VALUE};
            s{\A((?:\#\+[A-Z_]+:[^\r\n]*(\r?\n))+)}
             {$1 . "\#+$k: $v$2"}e;
        ' "$org"
        added="$added $key"
    done
    if [ -n "$added" ] ; then
        echo "$org:$added"
    else
        echo "$org: already complete"
    fi
done
