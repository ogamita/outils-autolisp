# autolisp-script

## Objectif
`autolisp` est un wrapper shell qui prépare une exécution AutoLISP dans AutoCAD ou BricsCAD, collecte les sorties dans des fichiers temporaires, puis restitue:

- le journal fonctionnel sur `stdout`
- les erreurs sur `stderr`
- un code de sortie final compatible shell

Le script fabrique à la volée un fichier `run-common.lsp` qui:

- configure les chemins de recherche LISP
- charge et/ou évalue les actions demandées
- appelle éventuellement une commande principale
- écrit un résumé final et un code de statut

## Emplacement
- Wrapper CLI: `autolisp-script/autolisp`
- Exemple de script LISP: `autolisp-script/autolisp.lsp`
- Exemples d'appel: `autolisp-script/autolisp-examples.org`

## Utilisation
```bash
autolisp [--autocad|--bricscad] [--timeout N] {source.lsp | -x expression}... [--dwg fichier.dwg] [--main C:MAIN]
```

## Sémantique d'exécution
- Les entrées `{source.lsp | -x expression}` sont traitées strictement dans l'ordre.
- Chaque `source.lsp` est exécuté via `(load "...")`.
- Chaque `-x expression` est lu puis évalué comme une forme AutoLISP.
- Si au moins un fichier `.lsp` a été fourni, le wrapper appelle ensuite `C:MAIN` par défaut, ou la commande passée avec `--main`.
- Si une action échoue, le script continue à construire le résumé, puis renvoie `1`.

Exemples:

```bash
./autolisp test.lsp
./autolisp lib1.lsp lib2.lsp --main C:RUN
./autolisp -x '(princ (+ 1 2))'
./autolisp init.lsp -x '(setq *x* 42)' test.lsp
```

## Sélection du moteur
- `--autocad` force AutoCAD.
- `--bricscad` force BricsCAD.
- Sans option:
  - sous Windows, le script tente AutoCAD puis BricsCAD selon les exécutables détectés
  - hors Windows, le moteur par défaut est BricsCAD

Codes d'erreur de sélection:

- `2`: argument invalide, fichier introuvable ou option incomplète
- `3`: moteur introuvable ou exécutable manquant

## Contrat côté AutoLISP
Le wrapper injecte les variables globales suivantes dans l'environnement LISP:

- `*AUTOLISP_OUTFILE*`
- `*AUTOLISP_ERRFILE*`
- `*AUTOLISP_STATUSFILE*`
- `*AUTOLISP_LOGDIR*`
- `*AUTOLISP_LOGNAME*`
- `*AUTOLISP_QUIT_ON_FINISH*`

Il définit aussi des helpers dans `run-common.lsp`, notamment:

- `autolisp-log-out`
- `autolisp-log-err`
- `autolisp-set-status`

Le cas standard consiste à exposer une commande `C:MAIN`, par exemple:

```lisp
(defun C:MAIN ( / )
  (autolisp-log-out "Hello from AutoLISP.")
  (autolisp-set-status 0)
  (princ))
```

Le wrapper initialise lui-même le statut à `99`, exécute les actions demandées, puis force un statut final:

- `0` si toutes les actions et l'appel à `MAIN` réussissent
- `1` dès qu'un `load`, un `eval` ou `MAIN` échoue

Autrement dit, un script LISP peut écrire son propre statut intermédiaire, mais le code de sortie final est gouverné par le wrapper.

## Format de sortie
Le `stdout` restitué par le wrapper est structuré à partir du fichier `output.txt`.

En particulier, la sortie utilisateur visible (`print`, `princ`, `prin1`, `prompt`) est maintenant miroirée directement dans `output.txt` pendant les phases `load`, `eval` et `main`. Le wrapper n'a donc plus besoin de dépendre uniquement des journaux de session du CAD pour reconstruire `OUTPUT`.

On retrouve en général:

- `LOAD <chemin>`
- `LOADED <chemin>`
- `EVAL <expression>`
- `RESULT <valeur>`
- `MAIN <commande>`
- `MAIN-RESULT <valeur>`
- `OUTPUT` suivi des lignes écrites par `print` / `princ` / `prin1` / `prompt`
- `TOTAL=<n> OK=<n> FAIL=<n> ERROR=<n>`

Le `stderr` contient les messages écrits dans `errors.txt`, par exemple:

- `ERROR load ...`
- `ERROR eval ...`
- `ERROR main ...`
- erreurs de lancement du moteur CAD
- timeout d'attente

## Répertoire de travail
Chaque exécution crée un répertoire temporaire sous:

- `AUTOLISP_WORKDIR`, si défini
- sinon `autolisp-script/.autolisp-runs`

Ce répertoire contient notamment:

- `run-common.lsp`
- `run.scr`
- `output.txt`
- `errors.txt`
- `status.txt`
- `logs/`

Par défaut il est supprimé en fin d'exécution.

## Variables d'environnement
- `AUTOCAD_ACCORECONSOLE`: chemin vers `accoreconsole.exe`
- `AUTOCAD_COM_MODE`: `auto`, `attach`, `launch`, `off`
- `AUTOCAD_EXE`: chemin vers `acad.exe` ou `acadlt.exe`
- `BRICSCAD_EXE`: chemin vers `bricscad.exe`
- `BRICSCAD_COM_MODE`: `auto`, `attach`, `launch`, `off`
- `AUTOLISP_DWG`: DWG par défaut pour AutoCAD Core Console
- `AUTOLISP_TIMEOUT`: ancien nom de timeout, encore accepté
- `AUTOLISP_WAIT_SECS`: timeout d'attente global, défaut `180`
- `AUTOLISP_WORKDIR`: racine des exécutions temporaires
- `AUTOLISP_KEEP_WORKDIR=1`: conserve le workdir
- `AUTOLISP_VERBOSE=1`: affiche le workdir conservé

## Comportement par plateforme

### Windows
- AutoCAD:
  - tente d'abord un pont COM via `cscript`
  - sinon lance `AUTOCAD_EXE /b`
  - sinon bascule sur `accoreconsole.exe` avec `/i <dwg> /s <script>`
- BricsCAD:
  - tente un pont COM via `cscript`
  - sinon lance `bricscad.exe /B`
- En mode COM `attach`, le wrapper n'ordonne pas la fermeture de BricsCAD à la fin.

### macOS
- Le fallback principal repose sur `osascript` et du pilotage UI.
- Le script active l'application CAD, injecte `(load "...")`, puis attend la mise à jour du fichier de statut.
- Ce mode dépend des autorisations Accessibilité et reste plus fragile qu'un lancement direct.
- Sous BricsCAD, le workspace doit être `2D Drafting`. Le workspace `2D Drafting (Modern)` peut empêcher l'injection de la commande et provoquer un timeout avec `status.txt` restant à `__PENDING__`.
- En cas de timeout sans aucune sortie ni erreur, le wrapper affiche un hint spécifique pour ce cas.

### Unix hors Windows
- Si `AUTOCAD_EXE` ou `BRICSCAD_EXE` est fourni, le wrapper tente un lancement direct avec `/b`.
- Sinon, pour AutoCAD ou BricsCAD sur macOS, il bascule sur le fallback UI si disponible.

## Exemples courants

BricsCAD avec la commande par défaut:

```bash
./autolisp --bricscad ./autolisp.lsp
```

BricsCAD avec expression inline:

```bash
./autolisp --bricscad -x '(progn (print (quote "Hello World")) (print "Hiya!"))'
```

BricsCAD avec chargement multiple puis `C:RUN`:

```bash
./autolisp lib/setup.lsp tests/test-suite.lsp --main C:RUN
```

Évaluation directe sans fichier:

```bash
./autolisp -x '(princ "bonjour")'
```

AutoCAD Core Console sous Windows:

```bash
export AUTOCAD_ACCORECONSOLE="C:/Program Files/Autodesk/AutoCAD 2025/accoreconsole.exe"
./autolisp --autocad ./autolisp.lsp --dwg ./tests/blank.dwg
```

BricsCAD sous Windows:

```bash
export BRICSCAD_EXE="C:/Program Files/Bricsys/BricsCAD V26 en_US/bricscad.exe"
./autolisp --bricscad ./autolisp.lsp
```

## Tests

Depuis `autolisp-script`:

```bash
make test
```

Variables utiles:

- `CAD=--bricscad` ou `CAD=--autocad`
- `TEST_TIMEOUT=<secondes>`
- `TEST_BACKEND=fake` pour exécuter la suite contre le faux moteur de test
- `TEST_RUN_ARGS=--verbose` pour afficher plus de détails en cas d'échec

La suite couvre actuellement:

- `-x` avec sortie visible
- `-x` sans sortie visible
- chargement d'un fichier `.lsp`
- `--main` avec point d'entrée personnalisé
- sortie produite pendant le `load` d'un fichier

### Backend `fake-cad`

Le fichier `tests/fake-cad.sh` est un faux moteur CAD utilisé pour les tests unitaires et la CI.

Son rôle est de simuler l'appel du wrapper vers un exécutable CAD sans lancer réellement BricsCAD ou AutoCAD. Concrètement:

- il vérifie que `autolisp` lui passe bien `/b <run-common.lsp>`
- il inspecte le fichier `run-common.lsp` généré par le wrapper
- il valide que ce fichier contient les formes attendues pour le scénario testé
- il écrit directement dans `OUTFILE`, `ERRFILE` et `STATUSFILE`
- il simule donc le comportement attendu du CAD vu par le wrapper

Ce backend ne teste pas:

- l'intégration réelle avec BricsCAD ou AutoCAD
- `osascript` sur macOS
- COM sous Windows
- les particularités UI ou workspace des applications CAD

En revanche, il teste très bien la logique interne du wrapper:

- génération de `run-common.lsp`
- gestion des actions `load` et `-x`
- appel de `MAIN` / `--main`
- reconstruction de `stdout`
- comparaison des sorties attendues

Utilisation explicite:

```bash
make test TEST_BACKEND=fake
```

En CI GitLab, c'est ce backend qui est utilisé aujourd'hui.

## Dépannage
- `Missing input: provide at least one source.lsp or -x expression`
  - fournir au moins un fichier `.lsp` ou une expression `-x`
- `Not found: ...`
  - vérifier le chemin d'un fichier `.lsp`
- `No engine found...`
  - forcer `--autocad` ou `--bricscad`, puis définir l'exécutable correspondant
- `AutoCAD Core Console needs a DWG`
  - fournir `--dwg` ou définir `AUTOLISP_DWG`
- `ERROR: timeout waiting for CAD runner completion`
  - augmenter `AUTOLISP_WAIT_SECS`
  - relancer avec `AUTOLISP_KEEP_WORKDIR=1 AUTOLISP_VERBOSE=1`
  - inspecter ensuite `output.txt`, `errors.txt`, `status.txt` et `logs/`
- Timeout BricsCAD macOS avec `status.txt=__PENDING__` et fichiers de sortie vides
  - vérifier que le workspace actif est `2D Drafting`
  - éviter `2D Drafting (Modern)`

Commande de debug typique:

```bash
AUTOLISP_KEEP_WORKDIR=1 AUTOLISP_VERBOSE=1 ./autolisp --bricscad ./autolisp.lsp
```
