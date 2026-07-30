# dwg-identifier

Identify which SNCF EPURE application produced a DWG/DXF drawing —
**SCHMS**, **SCHME**, **SCHMIEUX**, **PV**, or the **EPURE** umbrella —
by reading the registered-application (APPID) table the application
stamps into every drawing it touches.

It is a small Common-Lisp tool built on the clautolisp drawing
library (a required system dependency, installed under `/opt/local`
by default): clautolisp reads the drawing (DXF natively, DWG via its
`clautolisp/drawing-dwg` system + libredwg) into a backend-independent
value, and this tool classifies it. No AutoLISP and no running CAD are
involved.

## How identification works

Each application registers an eponymous appid family in the drawing's
APPID table (and tags its objects with xdata under that appid):

| Application | appid family |
|-------------|--------------|
| SCHMS       | `SCHMS`, `SCHMSPLUS`, `SCHMS_*` |
| SCHME       | `SCHME`, `SCHME+`, `SCHMEPLUS` |
| SCHMIEUX    | `SCHMIEUX`, `SCHMIEUX_*` |
| PV          | `PV`, `PVPLUS`, `PV2010`, `PV-SUITE`, `PVSX_*` |
| EPURE       | `EPURE`, `EPURELIB`, `EPURE_*`, `SNCF-Com_*` (shared umbrella) |

The originating application is read straight off the APPID table. A
`+`/`PLUS` appid marks the "plus" edition; the EPURE umbrella appids
are reported separately (a drawing can be e.g. *SCHMS+ (EPURE)*).

## Usage

```
make run ARGS='drawing.dwg another.dxf'
make run ARGS='--json drawing.dwg'
```

Example:

```
$ make run ARGS='N1A_V1.dwg'
N1A_V1.dwg
  application : SCHMS+ (EPURE)
  format      : DWG
  entities    : 37329
  appids      : ACAD … SCHMS SCHMSPLUS SNCF-Com_Echelle SNCF-Com_Vers-Dwg-Epure
```

## Build / dependencies

- **clautolisp** (its `drawing` + `drawing-dwg` systems) is a required
  **system installation** — it is no longer vendored as a submodule. A
  complete clautolisp installation under `CLAUTOLISP_PREFIX` (default
  `/opt/local`) provides both:
  - the CL sources: `$(CLAUTOLISP_PREFIX)/share/common-lisp/source/clautolisp/`
  - the native DWG codec (libredwg + CFFI shim):
    `$(CLAUTOLISP_PREFIX)/lib/clautolisp/<os>/<arch>/`

  Both ship in a clautolisp release "libraries" artefact. The Makefile
  adds the installed source directory to quicklisp's local-projects so
  ASDF finds the systems; `make check-clautolisp` verifies the
  installation. The executable is built against those installed
  sources, so at run time it derives the native-library directory from
  them: the installed `dwg-identify` depends only on the clautolisp
  installation, never on a source checkout.
- Developers hacking on clautolisp itself can build against a checkout
  instead: `make CLAUTOLISP_SOURCES=/path/to/checkout/clautolisp …`
  (build the shim there with `make build-libredwg`, which forwards to
  the checkout, or set `CLAUTOLISP_DWG_LIBDIR` at run time).
- **CFFI** (Quicklisp). DXF input needs neither libredwg nor the shim.
- `make test` runs the unit tests (synthetic drawings; no libredwg
  needed).

## Status

Classifies SCHMS / SCHME / SCHMIEUX / PV / EPURE and reports the
edition (`+`) and EPURE umbrella. Per-object metadata extraction
(decoding the SCHMS+ instance xdata into class/field values) is out of
scope for now — see `docs/dwg-identifier.org`.
