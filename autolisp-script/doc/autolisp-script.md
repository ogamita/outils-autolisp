# autolisp-script

## Objectif
`autolisp-script/autolisp` est un wrapper en ligne de commande pour exécuter un fichier AutoLISP dans AutoCAD ou BricsCAD, puis renvoyer :
- la sortie de test/log sur `stdout`
- les erreurs sur `stderr`
- le code de retour lu depuis un fichier d’état

C’est l’outil utilisé par `make test` dans ce dépôt.

## Emplacement
- Script : `outils/autolisp-script/autolisp`
- Exemples : `outils/autolisp-script/autolisp-examples.org`

## Utilisation
```bash
outils/autolisp-script/autolisp [--autocad|--bricscad] source.lsp [--dwg fichier.dwg] [--main C:MAIN]
```

## Contrat attendu côté LISP
Votre script doit exposer une commande principale (par défaut `C:MAIN`).

Le wrapper injecte :
- `*AUTOLISP_OUTFILE*`
- `*AUTOLISP_ERRFILE*`
- `*AUTOLISP_STATUSFILE*`

Votre code LISP doit écrire le statut final (`0` si succès, non-zéro sinon) dans `*AUTOLISP_STATUSFILE*`.

## Commandes courantes
Exécution standard (`C:MAIN`) :
```bash
outils/autolisp-script/autolisp --bricscad schms/test-unitaire.lsp
```

Point d’entrée personnalisé :
```bash
outils/autolisp-script/autolisp --bricscad schms/test-unitaire.lsp --main C:RUN_TESTS
```

AutoCAD Core Console sous Windows (DWG obligatoire) :
```bash
set AUTOCAD_ACCORECONSOLE=C:/Program Files/Autodesk/AutoCAD 2025/accoreconsole.exe
outils/autolisp-script/autolisp --autocad schms/test-unitaire.lsp --dwg path/to/blank.dwg
```

## Variables d’environnement
- `AUTOCAD_ACCORECONSOLE` : chemin vers `accoreconsole.exe` (Windows)
- `BRICSCAD_EXE` : chemin vers `bricscad.exe` (Windows)
- `AUTOLISP_DWG` : DWG par défaut en mode AutoCAD
- `AUTOLISP_WORKDIR` : répertoire parent des exécutions temporaires
- `AUTOLISP_KEEP_WORKDIR=1` : conserver le répertoire temporaire (debug)
- `AUTOLISP_VERBOSE=1` : afficher le chemin du répertoire conservé
- `AUTOLISP_WAIT_SECS` : timeout d’attente du fallback macOS

## Notes par plateforme
- Windows :
  - AutoCAD passe par `accoreconsole.exe`.
  - BricsCAD passe par `/B`.
- macOS :
  - Le script utilise un fallback UI via `osascript` (plus fragile).
  - Pour diagnostiquer, relancer avec `AUTOLISP_KEEP_WORKDIR=1`.

## Dépannage
- `Missing source.lsp` ou `Not found` :
  - vérifier le chemin passé à `autolisp`.
- Erreur AutoCAD liée au DWG :
  - fournir `--dwg` ou définir `AUTOLISP_DWG`.
- Pas de sortie et code non-zéro :
  - conserver le workdir puis inspecter `output.txt`, `errors.txt`, `status.txt`.
  - exemple :
  ```bash
  AUTOLISP_KEEP_WORKDIR=1 AUTOLISP_VERBOSE=1 outils/autolisp-script/autolisp --bricscad schms/test-unitaire.lsp
  ```
