# Prompt pour Codex — implanter `autolisp-introspection` + DSL de test

Tu travailles dans le dépôt `outils-autolisp`
(`src/outils-autolisp`), un ensemble de sous-projets AutoLISP / Visual
LISP indépendants partageant un même dépôt Git. Lis et respecte
`CLAUDE.md` et `AGENTS.md` à la racine du sous-projet.

## Mission

Implanter, **strictement d'après la spécification**, deux livrables :

1. la **bibliothèque d'introspection** `autolisp-introspection`, qui
   prend une « photo » des entités d'un dessin
   AutoCAD/BricsCAD avant et après l'appel d'une fonction, puis calcule
   les différences (entités créées / supprimées / modifiées ; pour les
   modifiées : attributs DXF changés et xdata ajoutées / supprimées /
   modifiées, avec valeurs avant/après) ;
2. l'**extension `attendu-…` du framework `autolisp-test`**, un DSL
   d'assertions qui exprime de façon concise les changements attendus et
   s'intègre au runner existant.

Périmètre : **uniquement des mutateurs de l'état des entités** du
dessin. **Aucune I/O utilisateur** (pas de `command`, `getpoint`,
DCL, etc.).

## Documents de référence (à lire en premier, ce sont la source de vérité)

- `autolisp-introspection/docs/autolisp-introspection--specifications.org`
  — API exacte, modèle de données, sémantique, exemple complet.
- `autolisp-introspection/docs/plan.org` — découpage en lots et
  définition de « terminé ».

En cas de doute, la spécification prime sur ce prompt. Si la
spécification est ambiguë ou contradictoire, **ne devine pas** : signale
le point et propose une résolution dans un fichier
`issues/open/introspection-<slug>.issue`.

## Conventions impératives (résumé — voir AGENTS.md/CLAUDE.md)

- Encodage **UTF-8** ; fins de ligne **CRLF** pour `*.lsp` et `*.org`,
  **LF** pour `Makefile`. Le `.gitattributes` du dépôt applique déjà ces
  règles : ne les contredis pas.
- Commentaires et textes français **accentués** ; identificateurs sans
  accent.
- AutoLISP n'a pas de packages : préfixe **tous** les symboles publics
  de la bibliothèque par `ei-`, les internes par `ei--`, les variables
  dynamiques par `ei-*…*`. Le DSL d'assertions suit le style **sans
  préfixe** du framework (`is`, `is-equal`, `deftest`) ; ses helpers
  internes sont préfixés `t:`.
- **Aucun pathname absolu** dans un fichier versionné ; chemins relatifs
  uniquement.
- Modèle de chaque source : voir `autolisp-hash-table/src/autolisp-hash-table.lsp`
  (en-tête « Public API », style `xx-` / `xx--`, `(vl-load-com)` en tête).

## Arborescence à produire

```
autolisp-introspection/
  Makefile                      # calqué sur autolisp-hash-table/Makefile
  src/autolisp-introspection.lsp
  docs/Makefile                 # export PDF org (identique aux autres modules)
  docs/autolisp-introspection--specifications.org   # déjà présent
  docs/plan.org                                      # déjà présent
  tests/introspection-tests.lsp
  tests/run-tests.lsp           # C:MAIN, calqué sur autolisp-hash-table
autolisp-test/
  test-entites.lsp              # DSL attendu-…
  docs/autolisp-test--entites.org
```

## Points techniques à ne pas rater

- **Identité = handle** (DXF 5), jamais l'ename (DXF -1, volatil).
- **Capture xdata** : `entget` **doit** être appelé avec le filtre
  `'("*")`, sinon les xdata sont absentes.
- **Codes DXF multi-valués** (ex. plusieurs `10` sur une LWPOLYLINE) :
  comparer la **liste ordonnée** des valeurs par code ; ne pas réduire
  par `assoc` (perte des doublons).
- **Groupes exclus** de la comparaison d'attributs : -1, -2, 5.
- **Normalisation** : réels et points avec tolérance `ei-*fuzz*` ;
  enames en valeur (ex. groupe 330) normalisés en handle avant
  comparaison.
- Une candidate « modifiée » ne l'est que si DXF **ou** xdata diffèrent
  réellement après normalisation.
- Objets `snapshot` / `diff` / `entity-diff` **opaques** : accès
  uniquement via les accesseurs `ei-…` spécifiés ; les tests ne doivent
  jamais dépendre de la représentation interne.

## Méthode de travail

Procède **lot par lot** comme dans `plan.org` (squelette → photo → diff
→ attributs → xdata → DSL → intégration). À la fin de chaque lot,
exécute les tests du lot et n'avance que s'ils passent.

Exécute les tests via le wrapper existant, comme les autres modules :

```
make -C autolisp-introspection test-bricscad        # Linux / défaut
make -C autolisp-introspection test-ci
```

Sur macOS, les cibles `test-bricscad-macos-batch` et
`test-bricscad-macos-osascript-attach` existent (cf.
`autolisp-hash-table/Makefile`). Les tests de la bibliothèque tournent
contre **un vrai BricsCAD** (sémantique fidèle de `entmake`/`entget`/
xdata). N'ajoute un smoke test `fake CAD` que si ce backend supporte
`entmakex` + `entget '("*")` + xdata ; sinon ne l'ajoute pas et
mentionne-le.

## Critères d'acceptation

- Le `deftest` complet figurant dans la spécification (test de
  `schms-affecte-pk`) s'exécute et **passe** (fournis une définition
  factice de `schms-affecte-pk` dans les tests pour le démontrer).
- Tous les cas de test listés au §« Tests de la bibliothèque elle-même »
  de la spec sont couverts et verts.
- `make test-ci` à la racine inclut le nouveau module ; `loader.lsp` et
  `README.md` sont mis à jour ; `make -C autolisp-introspection docs-pdf`
  fonctionne.
- Encodage / fins de ligne conformes ; aucun pathname absolu.

## Livrable final

Un résumé : fichiers créés/modifiés, commandes de test exécutées et leur
résultat, points laissés ouverts (issues créées). Ne déclare « terminé »
que ce qui a réellement été exécuté et vérifié.
