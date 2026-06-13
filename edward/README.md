# edward

Read, dump (JSON) and — eventually — transfer the application data that
the SNCF **EPURE** applications (**SCHMS**, SCHME, SCHMIEUX, **PV**) store
*inside* their DWG/DXF drawings: xdata attached to entities, and XRECORDs
held in named dictionaries under the named-object dictionary (NOD).

It is a Common-Lisp subproject of `outils-autolisp`, built — like its
sibling [dwg-identifier](../dwg-identifier) — on the
[clautolisp](../third-party/clautolisp) drawing library (vendored as a git
submodule). clautolisp reads the drawing (DXF natively, DWG via its
`clautolisp/drawing-dwg` system + the vendored libredwg) into a
backend-independent value; edward extracts, groups and decodes the stored
data. No AutoLISP and no running CAD are involved.

See [`docs/edward-specifications.org`](docs/edward-specifications.org) for
the full design (data model, v1 dump, v2 transfer, plan).

## Status — v1 (in progress)

Working today (the generic **raw** layer — lossless, application-agnostic):

- `edward dump FILE…` — JSON dump of a drawing:
  - `drawing` metadata + the full APPID table;
  - `dictionaries[]` — every NOD named-dictionary leaf (e.g. the SCHMS
    `SCHMS_LIGNES` / `SCHMS_VOIES` / `SCHMS_POSTES` tables) with its
    XRECORD data verbatim;
  - `entities[]` — each entity's handle / type / layer / block and its
    xdata **grouped by appid** (`--raw` adds the full DXF data).
- `edward list FILE…` — one-line classification per drawing (reuses
  dwg-identifier).
- `edward roundtrip FILE…` — read → rewrite → reread and check for loss
  (the v1 acceptance test, §4.4 of the spec).

Not yet: SCHMS schema-aware decoding (`*_ATTR.LSP`), PV decoding, and all
of v2 (select / copy / merge / replace / prune between drawings).

```
make build                 # build the bin/edward executable
make test                  # unit tests (synthetic DXF; no libredwg needed)
./bin/edward dump --no-entities "N1A 1.DWG"      # drawing-level data only
./bin/edward dump --app … --raw FILE.dwg
./bin/edward roundtrip --via dxf FILE.dwg
```

## DWG read/write notes (v1 round-trip findings)

The v1 round-trip acceptance test surfaced two distinct issues:

1. **Encoding — fixed in clautolisp (v1.2.7).** The DWG path goes
   DWG↔DXF through libredwg, which transcodes strings to **UTF-8** and
   records `$DWGCODEPAGE ANSI_1252`. clautolisp had been reading that
   interchange as ISO-8859-1 and ignoring the code page, so accented text
   mojibaked (`kilomètre` → `kilomÃ¨tre`). Fixed: the DWG codec now reads
   /writes the interchange as UTF-8 and captures `$DWGCODEPAGE` into
   `drawing-codepage`. `edward dump` now yields correct accented text and
   `"codepage": "ANSI_1252"`.

2. **Native DWG write-back — blocked by libredwg.** These drawings are
   **R2018 (AC1032)**, and libredwg's `dxf2dwg` only writes up to r2004
   (r2018 is "Planned", unimplemented). Downgrading R2018 attribute data
   (embedded `AcDbXrecord` / multiline ATTRIB, DXF code 43) to r2000/r2004
   fails (`Invalid DXF code 43 for ATTRIB`) — reproducible with pure
   standalone `dwg2dxf | dxf2dwg`, no clautolisp involved.

Consequence for v2: edward emits a correctly-encoded **DXF** (which
BricsCAD/AutoCAD open and re-save as R2018 DWG); native DWG write-back
waits on libredwg implementing R2018 write.

## Build / dependencies

- **clautolisp** (`drawing` + `drawing-dwg`) and the sibling
  **dwg-identifier**, made discoverable by the `Makefile` (it adds the
  clautolisp submodule and `../dwg-identifier` to ASDF). Populate the
  submodule once from the repo root:
  ```
  git submodule update --init --recursive third-party/clautolisp
  ```
- **CFFI** (Quicklisp) and a **built libredwg shim** for DWG input —
  `make build-libredwg` (DXF input needs neither).
- `make test` runs the unit tests on synthetic DXF (no libredwg needed).
