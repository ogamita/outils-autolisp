# autolisp-test

## Objectif
`autolisp-test` fournit un framework de tests AutoLISP léger :
- gestion de suites
- enregistrement de tests
- assertions
- exécution agrégée (`run-suite`, `run-all`)

## Emplacement
- Framework : `outils/autolisp-test/test-framework.lsp`
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

## Intégration avec le wrapper `autolisp`
Quand les tests sont lancés via `outils/autolisp-script/autolisp`, la sortie peut être redirigée avec :
- `OUTFILE` / `*AUTOLISP_OUTFILE*`
- `ERRFILE` / `*AUTOLISP_ERRFILE*`

Cette intégration est déjà utilisée dans `schms/test-unitaire.lsp`.
