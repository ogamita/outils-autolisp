# clautolisp DXF writer: emit `\U+XXXX` escapes for out-of-code-page characters

> **Status:** proposed (clautolisp `drawing` enhancement that edward needs for the
> mean-time "export DXF → BricsCAD/AutoCAD → R2018 DWG" workflow).

## Problem

`edward export` writes a drawing as ASCII DXF via clautolisp's
`dxf-write-drawing`. AutoCAD/BricsCAD ASCII DXF is **code-page based** (here
`$DWGCODEPAGE = ANSI_1252`), and represents any character **outside** the code
page with an `\U+XXXX` escape (e.g. `\U+2017`). clautolisp's DXF writer does not
do this escaping, so:

- `--encoding cp1252` / `--encoding latin-1` **fail** on the first
  out-of-code-page character (SBCL raises an encoding error). Confirmed on
  `N1A 1.DWG`: a single character, **U+2017 DOUBLE LOW LINE `‗` (×14)**, is
  outside cp1252 and aborts the whole write.
- `--encoding utf-8` succeeds (lossless) but may not be read correctly by CAD,
  which expects code-page bytes, not UTF-8, in an ANSI_1252-declared DXF.

So today only UTF-8 export is reliable, and its CAD-acceptance is unverified.

## Desired behaviour

When writing ASCII DXF in a code page (cp1252 etc.), encode each string char in
the code page when possible, and emit `\U+XXXX` (uppercase hex, AutoCAD form)
for any char the code page cannot represent. Symmetrically, the DXF **reader**
should decode `\U+XXXX` back to the character (so round-trips are clean).

## Where

`third-party/clautolisp/clautolisp/clautolisp/drawing/source/dxf.lisp` — the
string-writing path of `dxf-write-drawing-to-stream` (and the matching reader for
decode). Likely a small per-string transform: map the Lisp string to
`(code-page-bytes | \U+XXXX)` before emission, keyed off the chosen
`external-format` / the drawing's `drawing-codepage`.

## Acceptance

- `edward export --encoding cp1252 "N1A 1.DWG"` succeeds; `‗` appears as
  `\U+2017`; accented French (é, è, …) appears as single cp1252 bytes.
- BricsCAD/AutoCAD open the result and re-save it as native R2018 DWG with text
  intact (the empirical CAD test this unblocks).
- DXF read of such a file decodes `\U+2017` back to U+2017 (round-trip).

## Note

This is independent of the libredwg R2018 *write* gap (see
`libredwg-r2018-write-encoder.md`): even with a perfect DXF, native DWG still
needs the libredwg encoder; this issue is only about making the **DXF** edward
emits acceptable to CAD.
