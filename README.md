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

## Tags et branches

Depuis la version 1.9.0, le dépôt suit les [règles de version](https://gitlab.com/informatimago/rules/-/blob/master/version-rules.md) communes.

| Repère | Nature | Rôle |
| --- | --- | --- |
| `release-M.m.d` | **tag annoté** | une version figée, jamais déplacée ni supprimée |
| `version-M.m` | branche | pointeur sur la version la plus récente de la série `M.m` |
| `version-M` | branche | pointeur sur la version la plus récente du majeur `M` |
| `master` | branche | le tronc, là où le développement se fait |
| `maint-M.m` | branche | ligne de maintenance d'une série figée, créée à la demande |
| `fix-*`, `feat-*` | branche | une correction ou une fonctionnalité, éphémère |

Une version est un **tag**, parce qu'elle doit être immuable: une
branche bouge par construction. Un pointeur de série est une
**branche**, parce qu'il doit bouger — et parce que `git fetch` ne met
pas à jour un tag déjà présent localement, ce qui figerait
silencieusement la copie de l'utilisateur. Rien n'est jamais commité
sur `version-M.m` ni `version-M`: ils ne font que se déplacer sur un
commit portant un tag `release-*`.

Pour installer la dernière version de la série 1.9 et suivre ses
corrections:

```sh
git clone -b version-1.9 git@gitlab.com:ogamita/outils-autolisp.git
```

`make check-versions` vérifie les invariants (un `release-*` est bien
un tag, les versions d'une série s'ordonnent par ascendance, chaque
pointeur est exactement sur sa version la plus récente).

### Repères antérieurs — **dépréciés**

Les versions publiées avant 1.9.0 sont marquées `vM.n.p` (`v1.0.0` …
`v1.7.0`), et des branches `release-1.x` / `version-1` ont servi de
pointeurs. **Ces deux formats sont dépréciés: on n'en crée plus.** Les
refs déjà publiées restent en place — les supprimer casserait les
copies déjà récupérées — mais le nom `release-*` est désormais réservé
aux tags.

| Repère | Nature | Rôle historique |
| --- | --- | --- |
| `v1.0.0` … `v1.7.0` | tag figé | les versions publiées de la série 1 |
| `version-1`, `release-1.0` | branche | anciens pointeurs de suivi |
| `tag-version-1`, `tag-release-1.0` | tag figé | anciens tags de suivi |

### Jalons 1.0

Le tableau ci-dessous résume les changements marquants entre les tags actuellement présents. Il s'agit d'un panorama des évolutions majeures de la série 1.0, pas d'un changelog exhaustif ligne par ligne.

| De | Vers | Changement marquant |
| --- | --- | --- |
| `v1.0.0` | `v1.0.10` | Le dépôt est passé d'une base initiale à un `autolisp-script` bien plus complet: ajout de `autolisp-misc/src/cat.lsp` (alors `misc/src/cat.lsp`), support de `--epure`, unification des modes macOS, amélioration des chemins de chargement BricsCAD, ajout du reporting de version, correction du chargement AutoLISP, capture fiable de `princ`, puis gestion correcte de `(princ)` sans argument et stabilisation des sorties interactives. |

## Architecture de chargement

Le chargement est décrit par des définitions de systèmes ALPM
(AutoLISP Package Management, <https://gitlab.com/ogamita/alpm>) :
`outils-autolisp.alpm` à la racine — le système « parapluie » qui
remplace l'ancien `loader.lsp` — et un `<sous-projet>.alpm` dans
chaque sous-projet de bibliothèque AutoLISP (`autolisp-vector`,
`autolisp-hash-table`, `autolisp-introspection`, `autolisp-json`,
`autolisp-doc`, `autolisp-algetypes`, `autolisp-defstruct`, `autolisp-misc`,
`autolisp-test`).

Exemple depuis la racine du dépôt:

```lisp
(alpm-register-directory "/chemin/vers/outils-autolisp")
(alpm-load-system "outils-autolisp")   ; ou un sous-projet seul :
(alpm-load-system "autolisp-json")
```

ALPM est en cours de spécification ; en attendant son
implémentation, les `loader.lsp` de sous-projets restent
utilisables. Ils s'appuient sur le helper commun `cl-loader.lsp`,
qui fournit:

- `*verbose*` pour activer les traces de chargement;
- `clload` pour charger un fichier avec options;
- `clload-files` pour charger une liste de fichiers dans l'ordre;
- `cl-path-join` pour construire les chemins de travail.

## Sous-projets

### `autolisp-script` — **déprécié**

> **Déprécié** : remplacé par **`alfe`** (AutoLISP front-end, projet
> [clautolisp](https://gitlab.com/ogamita/clautolisp)) pour le pilotage CAO, et
> par **`clautolisp`** pour les tests headless. Le binaire
> `autolisp` est désormais un stub ; l'ancien script est conservé sous
> `autolisp-script/autolisp-deprecated`. Voir `autolisp-script/DEPRECATED.md`.

Wrapper CLI pour exécuter du code AutoLISP dans BricsCAD ou AutoCAD, capturer `stdout` / `stderr`, gérer un code de retour shell et proposer un mode interactif.

Points notables:

- support explicite de BricsCAD macOS en mode `automation` ou `batch`;
- REPL interactif avec handshake fichier en mode batch;
- niveaux de verbosité `--quiet`, normal et `--verbose`, avec annonce du moteur BricsCAD et de sa version au démarrage interactif;
- backend `fake-cad` pour tests automatisés sans moteur réel.

Documentation:
- manuel: [autolisp-script/docs/autolisp-script.md](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-script/docs/autolisp-script.md)
- spécifications: [autolisp-script/docs/autolisp-script--specifications.org](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-script/docs/autolisp-script--specifications.org)

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

### `autolisp-algetypes`

Petite bibliothèque de types algébriques immuables : déclaration de types
somme, construction de variantes, champs nommés, filtrage exhaustif et types
usuels `option` / `result`.

Documentation: `autolisp-algetypes/docs/autolisp-algetypes--manual.org`

### `autolisp-vector`

Implémentation d'un vecteur AutoLISP indexé par arbre, utilisé comme brique de base pour d'autres structures.

Documentation: [autolisp-vector/docs/autolisp-vector--manual.org](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-vector/docs/autolisp-vector--manual.org)

### `autolisp-hash-table`

Implémentation d'une table de hashage AutoLISP construite au-dessus de `autolisp-vector`, avec tests et benchmarks.

Documentation: [autolisp-hash-table/docs/autolisp-hash-table--manual.org](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-hash-table/docs/autolisp-hash-table--manual.org)

### `autolisp-introspection`

Bibliothèque de photographie et de comparaison des entités d'un dessin par
handle, avec détail des attributs DXF et xdata modifiés. Le module
`autolisp-test/test-entites.lsp` fournit le DSL d'assertions `attendu-…`.

Documentation: `autolisp-introspection/docs/autolisp-introspection--specifications.org`
et `autolisp-test/docs/autolisp-test--entites.org`.

### `autolisp-json`

Lecture et écriture de fichiers JSON en AutoLISP: sérialisation et désérialisation d'une `sexp` Lisp vers/depuis du JSON. La version 1 traite le document en bloc (un fichier, une `sexp`); une version incrémentale est prévue. La représentation est balisée (`(aj-object ...)`, `(aj-array ...)`, `aj-true`/`aj-false`/`aj-null`) et garantit un aller-retour exact.

Documentation: [autolisp-json/docs/autolisp-json--manual.org](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-json/docs/autolisp-json--manual.org), spécifications: [autolisp-json/docs/autolisp-json--specifications.org](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-json/docs/autolisp-json--specifications.org)

### `autolisp-formatter`

Formateur / pretty-printer AutoLISP écrit en AutoLISP: relecture syntaxique du source (scanner, CST), puis réémission déterministe et idempotente. Trois styles de parenthèses (`cl`, `nail`, et `stacked-nail` accepté en entrée mais jamais émis par défaut), trois politiques de casse avec fichier d'exceptions, normalisation ou préservation des commentaires, fichier de configuration. Les coupures de ligne de l'auteur sont conservées: le formateur ne reflue pas le code.

Lanceur: `autolisp-formatter/scripts/autolisp-format [OPTIONS] FICHIER...` (`--check`, `--in-place`, `--output`).

Documentation: [autolisp-formatter/README.md](autolisp-formatter/README.md), manuel: [autolisp-formatter/docs/autolisp-formatter--manual.org](autolisp-formatter/docs/autolisp-formatter--manual.org), spécifications: [autolisp-formatter/docs/autolisp-formatter--specifications.org](autolisp-formatter/docs/autolisp-formatter--specifications.org)

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
- `make test-bricscad-macos-automation-attach`

La cible agrégée lance d'abord `batch`, puis `automation attach`. Le second mode suppose qu'une session BricsCAD soit déjà ouverte; pour `autolisp-script`, le runner interactif s'arrête et demande d'ouvrir BricsCAD avant de continuer.

En mode BricsCAD macOS `batch`, les `source.lsp` sont maintenant autorisés par défaut. Le wrapper essaie aussi de transformer une erreur fatale de bootstrap ou de `load` en échec propre avec journalisation et sortie explicite de BricsCAD, pour éviter une session bloquée en `BOOTING`.

État des cibles principales:

- `make test-ci` lance notamment `autolisp-algetypes`, `autolisp-vector`, `autolisp-hash-table`,
  `autolisp-introspection`, `autolisp-json`, `autolisp-doc` et `autolisp-misc`;
- [`autolisp-doc/Makefile`](/Users/pjb/works/sncf-reseau/src/outils-autolisp/autolisp-doc/Makefile) expose ses propres tests via `make -C autolisp-doc test`;
- `autolisp-script` propose aussi un backend de vérification sans CAD réel:

```bash
make -C autolisp-script test-fakecad
```

### Compilation et installation de dwg-identifier

dwg-identifier requiert une installation système complète de
clautolisp (sources CL sous
`$(CLAUTOLISP_PREFIX)/share/common-lisp/source/clautolisp/` et
bibliothèques natives libredwg + shim sous
`$(CLAUTOLISP_PREFIX)/lib/clautolisp/<os>/<arch>/`), `/opt/local` par
défaut — le sous-module `third-party/clautolisp` a été supprimé.
`make check-clautolisp` vérifie cette installation.

```bash
cd outils-autolisp
make -C dwg-identifier clean build test   # construire et tester
sudo make install-programs                # installer (depuis la racine)
dwg-identify ~/works/sncf-reseau/dwg/pjb/2018.dwg
```

L'installation se pilote depuis la **racine**, qui possède l'unique
arbre de staging de la phase `programs`: `make -C dwg-identifier
install` ne fait que renvoyer vers elle. C'est la règle B2 des
[règles de construction](https://gitlab.com/informatimago/rules/-/blob/master/build-rules.md):
`install` copie un arbre déjà construit et ne compile rien, pour que
`sudo make install` ne laisse jamais de fichiers appartenant à root
dans l'arbre de travail.

(`PREFIX` et `CLAUTOLISP_PREFIX` valent `/opt/local` par défaut ;
pour développer contre un checkout de clautolisp :
`make CLAUTOLISP_SOURCES=/chemin/checkout/clautolisp …`.)

## Construction, installation, publication

Le `Makefile` racine est structuré en **phases** — `libraries`
(les systèmes ALPM), `programs` (`dwg-identify`) et `documentation`
(les manuels) — et en quatre **verbes** définis sur chacune:
`build-`, `stage-`, `install-`, `release-`.

```bash
make help                  # les cibles et ce qu'elles font
make build                 # bibliothèques + programmes (pas la doc, lente)
make build-documentation   # les 10 manuels x 4 formats
sudo make install          # tout installer dans /opt/local
make install PREFIX=~/opt  # ou ailleurs
make release               # les artefacts sous dist/
make uninstall             # retirer exactement ce qu'install a posé
```

Chaque phase s'installe **seule** (`make install-libraries`,
`install-programs`, `install-documentation`): une machine sans Emacs ni
TeX installe quand même les bibliothèques et le programme.

Ce qui atterrit sous `$PREFIX`:

| Chemin | Contenu |
| --- | --- |
| `share/autolisp/<système>/` | les systèmes ALPM et leurs sources |
| `share/autolisp/outils-autolisp.alpm` | le système parapluie |
| `bin/dwg-identify` | le programme |
| `share/doc/outils-autolisp/<composant>/` | manuel en `.org`, `.pdf`, HTML une page et `html/` paginé |
| `share/info/<composant>.info` | les manuels Info, enregistrés dans `share/info/dir` |
| `share/doc/outils-autolisp/manifest-<phase>.txt` | le manifeste de provenance (dépôt, tag, commit) |

Enregistrer `$PREFIX/share/autolisp` auprès d'ALPM suffit ensuite à
rendre chaque système chargeable:

```lisp
(alpm-register-directory "/opt/local/share/autolisp")
(alpm-load-system "autolisp-vector")
```

### Documentation

Chaque système et chaque programme a un manuel
`<composant>/docs/<composant>--manual.org`, rendu par
`make build-documentation` en quatre formats: PDF (export LaTeX
d'org), Info, une page HTML unique, et un répertoire `html/` d'une page
par section. Les trois derniers passent par le même `.texi` produit par
org, de sorte que les formats Info et HTML sont structurellement
identiques.

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
