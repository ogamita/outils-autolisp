# make/

Scripts PowerShell de remplacement pour les cibles `make` sous Windows, quand `make` n'est pas disponible.

## Scripts disponibles

- `test-ci.ps1` : exécute la séquence complète prévue pour la CI
- `test-fake.ps1` : exécute les tests avec le faux backend CAD
- `test-bricscad.ps1` : exécute les tests BricsCAD
- `test-autocad.ps1` : exécute les tests AutoCAD

## Environnement partagé

Tous les scripts chargent automatiquement `env.ps1`:

```powershell
. "$PSScriptRoot\env.ps1"
```

`env.ps1` permet de définir facilement les variables utiles pour le debug local, par exemple:

- `AUTOLISP_KEEP_WORKDIR`
- `AUTOLISP_VERBOSE`
- `AUTOLISP_WAIT_SECS`
- `BRICSCAD_EXE`
- `AUTOCAD_EXE`
- `AUTOCAD_ACCORECONSOLE`

## Exemples

Suite fake:

```powershell
.\make\test-fake.ps1
```

Tests BricsCAD avec workdir conservé:

1. éditer `.\make\env.ps1`
2. décommenter:

```powershell
$env:AUTOLISP_KEEP_WORKDIR = "1"
$env:AUTOLISP_VERBOSE = "1"
```

3. lancer:

```powershell
.\make\test-bricscad.ps1
```
