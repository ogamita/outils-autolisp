# outils-autolisp

Collection d'outils et bibliothèques AutoLISP pour:

- exécuter du code AutoLISP depuis le shell;
- écrire et charger des macros;
- lancer des tests;
- expérimenter des structures de données;
- consulter une base de documentation locale.

## État actuel

Cette semaine, le dépôt a évolué sur quatre axes principaux:

- ajout du sous-projet `autolisp-doc`, avec base documentaire générée, API `documentation` / `describe` / `apropos`, tests et manuel;
- refactorisation des `loader.lsp` autour de [`cl-loader.lsp`](/Users/pjb/works/sncf-reseau/src/outils-autolisp/cl-loader.lsp) et d'une variable globale `*verbose*`;
- amélioration importante de `autolisp-script`, en particulier pour BricsCAD sur macOS et pour le mode interactif avec fake CAD;
- mise à jour des `Makefile` racine et sous-projets pour mieux séparer tests, benchmarks et génération de documentation.

## Architecture de chargement

Les fichiers `loader.lsp` jouent le rôle d'un chargeur déclaratif minimal.
Le helper commun [`cl-loader.lsp`](/Users/pjb/works/sncf-reseau/src/outils-autolisp/cl-loader.lsp) fournit:

- `*verbose*` pour activer les traces de chargement;
- `clload` pour charger un fichier avec options;
- `clload-files` pour charger une liste de fichiers dans l'ordre;
- `cl-path-join` pour construire les chemins de travail.

Exemple depuis la racine du dépôt:

```lisp
(setq *outils-autolisp-path* "/chemin/vers/outils-autolisp")
(setq *verbose* T)
(load (strcat *outils-autolisp-path* "/loader.lsp"))
```

## Sous-projets

### `autolisp-script`

Wrapper CLI pour exécuter du code AutoLISP dans BricsCAD ou AutoCAD, capturer `stdout` / `stderr`, gérer un code de retour shell et proposer un mode interactif.

Points notables:

- support explicite de BricsCAD macOS en mode `osascript` ou `batch`;
- REPL interactif avec handshake fichier en mode batch;
- backend `fake-cad` pour tests automatisés sans moteur réel.

Documentation: [autolisp-script/docs/autolisp-script.md](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-script/docs/autolisp-script.md)

### `autolisp-test`

Petit framework de tests AutoLISP avec suites, assertions et exécution agrégée via `run-suite` et `run-all`.

Documentation: [autolisp-test/docs/autolisp-test.md](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-test/docs/autolisp-test.md)

### `autolisp-macro`

Runtime de macros pour AutoLISP: `defmacro`, expansion de macros, `mload` et support de `quasiquote`.

Le `loader.lsp` du sous-projet s'appuie maintenant sur `clload` et peut être piloté via `*autolisp-macro-path*`.

Documentation: [autolisp-macro/docs/autolisp-macro.md](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-macro/docs/autolisp-macro.md)

### `autolisp-doc`

Couche de documentation interactive pour AutoLISP, alimentée par une base locale extraite de la documentation Autodesk.

Le sous-projet fournit notamment:

- `documentation`;
- `describe`;
- `apropos`;
- `apropos-list`;
- `help`.

Documentation: [autolisp-doc/docs/autolisp-doc--manual.org](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-doc/docs/autolisp-doc--manual.org)

### `autolisp-vector`

Implémentation d'un vecteur AutoLISP indexé par arbre, utilisé comme brique de base pour d'autres structures.

Documentation: [autolisp-vector/docs/autolisp-vector--manual.org](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-vector/docs/autolisp-vector--manual.org)

### `autolisp-hash-table`

Implémentation d'une table de hashage AutoLISP construite au-dessus de `autolisp-vector`, avec tests et benchmarks.

Documentation: [autolisp-hash-table/docs/autolisp-hash-table--manual.org](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-hash-table/docs/autolisp-hash-table--manual.org)

### `autolisp-formatter`

Projet de formateur / pretty-printer AutoLISP. Le dépôt contient surtout les spécifications et le plan de travail.

Documentation: [autolisp-formatter/docs/autolisp-formatter--specifications.org](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-formatter/docs/autolisp-formatter--specifications.org)

### `autolisp-defstruct`

Prototype autour d'une implémentation `defstruct` pour AutoLISP.

Fichier principal: [autolisp-defstruct/defstruct.lsp](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-defstruct/defstruct.lsp)

### `scripts`

Scripts utilitaires orientés documentation PDF sous Windows.

Documentation: [scripts/docs/scripts.md](/Users/pjb/works/sncf-reseau/src/outils-autolisp/scripts/docs/scripts.md)

## Tests et commandes utiles

Depuis la racine:

```bash
make test-ci
make test-bricscad
make bench-bricscad
make docs-pdf
```

Sous macOS, `make test-bricscad` sépare explicitement les runs BricsCAD:

- `make test-bricscad-macos-batch`
- `make test-bricscad-macos-osascript-attach`

La cible agrégée lance d'abord `batch`, puis `osascript attach`. Le second mode suppose qu'une session BricsCAD soit déjà ouverte; pour `autolisp-script`, le runner interactif s'arrête et demande d'ouvrir BricsCAD avant de continuer.

État des cibles principales:

- `make test-ci` lance actuellement `autolisp-script`, `autolisp-vector` et `autolisp-hash-table`;
- [`autolisp-doc/Makefile`](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-doc/Makefile) expose ses propres tests via `make -C autolisp-doc test`;
- `autolisp-script` propose aussi un backend de vérification sans CAD réel:

```bash
make -C autolisp-script test-fakecad
```

## Vérification récente

Vérification effectuée localement sur les modifications récentes:

- comparaison avec `fabrik/develop`;
- revue des fichiers modifiés et ajoutés;
- validation de `autolisp-script` via `make -C autolisp-script test-fakecad`.

Cette vérification couvre les chemins de chargement `loader.lsp` et les scénarios fake CAD BricsCAD / AutoCAD. Elle ne remplace pas une exécution complète sur moteurs réels.

## Auteurs

Pascal Bourguignon <ext.pascal.bourguignon@reseau.sncf.fr>  
aka Pascal Bourguignon <informatimago@gmail.com>

Avec l'aide de ChatGPT/Codex.
