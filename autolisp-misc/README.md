autolisp-misc
=============

Small miscellaneous AutoLISP library.

Contents

- `src/browser.lsp`: Unix-like shell on the AutoCAD / BricsCAD process's
  real current directory, via `WScript.Shell`. Exposes `pwd`, `cd`,
  `pushd`, `popd`, `ls`, `cat`, `truename` (alias `path`),
  `user-home-directory` (alias `home`).
- `src/cat.lsp`: Unix-like `cat` helper for printing one file or a list of files.
- `src/format.lsp`: `format`, a small formatter inspired by Common Lisp.
- `docs/user-manual.org`: user-facing documentation for the public API.
- `docs/autolisp-misc--specifications.org`: design specifications for the
  library.
- `autolisp-misc.prj`: AutoLISP project definition for the `autolisp-misc`
  library sources.

Note: `src/fs.lsp` is kept in the repository for the time being but is
no longer part of the project build. It implemented `pwd` / `cd` / `ls`
against a *virtual* current directory (`*misc-cwd*`); `browser.lsp`
supersedes it by acting on the *real* process cwd.

Usage

```lisp
(load "autolisp-misc/src/browser.lsp")

(pwd)
(cd "docs")
(pushd "..")
(popd)
(ls nil)
(ls ':l)
(cat "fic")
(cat '("fic1" "fic2" "ficN"))
(load (path "foo.lsp"))   ; load relative to (pwd)
(truename "../sibling")
(user-home-directory)
(home)

(load "autolisp-misc/src/cat.lsp")

(cat "fic")
(cat '("fic1" "fic2" "ficN"))

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
