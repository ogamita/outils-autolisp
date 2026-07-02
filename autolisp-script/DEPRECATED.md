# autolisp-script — DÉPRÉCIÉ

Ce sous-projet est **déprécié**. Le wrapper `autolisp` (pilotage
d'AutoCAD/BricsCAD en batch) est remplacé par **`alfe`** (AutoLISP front-end,
projet [clautolisp](https://github.com/ogamita/clautolisp)), et les tests
headless par **`clautolisp`**.

- Le binaire `autolisp` est désormais un simple stub qui renvoie une erreur et
  invite à utiliser `alfe`.
- L'ancien script complet reste disponible sous `autolisp-deprecated` pour un
  besoin ponctuel.
- Les cibles de test (`test-ci`, `test-fakecad`, …) sont inhibées (no-op) et le
  job CI correspondant a été retiré.

Voir `makefiles/common.mk` (à la racine du dépôt) et `.gitlab-ci.yml` pour la
nouvelle chaîne de tests basée sur `clautolisp`/`alfe`.
