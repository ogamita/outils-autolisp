# autolisp-json

Lecture et écriture de **JSON** en AutoLISP : sérialise/désérialise une
expression symbolique (`sexp`) Lisp vers/depuis du texte JSON.

La **version 1** traite le document *en bloc* : un fichier contient un seul
document JSON, une `sexp` représente un seul document. Une version
*incrémentale* (par flux) est prévue — voir
[`issues/open/autolisp-json-incremental.issue`](../issues/open/autolisp-json-incremental.issue).

## Chargement

```lisp
(load "autolisp-json/src/autolisp-json.lsp")   ; la source seule
;; ou
(load "autolisp-json/loader.lsp")              ; résout son chemin tout seul
```

## Représentation (balisée, aller-retour sûr)

| Valeur JSON     | Représentation `sexp`                     |
|-----------------|-------------------------------------------|
| `{ … }`         | `(aj-object ("clé" . valeur) …)`          |
| `[ … ]`         | `(aj-array valeur …)`                     |
| chaîne          | chaîne AutoLISP (`STR`)                   |
| entier / réel   | `INT` / `REAL`                            |
| `true`          | `aj-true`                                 |
| `false`         | `aj-false`                                |
| `null`          | `aj-null`                                 |

Les singletons `aj-true` / `aj-false` / `aj-null` sont liés à eux-mêmes :
ils s'écrivent sans `quote`. Décoder puis réencoder puis redécoder redonne
exactement la même `sexp` (`{}`, `[]`, `false`, `null` restent distincts).

## API

### Décodage / encodage

| Fonction | Rôle |
|----------|------|
| `(aj-decode chaîne)` | chaîne JSON complète → `sexp` (erreur si malformée) |
| `(aj-encode valeur)` | `sexp` → JSON **compact** |
| `(aj-encode-pretty valeur)` | `sexp` → JSON **indenté** |

### Fichiers (en bloc)

| Fonction | Rôle |
|----------|------|
| `(aj-read-file chemin)` | lit tout le fichier et le décode → `sexp` |
| `(aj-write-file chemin valeur)` | encode compact et écrit → `chemin` |
| `(aj-write-file-pretty chemin valeur)` | encode indenté et écrit → `chemin` |

### Constructeurs, prédicats, accesseurs

| Fonction | Rôle |
|----------|------|
| `(aj-make-object alist)` / `(aj-make-array items)` | construire objet / tableau |
| `(aj-object-p v)` / `(aj-array-p v)` | prédicats de type |
| `(aj-null-p v)` / `(aj-true-p v)` / `(aj-false-p v)` | prédicats de singleton |
| `(aj-boolean x)` | `aj-true` si `x` vrai, sinon `aj-false` |
| `(aj-object-get obj clé)` | valeur associée, ou `nil` si absente |
| `(aj-object-has-p obj clé)` | `T` / `nil` |
| `(aj-object-put obj clé valeur)` | **nouvel** objet (non destructif) |
| `(aj-object-keys obj)` | liste des clés, dans l'ordre |
| `(aj-object-alist obj)` / `(aj-array-items arr)` | contenu brut |

### Configuration

| Variable | Défaut | Effet |
|----------|--------|-------|
| `*aj-escape-non-ascii*` | `nil` | `T` → échappe tout code > 126 en `\uXXXX` |
| `*aj-real-precision*` | `12` | décimales conservées pour les `REAL` |
| `*aj-indent*` | `2` | espaces par niveau (mode indenté) |

Par tolérance à l'encodage, `T` donne `true` et `nil` donne `null`.

## Exemples

```lisp
;; Décoder
(aj-decode "{\"a\":1,\"b\":[true,null]}")
;; => (aj-object ("a" . 1) ("b" aj-array aj-true aj-null))

(aj-decode "1.5")   ;; => 1.5
(aj-decode "true")  ;; => aj-true

;; Encoder
(aj-encode '(aj-object ("a" . 1) ("b" . 2)))
;; => "{\"a\":1,\"b\":2}"

(aj-encode-pretty '(aj-array 1 2 3))
;; => "[\n  1,\n  2,\n  3\n]"

;; Construire et lire
(setq doc (aj-make-object (list (cons "nom" "Ligne 42")
                                (cons "voies" 2)
                                (cons "gares" (aj-make-array (list "Nord" "Sud"))))))
(aj-object-get doc "nom")                    ;; => "Ligne 42"
(aj-array-items (aj-object-get doc "gares")) ;; => ("Nord" "Sud")

;; Fichiers
(setq data (aj-read-file "examples/sample.json"))
(aj-write-file-pretty "sortie.json" data)
```

Voir [`examples/demo.lsp`](examples/demo.lsp) et
[`examples/sample.json`](examples/sample.json) pour un exemple complet.

## Tests

```sh
make test          # BricsCAD (macOS) via alfe
```

Ou, en tête à tête et sans CAO, via `clautolisp` :

```sh
clautolisp --dialect bricscad \
  -l ../autolisp-test/test-framework.lsp \
  -l src/autolisp-json.lsp \
  -l tests/json-tests.lsp \
  -x '(run-suite "autolisp-json")'
```

## Documentation

- Manuel : [`docs/autolisp-json--manual.org`](docs/autolisp-json--manual.org)
- Spécifications : [`docs/autolisp-json--specifications.org`](docs/autolisp-json--specifications.org)

Les PDF se régénèrent avec `make docs-pdf` (ils ne sont pas versionnés).
