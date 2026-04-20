misc
====

Small miscellaneous AutoLISP library.

Contents

- `src/cat.lsp`: Unix-like `cat` helper for printing one file or a list of files.
- `src/fs.lsp`: Unix-like `pwd`, `cd`, `ls` helpers sharing a virtual
  current directory.
- `docs/user-manual.org`: user-facing documentation for the public API.
- `misc.prj`: AutoLISP project definition for the `misc` library sources.

Usage

```lisp
(load "misc/src/cat.lsp")

(cat "fic")
(cat '("fic1" "fic2" "ficN"))

(load "misc/src/fs.lsp")

(pwd)
(cd "docs")
(ls nil)
(ls ':l)
```

Project file

`misc.prj` follows the Autodesk `VLISP-PROJECT-LIST` format used by the
AutoLISP Project Manager and the legacy Visual LISP IDE.

Note:
For Windows VLX builds, Autodesk's Make Application workflow uses an
application make file (`.prv`). The `misc.prj` file groups and orders the
library source files; build-specific VLX options can then be adjusted from the
Autodesk tooling.
