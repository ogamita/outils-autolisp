# autolisp-test

## Objectif
`autolisp-test` fournit un framework de tests AutoLISP léger :
- gestion de suites
- enregistrement de tests
- assertions
- exécution agrégée (`run-suite`, `run-all`)

## Emplacement
- Framework : `outils/autolisp-test/test-framework.lsp`
- Harnais de projet : `outils/autolisp-test/test-runner.lsp` (voir plus bas)
- Lecture des projets Visual LISP : `outils/autolisp-test/vlisp-project.lsp`
- Exemple : `outils/autolisp-test/test-example.lsp`

## Démarrage rapide
Charger le framework, déclarer les tests, puis lancer :
```lisp
(load "outils/autolisp-test/test-framework.lsp")

(defsuite "math")
(in-suite "math")

(deftest
  "addition"
  (function
    (lambda ()
      (is-equal 3 (+ 1 2))
      (is (= 7 (+ 3 4)))
      (is-not (= 0 (+ 1 2))))))

(run-suite "math")
;; ou :
;; (run-all)
```

## API principale
- Gestion des suites :
  - `(defsuite "nom")`
  - `(in-suite "nom")`
- Déclaration de test :
  - `(deftest "nom" (function (lambda () ... )))`
- Assertions :
  - `(is condition [msg])`
  - `(is-not condition [msg])`
  - `(is-equal attendu obtenu [msg])`
  - `(is-approx attendu obtenu tolerance [msg])`
  - `(signals-error thunk [msg])`
- Exécution :
  - `(run-suite "nom")`
  - `(run-all)`

## Format des résultats
Par test :
- `OK    [suite] test-name`
- `FAIL  [suite] test-name -- ...`
- `ERROR [suite] test-name -- ...`

Par suite :
- `---- Suite [suite] ----`
- `Total: N  OK: N  FAIL: N  ERROR: N`

Compteurs globaux :
- `*t:last-total*`
- `*t:last-ok*`
- `*t:last-fail*`
- `*t:last-error*`

## Rapport JUnit (GitLab)
Facultatif, en plus de la sortie console : si `AUTOLISP_TEST_JUNIT` (ou `*t:junit-file*`) nomme un fichier, chaque `run-suite` y (ré)écrit un rapport JUnit XML de toutes les suites exécutées. Avec `make`, passer `JUNIT_DIR=<répertoire>` (cf. `makefiles/common.mk`). Détails dans `autolisp-test--manual.org`.

## Intégration avec le wrapper `autolisp`
Quand les tests sont lancés via `outils/autolisp-script/autolisp`, la sortie peut être redirigée avec :
- `OUTFILE` / `*AUTOLISP_OUTFILE*`
- `ERRFILE` / `*AUTOLISP_ERRFILE*`

Cette intégration est déjà utilisée dans `schms/test-unitaire.lsp`.

## Harnais de projet : `test-runner.lsp`
`test-runner.lsp` fait tourner les tests d'une application sous clautolisp,
BricsCAD et AutoCAD, directement ou via alfe. Il charge `test-framework.lsp`
et `vlisp-project.lsp`, puis apporte :
- le chargement tolérant des sources et des suites (un échec de chargement
  est compté comme une erreur, sans interrompre les autres chargements) ;
- la sélection des fichiers par motif (`tu:load-all`) ou par projet Visual
  LISP (`tu:load-project`) ;
- des échecs d'assertion distincts des erreurs sur toutes les CAO, un
  compteur `ABORT` et la capture de `(vl-bt)` dans `errors.log` ;
- les commandes `C:MAIN`, `C:RUN-NAMED` et `C:WRITE-SUMMARY`, et l'écriture
  du statut.

Il n'est pas listé dans `autolisp-test.alpm`, car il redéfinit `C:MAIN` et une
partie du runner de `test-framework.lsp`.

### Mise en place
Le fichier de configuration d'un projet (par exemple
`tests/test-runner-commun.lsp`) positionne les variables, puis charge le
harnais par un `load` **de premier niveau**. alfe ne normalise que les
fichiers chargés ainsi, et sous AutoCAD un `(princ)` sans argument échoue
sinon.
```lisp
(setq *tu:repo-dir* "C:/depots/mon-projet")          ; obligatoire
(setq *outils-autolisp-root* "C:/depots/outils-autolisp") ; obligatoire
(setq *tu:project-name* "MON-PROJET")                 ; libellé du bilan
(load (strcat *outils-autolisp-root* "/autolisp-test/test-runner.lsp"))
```
Variables facultatives : `*tu:statusfile*` (fichier de statut, prioritaire
sur la variable d'environnement `STATUSFILE` d'alfe), ainsi que
`*AUTOLISP_OUTFILE*`, `*AUTOLISP_ERRFILE*`, `*AUTOLISP_STATUSFILE*` et
`*AUTOLISP_WORKDIR*`, qui servent de replis aux variables d'environnement
correspondantes.

Le point d'entrée d'un groupe de tests charge ensuite ses sources et ses
suites, puis on lance `(C:MAIN)`.

### Chargement
Les chemins relatifs partent de `*tu:repo-dir*`.
- `(tu:load chemin)` charge une source. Sous alfe, c'est son lecteur qui
  normalise les formes.
- `(tu:load-test chemin)` charge un fichier de suites. Ses assertions à
  message facultatif sont normalisées : `(is x)` devient `(tu:is x nil)`.
- `(tu:load-all motif options)` charge, en ordre lexicographique, les
  fichiers désignés par `motif`.
- `(tu:load-project fichier.prj options)` charge les sources de `:OWN-LIST`
  dans l'ordre du projet. Chaque élément est relatif au répertoire du `.prj`,
  et reçoit l'extension `.lsp` s'il n'en a pas.
- `(tu:load-introspection)` charge `autolisp-introspection` et
  `test-entites.lsp`, pour les tests CAD.
- `(tu:path chemin)` renvoie le chemin absolu d'un fichier du projet.

Syntaxe des motifs :
- ce sont des chemins relatifs dont chaque composant peut contenir des
  jokers : `*` (une suite de caractères), `?` (un caractère), `[...]` (un
  caractère de l'ensemble) et `[!...]` (un caractère hors de l'ensemble) ;
- un joker ne franchit pas un `/` ;
- tous les autres caractères sont littéraux ;
- la casse est ignorée.

`options` est une liste plate de 2n éléments `(clé valeur ...)` :
- `exclude "motif"` écarte les fichiers qui correspondent au motif. Cette
  clé est répétable, et le motif porte sur le chemin relatif à
  `*tu:repo-dir*` ;
- `loader fonction` désigne la fonction à un argument qui charge chaque
  fichier : `tu:load` par défaut, `tu:load-test` pour des suites.

Les erreurs suivantes sont comptées comme des échecs de chargement, donc
comme des erreurs dans le bilan : un motif qui ne désigne aucun fichier, un
`.prj` illisible et des options invalides (clé inconnue, valeur manquante,
`loader` qui ne désigne pas une fonction).
```lisp
(tu:load-all "tests/test-unitaire-*.lsp"
             '(exclude "tests/test-unitaire-foo*.lsp"
               exclude "tests/test-unitaire-broken.lsp"
               loader  tu:load-test))
(tu:load-project "src/mon-projet.prj"
                 '(exclude "src/demarrage.lsp"))
```

### Bilan et statut
`C:MAIN` exécute toutes les suites. Le résultat de chaque test s'affiche
sous la forme `OK`, `FAIL`, `ERROR` ou `ABORT`. Le bilan de chaque suite
suit :
- `Total: N  OK: N  FAIL: N  ERROR: N  ABORT: N`

Le bilan global vient ensuite, précédé de `==== <projet> ==== ` si
`*tu:project-name*` est défini. Les échecs de chargement y figurent comme
erreurs `[(chargement)]`.

Le statut vaut 0 si tout est passé, et 1 sinon. Il est écrit dans
`*tu:statusfile*` (ou `STATUSFILE`), puis transmis par
`autolisp-set-status` quand alfe ou clautolisp le fournit.

`(C:RUN-NAMED "suite" "test")` exécute un seul test. Le backtrace est alors
intact, puisque le test ne passe pas par `vl-catch-all-apply`.
`(C:WRITE-SUMMARY)` écrit ensuite le bilan et le statut.

## Projets Visual LISP : `vlisp-project.lsp`
`read-vlisp-project-file` lit un fichier `.prj` en ignorant ses
commentaires. Il renvoie une alist `(clé . valeur)`, ou `nil` si le fichier
est illisible ou invalide.

Les accesseurs sont :
- `vlisp-project-name` ;
- `vlisp-project-own-list` ;
- `vlisp-project-fas-directory` ;
- `vlisp-project-tmp-directory` ;
- `vlisp-project-keys` ;
- `vlisp-project-context-id`.

`(vlisp-project-sources alist répertoire)` renvoie les chemins des sources.
L'API est compatible avec `dev/lisp/make-loader.lsp` de SCHMS+.
