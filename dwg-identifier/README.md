# dwg-identifier

Identify which SNCF EPURE application produced a DWG/DXF drawing —
**SCHMS**, **SCHME**, **SCHMIEUX**, **PV**, or the **EPURE** umbrella —
by reading the registered-application (APPID) table the application
stamps into every drawing it touches.

It is a small Common-Lisp tool built on the
[clautolisp](../../../) drawing library: clautolisp reads the drawing
(DXF natively, DWG via its `clautolisp/drawing-dwg` system + the
vendored libredwg) into a backend-independent value, and this tool
classifies it. No AutoLISP and no running CAD are involved.

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

- **clautolisp** (its `drawing` + `drawing-dwg` systems). Not installed
  yet, so the Makefile loads `clautolisp.asd` explicitly. Override the
  location with `make CLAUTOLISP=/path/to/clautolisp …` (default
  `$HOME/src/public/clautolisp`).
- **CFFI** (Quicklisp) and a **built libredwg shim** for DWG input —
  build it once with `make build-libredwg` (DXF input needs neither).
- `make test` runs the unit tests (synthetic drawings; no libredwg
  needed).

## Status

Classifies SCHMS / SCHME / SCHMIEUX / PV / EPURE and reports the
edition (`+`) and EPURE umbrella. Per-object metadata extraction
(decoding the SCHMS+ instance xdata into class/field values) is out of
scope for now — see `docs/dwg-identifier.org`.
