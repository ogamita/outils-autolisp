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
autolisp [--autocad|--bricscad] [--quiet|--verbose] [--timeout N] [--bootstrap-phase marker|core|log|full] [--mode automation|batch] [--backend attach|launch] [--bricscad-macos-profile NOM] {source.lsp | -x expression}... [--dwg fichier.dwg] [--main C:MAIN]
autolisp [--autocad|--bricscad] [--quiet|--verbose] [--timeout N] [--bootstrap-phase marker|core|log|full] [--mode automation|batch] [--backend attach|launch] [--bricscad-macos-profile NOM] -i|--interactive [--dwg fichier.dwg]
```

## Sémantique d'exécution
- Les entrées `{source.lsp | -x expression}` sont traitées strictement dans l'ordre.
- Chaque `source.lsp` est exécuté via `(load "...")`.
- Chaque `-x expression` est lu puis évalué comme une forme AutoLISP.
- `-i` / `--interactive` démarre un REPL: le wrapper lit une forme Lisp sur `stdin`, continue la lecture tant que le parenthésage reste incomplet, exécute la forme comme avec `-x`, affiche ensuite les sorties utilisateur et le résultat, puis recommence.
- Le mode interactif est exclusif: il n'accepte pas de `source.lsp` ni de `-x` sur la même ligne de commande.
- Si au moins un fichier `.lsp` a été fourni, le wrapper appelle ensuite `C:MAIN` par défaut, ou la commande passée avec `--main`.
- Si une action échoue, le script continue à construire le résumé, puis renvoie `1`.

## Verbosité
- `--quiet`: supprime les messages d'information et les hints non essentiels; les erreurs restent visibles.
- sans option: mode normal, avec sorties utilisateur et résultats sans labels techniques.
- `--verbose`: affiche les labels structurés (`LOAD`, `EVAL`, `OUTPUT`, `RESULT`, `TOTAL`, etc.) ainsi que davantage de diagnostics shell.

En mode interactif BricsCAD batch sur macOS, le démarrage annonce aussi le moteur effectivement lancé, par exemple:

```text
autolisp: launched BricsCAD 26.0 pid=4724
```

Exemples:

```bash
./autolisp test.lsp
./autolisp lib1.lsp lib2.lsp --main C:RUN
./autolisp -x '(princ (+ 1 2))'
./autolisp init.lsp -x '(setq *x* 42)' test.lsp
./autolisp --interactive
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
- `*AUTOLISP_INPFILE*`
- `*AUTOLISP_LOGDIR*`
- `*AUTOLISP_LOGNAME*`
- `*AUTOLISP_QUIT_ON_FINISH*`

Il définit aussi des helpers dans `run-common.lsp`, notamment:

- `autolisp-log-out`
- `autolisp-log-err`
- `autolisp-set-status`

En mode REPL batch BricsCAD sur macOS, `*AUTOLISP_INPFILE*` sert de canal d'entrée. Le wrapper shell écrit chaque requête dans un fichier temporaire puis le renomme atomiquement vers `input.lsp`, pour éviter que BricsCAD lise une forme partiellement écrite. Le handshake avec `status.txt` utilise des états textuels `READY <n>` et `STOP <n>`.

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
Le `stdout` restitué par le wrapper est reconstruit à partir de `output.txt`.

En particulier, la sortie utilisateur visible (`print`, `princ`, `prin1`, `prompt`) est miroirée directement dans `output.txt` pendant les phases `load`, `eval` et `main`.

Par niveau de verbosité:

- `--quiet` et mode normal:
  - affichent seulement les sorties utilisateur et les valeurs finales;
  - n'affichent pas les labels techniques `STDOUT`, `STDERR`, `RESULT`, `LOAD`, `EVAL`, `MAIN`, `TOTAL`, etc.
- `--verbose`:
  - conserve le format structuré du wrapper;
  - ajoute davantage de diagnostics shell lors des timeouts ou problèmes de lancement.

Exemple normal avec `-x`:

```text
"Hi"
3
```

Exemple `--verbose` avec `-x`:

```text
EVAL (progn (print "Hi") (+ 1 2))
OUTPUT
"Hi"
RESULT 3
TOTAL=1 OK=1 FAIL=0 ERROR=0
```

Le `stderr` contient les messages d'erreur, par exemple:

- `ERROR load ...`
- `ERROR eval ...`
- `ERROR main ...`
- erreurs de lancement du moteur CAD
- timeout d'attente

En mode normal et `--quiet`, ces erreurs restent concises. En `--verbose`, elles sont accompagnées des détails structurés déjà présents sur `stdout`, et des diagnostics shell supplémentaires si nécessaire.

## Répertoire de travail
Chaque exécution crée un répertoire temporaire sous:

- `AUTOLISP_WORKDIR`, si défini
- sinon `autolisp-script/.autolisp-runs`
- exception: en mode BricsCAD macOS `batch`, le défaut devient `${TMPDIR:-/tmp}/autolisp-runs` pour éviter les problèmes de chargement depuis le dossier du repo

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
- `AUTOLISP_MODE`: `auto`, `automation`, `batch`
- `AUTOLISP_BACKEND`: `attach`, `launch`
- `BRICSCAD_MACOS_PROFILE`: nom du profil BricsCAD pour le mode batch macOS
- `AUTOLISP_BOOTSTRAP_PHASE`: `marker`, `core`, `log`, `full`
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
  - en mode COM, le wrapper envoie maintenant exactement `(load ".../run-common.lsp")` suivi d'un retour chariot, sans suffixe parasite
- En mode COM `attach`, le wrapper n'ordonne pas la fermeture de BricsCAD à la fin.

### macOS
- BricsCAD expose maintenant deux modes explicites:
  - `--mode automation`: envoie `(load ".../run-common.lsp")` à une session GUI via `osascript`
  - `--mode batch`: lance une nouvelle instance avec `-b run.scr`
- `--bricscad-macos-profile NOM` ajoute `-P NOM` au lancement batch macOS pour imposer un profil BricsCAD stable.
- En mode `automation`, le wrapper commence par envoyer `_.COMMANDLINE` puis la commande `(load ".../run-common.lsp")`, afin d'afficher et focaliser la ligne de commande avant l'injection; `--backend launch` ouvre BricsCAD automatiquement avant l'injection et `--backend attach` échoue si aucune instance n'est déjà ouverte.
- En mode `batch`, le wrapper continue à faire toute l'I/O via `output.txt`, `errors.txt` et `status.txt`; BricsCAD ne fournit pas de sortie standard exploitable.
- En mode `batch` avec `-i`, le wrapper garde une seule instance BricsCAD active et implémente un REPL via `input.lsp` + `status.txt`.
- En mode BricsCAD macOS `batch`, `run.scr` charge directement `run-common.lsp` puis termine par `(command "_QUIT" "_Y")` pour fermer l'instance lancée. `_.COMMANDLINE` reste réservé au mode `automation`; en pratique il perturbe le démarrage via `-b`.
- Le bootstrap `automation` dépend des autorisations Accessibilité et reste plus fragile qu'un lancement direct.
- Sous BricsCAD, le workspace doit être `2D Drafting`. Le workspace `2D Drafting (Modern)` peut empêcher l'injection de la commande et provoquer un timeout avec `status.txt` restant à `__PENDING__`.
- En cas de timeout sans aucune sortie ni erreur, le wrapper affiche un hint spécifique pour ce cas.

### Phases de bootstrap
- `full`: comportement normal, avec setup du log CAD, capture de `print` / `princ` / `prompt`, et REPL batch.
- `log`: exécute les actions sans redéfinir `print` / `princ` / `prompt`, mais garde le setup du log CAD.
- `core`: exécute les actions avec l'I/O fichier de base, sans setup du log CAD ni redéfinition des sorties standard Lisp.
- `marker`: n'exécute pas les actions demandées; écrit seulement un marqueur de bootstrap puis un statut final, utile pour vérifier que `run-common.lsp` démarre bien.
- Le mode interactif `-i` impose `--bootstrap-phase full`.

### Unix hors Windows
- Si `AUTOCAD_EXE` est fourni, le wrapper tente un lancement direct avec `/b`.
- Si `BRICSCAD_EXE` est fourni, le wrapper tente un lancement direct avec `-b run.scr`.
- Sinon, pour AutoCAD ou BricsCAD sur macOS, il bascule sur le fallback UI si disponible.

## Exemples courants

BricsCAD avec la commande par défaut:

```bash
./autolisp --bricscad ./autolisp.lsp
```

BricsCAD macOS en batch:

```bash
./autolisp --bricscad --mode batch ./autolisp.lsp
```

BricsCAD macOS en batch avec profil dédié:

```bash
./autolisp --bricscad --mode batch --bricscad-macos-profile Lisp ./autolisp.lsp
```

BricsCAD macOS en attachement à une session déjà lancée:

```bash
./autolisp --bricscad --mode automation --backend attach ./autolisp.lsp
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

REPL interactif:

```bash
./autolisp --interactive
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
make test-ci
```

La cible `test-ci` est la cible agrégée prévue pour l'automatisation:

- avec `TEST_BACKEND=fake`, elle exécute uniquement la suite fake (`test-fakecad`)
- avec `TEST_BACKEND=real`, elle exécute les suites réelles (`test-bricscad` et `test-autocad`)

Sous Windows, si `make` n'est pas disponible, des scripts PowerShell équivalents sont fournis dans `make/`:

```powershell
.\make\test-ci.ps1
.\make\test-fake.ps1
.\make\test-bricscad.ps1
.\make\test-autocad.ps1
```

Ces scripts chargent automatiquement `make/env.ps1` avant d'exécuter les tests.

Variables utiles:

- `CAD=--bricscad` ou `CAD=--autocad`
- `TEST_TIMEOUT=<secondes>`
- `TEST_BACKEND=fake` pour exécuter la suite contre le faux moteur de test
- `TEST_RUN_ARGS=--verbose` pour afficher plus de détails en cas d'échec

Sous macOS, `make test-bricscad` sépare maintenant les cas BricsCAD en deux invocations explicites:

- `make test-bricscad-macos-batch`
- `make test-bricscad-macos-automation-attach`

La cible agrégée `make test-bricscad` lance les deux. Le mode `automation attach` exige qu'une session BricsCAD soit déjà ouverte; si ce n'est pas le cas et que le terminal est interactif, le runner affiche un message et attend que BricsCAD soit lancé avant de continuer.

### `make/env.ps1`

Le fichier `make/env.ps1` centralise les variables d'environnement utiles pour le debug sous PowerShell. Il suffit de décommenter ou modifier les lignes voulues, par exemple:

- `AUTOLISP_KEEP_WORKDIR`
- `AUTOLISP_VERBOSE`
- `AUTOLISP_WAIT_SECS`
- `BRICSCAD_EXE`
- `AUTOCAD_EXE`
- `AUTOCAD_ACCORECONSOLE`

Exemple de workflow Windows:

1. éditer `make/env.ps1`
2. décommenter `AUTOLISP_KEEP_WORKDIR=1` et `AUTOLISP_VERBOSE=1`
3. lancer `.\make\test-bricscad.ps1`

Depuis Git Bash sous Windows, les trampolines bash correspondants sont aussi disponibles:

```bash
./make/test-ci
./make/test-fake
./make/test-bricscad
./make/test-autocad
```

La suite couvre actuellement:

- `-x` avec sortie visible
- `-x` sans sortie visible
- chargement d'un fichier `.lsp`
- `--main` avec point d'entrée personnalisé
- sortie produite pendant le `load` d'un fichier
- mode interactif `--interactive`, y compris une forme multi-lignes et un échec d'évaluation

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
- le bootstrap `automation` sur macOS
- COM sous Windows
- les particularités UI ou workspace des applications CAD

En revanche, il teste très bien la logique interne du wrapper:

- génération de `run-common.lsp`
- gestion des actions `load` et `-x`
- boucle REPL `--interactive`
- appel de `MAIN` / `--main`
- reconstruction de `stdout`
- comparaison des sorties attendues

Utilisation explicite:

```bash
make test-ci TEST_BACKEND=fake
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
  - relancer avec `AUTOLISP_KEEP_WORKDIR=1 AUTOLISP_VERBOSE=1` ou `--verbose`
  - inspecter ensuite `output.txt`, `errors.txt`, `status.txt` et `logs/`
- Timeout BricsCAD macOS avec `status.txt=__PENDING__` et fichiers de sortie vides
  - vérifier que le workspace actif est `2D Drafting`
  - éviter `2D Drafting (Modern)`

Commande de debug typique:

```bash
AUTOLISP_KEEP_WORKDIR=1 AUTOLISP_VERBOSE=1 ./autolisp --bricscad ./autolisp.lsp
```
