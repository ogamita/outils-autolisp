autolisp-misc
=============

Small miscellaneous AutoLISP library.

Contents

- `src/cat.lsp`: Unix-like `cat` helper for printing one file or a list of files.
- `src/format.lsp`: `format`, a small formatter inspired by Common Lisp.
- `src/fs.lsp`: Unix-like `pwd`, `cd`, `ls` helpers sharing a virtual
  current directory.
- `docs/user-manual.org`: user-facing documentation for the public API.
- `docs/autolisp-misc--specifications.org`: design specifications for the
  library.
- `autolisp-misc.prj`: AutoLISP project definition for the `autolisp-misc`
  library sources.

Usage

```lisp
(load "autolisp-misc/src/cat.lsp")

(cat "fic")
(cat '("fic1" "fic2" "ficN"))

(load "autolisp-misc/src/fs.lsp")

(pwd)
(cd "docs")
(ls nil)
(ls ':l)

(load "autolisp-misc/src/format.lsp")

(format "~A = ~D" '("pommes" 12))
```

Project file

`autolisp-misc.prj` follows the Autodesk `VLISP-PROJECT-LIST` format used by
the AutoLISP Project Manager and the legacy Visual LISP IDE.

Note:
For Windows VLX builds, Autodesk's Make Application workflow uses an
application make file (`.prv`). The `autolisp-misc.prj` file groups and orders
the library source files; build-specific VLX options can then be adjusted from
the Autodesk tooling.
