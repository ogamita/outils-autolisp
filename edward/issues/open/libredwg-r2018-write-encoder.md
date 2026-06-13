# Implement complete DWG **write/encode** support for R2018 (AC1032), and the R2004→R2018 family

> **Status:** proposed — to be moved to a fork of GNU LibreDWG and turned into a
> tracking issue + PR series.
> **Audience:** a developer (or coding agent) working in a libredwg fork.
> **Provenance:** distilled from a concrete failure on real AutoCAD **R2018
> (AC1032)** drawings while building `edward` (an external tool that reads/writes
> the data EPURE/SNCF applications store in DWG via libredwg). Line/function
> references are against libredwg **0.13.4** (`0.13.4.8252`); **re-verify against
> your fork's HEAD before starting** — libredwg moves.

## 1. Goal

Make libredwg able to **encode (write)** DWG files for the modern format family
**R2004, R2007, R2010, R2013, R2018** — with **R2018 (AC1032)** as the priority
target — to the same fidelity it already **decodes** them. Concretely:

- `dwg2dxf in.dwg && dxf2dwg -o out.dwg --as r2018 in.dxf` produces a valid
  R2018 DWG;
- `dwgwrite`/`dxf2dwg --as r2018` and the `dwg_encode()` API emit R2018;
- a decode→encode→decode round-trip of a real R2018 file is **stable** (see
  §6 acceptance), and the result **opens in AutoCAD/BricsCAD without
  “drawing needs recovery”.**

The DWG format for these versions is **already understood by libredwg** — the
**decoder** implements it. This is therefore an **encoder-completion** task, not
reverse-engineering.

## 2. Why (motivation)

External tools (here: `edward`, manipulating SNCF “EPURE” application data stored
as XRECORDs/xdata inside DWGs) can faithfully **read** R2018 drawings through
libredwg but cannot **write** them back: libredwg can only encode up to ~R2000
reliably. The practical fallout: any “read → modify → write” workflow on modern
(R2018) production drawings is impossible without round-tripping through a
proprietary CAD app. Completing the encoder removes that dependency for the whole
ecosystem, not just this one tool.

## 3. Current state (0.13.4) — what works, what doesn’t

**Decode:** R2018 read works (verified — `dwg2dxf` on AC1032 files succeeds and
produces correct, UTF-8 DXF with `$DWGCODEPAGE`).

**Encode:** effectively **R2000-only**.

- `programs/dxf2dwg.c` advertises writable versions **r12, r14, r2000
  (default), r2004**; **r2007/r2010/r2013/r2018 are listed as “Planned”
  (unimplemented).** (The `--help` text and the code disagree slightly on
  r2004 — see below — so treat r2000 as the only *reliable* target today.)
- `src/encode.c` (version dispatch, ~lines 3779–3967 in 0.13.4):
  - `VERSIONS (R_2007a, R_2007)` logs *“We don’t encode R2007 sections yet”*
    and **silently downgrades to R_2010** — which itself has no real encoder,
    so this is a dead end.
  - The R_2004+ branch logs *“Writing R2004 sections not yet finished”*.
  - The umbrella capability string (`WE_CAN`, ~line 3482) states libredwg *“is
    only capable of encoding versions r1.1–r2000 (MC0.0–AC1015)”*.
- Net: there is **no R2004+ section-writer pipeline** (the new section-map /
  paged / optionally-compressed-and-encrypted container introduced at R2004 and
  reworked at R2007). R2010/2013/2018 reuse that container with version stamps
  and a handful of object/field deltas, so **the R2004/R2007 section writers are
  the long pole**; the per-version deltas are comparatively small.

### 3a. Concrete blocker we hit (a *separable, smaller* bug worth fixing first)

Round-tripping an R2018 file fails on **multiline attributes** with:

```
ERROR: Invalid DXF code 43 for ATTRIB
ERROR: Failed to decode DXF file
```

Root cause is a **writer/reader asymmetry in the DXF path**, independent of the
binary encoder:

- R2018 ATTRIB/ATTDEF can be **multiline** (`type > 1`), carrying an **embedded
  `AcDbMText` “Embedded Object”** (DXF marker `101 Embedded Object`) with MTEXT
  geometry: `extents_width` = DXF **42**, `extents_height` = DXF **43**, column
  fields **71/72/73**, axis vectors, annotative scale **48**, etc.
  (`include/dwg.h` `Dwg_Entity_ATTRIB` R2018 fields: `type`, `mtext_style`,
  `annotative_data_size/bytes`, `annotative_app`, `annotative_short`;
  `src/dwg.spec` ATTRIB `SINCE (R_2018b)` block — note its `// TODO` markers for
  the embedded MTEXT.)
- `out_dxf.c` (via `dwg.spec`) **emits** those embedded-MText codes (42/43/44/…)
  under the ATTRIB.
- `in_dxf.c` **rejects** them: for any “importable” stable class (ATTRIB
  included), the parser hard-fails on any group code outside the 60–68 window —
  `~lines 12034–12071`, `is_dxf_class_importable(...)` then `goto invalid_dxf;`
  → `LOG_ERROR("Invalid DXF code %d for %s")` → `return NULL` (**aborts the
  whole file**, doesn’t skip the field). Code 43 is simply the first
  out-of-window code encountered.

Real-world footprint is tiny — in a 3124-ATTRIB drawing, only **6** carried the
embedded object — but one is enough to abort the import.

**Sub-fix:** teach `in_dxf.c` to parse the ATTRIB/ATTDEF `101 Embedded Object`
block (the field model already exists in `dwg.spec`/`dwg.h` for decode), or at
minimum to **skip unknown codes for that subclass instead of aborting**. This
alone makes `dxf2dwg` of R2018 drawings succeed (producing an r2000 file today),
and is a good warm-up PR that is useful independently of the binary encoder.

## 4. Scope / work breakdown

Order roughly by dependency. Each item should be its own PR with tests.

**A. DXF-path ATTRIB embedded-object import (the §3a sub-fix).** Smallest,
independently valuable. Lets `dxf2dwg` accept R2018 multiline attributes.

**B. R2004 binary section writer.** Finish the R2004 container in `encode.c`:
the section locator/“section map”, the `SECTION_*` sections (Header, AuxHeader,
Classes, Handles, Template, ObjFreeSpace, Objects/data section), the data-section
paging, and the R2004-specific compression/encryption (mirror the **decoder** in
`src/decode_r2004.c` / `src/decode.c` — it is the ground truth). Target: a
`--as r2004` that libredwg re-reads identically.

**C. R2007 section writer (`encode_r2007.c`).** The biggest piece: R2007
reworked the section system (page map / section map, different
compression, Reed–Solomon-coded system pages). Implement the encoder mirroring
`src/decode_r2007.c`. R2010+ build on this.

**D. R2010 / R2013 / R2018 deltas.** Version stamps (`R_2010`, `R_2013`,
`R_2018b`/`R_2018` ↔ `AC1032`, see the enum in `include/dwg.h` ~lines 290–327),
header/maintenance-version bytes, and the per-version object/field `SINCE(...)`
branches that `dwg.spec` already encodes for decode but that need encode paths
wired/verified (e.g. ATTRIB embedded MTEXT, and any other R2010+/R2018 object &
field additions).

**E. Object/field encode coverage sweep.** Walk `dwg.spec` for `SINCE
(R_2004…R_2018)` / `VERSIONS(...)` branches and ensure each has a working
**encode** path symmetric to its decode (the spec macros are bidirectional, but
some R2018 additions are decode-only with `// TODO`). Pay special attention to
the embedded-MText ATTRIB, annotative objects, and any class added after R2000.

**F. Downgrade policy.** Decide and implement what `--as r2004` does when the
source is R2018 and carries R2018-only constructs (multiline attribs, newer
objects): faithfully **up-convert is the goal**, but a defined, lossy
**down-convert** (e.g. flatten multiline ATTRIB → single-line, preserving the
text) is acceptable as a fallback and should be explicit, logged, and tested —
not a silent corruption.

## 5. Key files / entry points (0.13.4 — verify against HEAD)

- `src/encode.c` — top-level `dwg_encode()`, version dispatch (~3779–3967),
  `WE_CAN` capability string (~3482), R2004+ section assembly (~3945–4084).
- `src/encode_r2007.c` — where the R2007 section encoder belongs (currently
  effectively absent for write).
- `src/decode.c`, `src/decode_r2004.c`, `src/decode_r2007.c` — **the
  authoritative reference**: the encoder must be the inverse of these.
- `src/dwg.spec` — bidirectional field definitions; the `SINCE/VERSIONS`
  branches define the per-version object layouts. ATTRIB block (~188–391) incl.
  `SINCE (R_2018b)` embedded MText.
- `include/dwg.h` — `Dwg_Version_Type` enum (R_2004…R_2018), `Dwg_Entity_ATTRIB`
  / `Dwg_Entity_MTEXT` structs and their R2018 fields.
- `src/in_dxf.c` — the `invalid_dxf` guard (~12034–12071) for item A.
- `src/out_dxf.c` — DXF emitter (already emits the embedded-MText codes).
- `programs/dxf2dwg.c`, `programs/dwgwrite.c` — CLI version validation/listing.

## 6. Acceptance / test strategy

Fidelity target is **not** byte-identity (libredwg never guarantees that); it is
**semantic round-trip stability + CAD acceptance**:

1. **Self round-trip:** for a corpus of real R2018 (AC1032) files,
   `decode(F) → encode(--as r2018) → decode(F')` yields an object graph equal to
   `decode(F)` under libredwg’s existing object-compare (`dwg_compare` / the
   `examples`/`test` harness). No new `ERROR`s; warnings catalogued.
2. **DXF round-trip:** `dwg2dxf F | dxf2dwg --as r2018` succeeds (item A) and the
   result re-reads equal.
3. **CAD acceptance:** the encoded R2018 DWG **opens in AutoCAD 2018+ and
   BricsCAD without “needs recovery”/audit errors**; spot-check that multiline
   attributes, MTEXT, xdata, and named-dictionary XRECORDs survive.
4. **Regression:** existing r12–r2000 encode tests stay green; add r2004/r2007/
   r2010/r2013/r2018 to the `make check` matrix.
5. **Corpus:** include files exercising R2018-only features (multiline
   attributes with `\P`, annotative objects). Provide a generator or check in
   small synthetic samples (a single multiline ATTRIB reproduces item A).

## 7. References

- libredwg’s **own decoder** (`decode*.c`) — primary, exact source of truth.
- libredwg `dwg.spec`, `include/dwg.h` — object/field layouts per version.
- Open Design Alliance, *Open Design Specification for .dwg files* — the
  community DWG format spec covering R2004/R2007/R2010/R2013/R2018 containers
  (section maps, compression, R2007 page system).
- libredwg `NEWS`/`TODO` — prior notes that “2004–2018 encoding” was “in
  progress”; this issue is to finish it.

## 8. Suggested PR sequence

1. **PR1 (item A):** `in_dxf.c` ATTRIB/ATTDEF embedded-object import (+ a tiny
   synthetic multiline-ATTRIB DXF test). Unblocks `dxf2dwg` of R2018 sources.
2. **PR2 (item B):** R2004 section writer + `--as r2004` self-round-trip tests.
3. **PR3 (item C):** R2007 section writer (`encode_r2007.c`).
4. **PR4 (item D+E):** R2010/R2013/R2018 stamps + object/field encode sweep;
   enable `--as r2018`; CAD-acceptance corpus.
5. **PR5 (item F):** explicit, tested downgrade policy + docs (`programs`
   `--help`, `NEWS`).

## 9. Notes for the implementer

- Keep the encoder a strict **inverse of the decoder**; when in doubt, read
  `decode_r2004.c`/`decode_r2007.c` and mirror.
- R2010–R2018 are mostly the R2007 container with new version bytes and a few
  object deltas — once R2004+R2007 sections write correctly, R2018 is close.
- Treat the `WE_CAN` capability string and `dxf2dwg`/`dwgwrite` version lists as
  things to update as each version lands, so the CLI never advertises an
  unfinished target.
- Log, don’t silently downgrade: the current “downgrade R2007→R2010” behavior
  hides failures; make version-handling explicit.
