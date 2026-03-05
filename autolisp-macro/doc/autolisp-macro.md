# autolisp-macro

## Objectif
`autolisp-macro` apporte des capacités de macros à AutoLISP :
- support de `defmacro`
- expansion de macros (`m:macroexpand`, `m:macroexpand-all`)
- évaluation/chargement compatibles macros (`m:meval`, `mload`)
- helpers de quasiquote (`quasiquote`, `unquote`, `splice`)

## Emplacement
- Runtime et loader : `outils/autolisp-macro/mruntime.lsp`
- Variante minimale : `outils/autolisp-macro/macro.lsp`
- Implémentations quasiquote :
  - `outils/autolisp-macro/quasiquote.lsp` (listes propres)
  - `outils/autolisp-macro/quasiquote-dotted.lsp` (support des listes pointées)
- Démonstrations :
  - `outils/autolisp-macro/macro-demo.lsp`
  - `outils/autolisp-macro/quasiquote-demo.lsp`
  - `outils/autolisp-macro/draw-grid.lsp`

## Démarrage rapide
```lisp
(load "outils/autolisp-macro/mruntime.lsp")
(mload "outils/autolisp-macro/quasiquote-dotted.lsp")
(mload "outils/autolisp-macro/macro-demo.lsp")

(c:macro-demo)
```

## Workflow recommandé
1. Charger le runtime (`mruntime.lsp`).
2. Charger les fichiers macro avec `mload` (et pas `load`) pour enregistrer les `defmacro`.
3. Évaluer des formulaires via `m:meval` ou appeler les commandes/fonctions chargées.

## API principale
- Registre :
  - `m:macro-expander`
  - `m:set-macro-expander`
  - `m:macro-p`
- Expansion :
  - `m:macroexpand-1`
  - `m:macroexpand`
  - `m:macroexpand-all`
- Évaluation :
  - `m:meval`
  - `mload`

## Exemple
Depuis `macro-demo.lsp` :
```lisp
(defmacro when (test &rest body)
  (list 'if test (cons 'progn body)))
```

Puis :
```lisp
(when (< x 3)
  (print "ok"))
```

sera développé en formulaire `if` + `progn` avant évaluation.

## Notes sur quasiquote
- Exemple d’usage :
  - `(quasiquote (a (unquote x) (splice xs) b))`
- Préférer `quasiquote-dotted.lsp` si vous avez besoin des listes pointées.
- `unquote` et `splice` sont des marqueurs, pas des fonctions d’usage runtime direct.

## Comportement de `loader.lsp`
`loader.lsp` résout son propre chemin via `findfile`, calcule `../autolisp-test/`, puis charge les dépendances.

Si `findfile` ne retrouve pas `loader.lsp`, le script échoue immédiatement avec un message explicite vous demandant :
- d’ajouter `outils/autolisp-macro` au `SRCHPATH`, ou
- de charger `loader.lsp` avec un chemin absolu.
