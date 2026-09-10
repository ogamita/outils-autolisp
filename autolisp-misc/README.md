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
- `src/map.lsp`: the Common Lisp `mapc`/`mapl`/`maplist`/`mapcan`/`mapcon`
  family (`mapcar` is already native to AutoLISP). Since AutoLISP has no
  variadic user functions, each one comes in two forms: `(mapX fn list)`
  for a single list, and `(mapX* fn lists)` taking a list of lists.
- `src/aloop.lsp`: `aloop`, nested loops described by a list of clauses
  (`(from start to end)`, `(below end)`, `(in list)`, `(on list)`, ...,
  each optionally taking a `by` step or step function, plus a computed
  `(from start then step-fn bound-kw end)` form), a function port of
  the `rloop` Elisp macro from `~/src/public/emacs/pjb-emacs.el`.
- `docs/autolisp-misc--manual.org`: user-facing documentation for the public API.
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

(load "autolisp-misc/src/map.lsp")

(mapc 'princ '(1 2 3))                             ; 123, => (1 2 3)
(mapc* '+ (list '(1 2 3) '(10 20 30)))              ; => (1 2 3)
(mapl 'princ '(1 2 3))                              ; (1 2 3)(2 3)(3)
(maplist 'reverse '(1 2 3))                         ; => ((3 2 1) (3 2) (3))
(mapcan (function (lambda (x) (list x x))) '(1 2 3)) ; => (1 1 2 2 3 3)
(mapcon 'reverse '(1 2 3))                          ; => (3 2 1 3 2 3)

(load "autolisp-misc/src/aloop.lsp")

(aloop (list '(below 2) '(in (a b)))
       (function (lambda (i s) (princ (list i s)))))
; affiche (0 A)(0 B)(1 A)(1 B)

(aloop (list '(below 10 by 2)) 'princ)              ; => 0 2 4 6 8
(aloop (list '(on (a b c))) 'princ)                 ; => (a b c) (b c) (c)
(aloop (list (list 'from 1 'then (function (lambda (x) (* 2 x))) 'below 100))
       'princ)                                      ; => 1 2 4 8 16 32 64
```

Project file

`autolisp-misc.prj` follows the Autodesk `VLISP-PROJECT-LIST` format used by
the AutoLISP Project Manager and the legacy Visual LISP IDE.

Note:
For Windows VLX builds, Autodesk's Make Application workflow uses an
application make file (`.prv`). The `autolisp-misc.prj` file groups and orders
the library source files; build-specific VLX options can then be adjusted from
the Autodesk tooling.
