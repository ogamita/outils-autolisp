# autolisp-formatter

Formateur / pretty-printer AutoLISP, **écrit en AutoLISP**.

Il relit un source AutoLISP, en reconstruit la structure syntaxique, puis le
réémet de façon déterministe et idempotente : indentation, placement des
parenthèses fermantes, casse des symboles et présentation des commentaires
sont recalculés, le reste est préservé.

Principe directeur : **le formateur ne reflue pas le code.** Les coupures de
ligne voulues par l'auteur sont conservées. Une forme écrite sur une ligne y
reste, une forme éclatée reste éclatée aux mêmes endroits. C'est ce qui rend
la sortie idempotente sans avoir à choisir une largeur de ligne.

## Utilisation en ligne de commande

```
scripts/autolisp-format [OPTIONS] FICHIER...
```

| Option | Effet |
| --- | --- |
| `--style cl\|nail\|stacked-nail` | style de parenthèses (défaut `cl`) |
| `--symbol-case preserve\|downcase\|upcase` | casse des symboles (défaut `preserve`) |
| `--comment-style preserve\|cl` | préfixes de commentaires |
| `--block-comments preserve\|to-semicolons` | traitement des `;\| ... \|;` |
| `--contextual-comments yes\|no` | `;;;;` / `;;;` / `;;` / `;` selon l'emplacement |
| `--inline-comment-column N` | alignement des commentaires de fin de ligne |
| `--case-exceptions FICHIER` | fichier d'exceptions de capitalisation |
| `--check-case-exceptions` | signale les exceptions jamais rencontrées |
| `--report-stacked` | signale les lignes en fermetures empilées |
| `--config FICHIER` | fichier de configuration |
| `--in-place` | remplace le fichier source |
| `--check` | n'écrit rien ; statut 1 si le fichier n'est pas conforme |
| `--output FICHIER` | écrit vers un autre fichier |

Codes de retour : `0` succès, `1` au moins un fichier non conforme
(`--check`), `2` erreur.

```bash
scripts/autolisp-format --style nail --symbol-case downcase --in-place src/*.lsp
```

## Styles de parenthèses

```lisp
;; --style cl
(defun foo (x)
  (if (> x 0)
      (progn
        (bar x)
        (baz x))))

;; --style nail
(defun foo (x)
  (if (> x 0)
    (progn
      (bar x)
      (baz x)
    )
  )
)
```

Le troisième style, `stacked-nail` — *nail-clipping à fermetures empilées*,
où plusieurs fermantes s'alignent sur une même ligne (`) ) )`) — n'est émis
que s'il est demandé explicitement. En entrée il est toujours accepté et
normalisé vers le style cible ; `--report-stacked` en signale les
occurrences.

## Utilisation depuis AutoLISP

```lisp
(load "autolisp-formatter/loader.lsp")

(fmt-format "(setq  a  1)\n" '("--style" "nail"))     ; -> texte formaté
(fmt-format-string texte options)                      ; options normalisées
(fmt-format-file "entree.lsp" "sortie.lsp" options)
(fmt-check-file "entree.lsp" options)                  ; T si déjà conforme
(fmt-main '("--check" "entree.lsp"))                   ; -> code de retour
```

`options` est la structure produite par `fmt-build-options` ; les mêmes
listes d'options sont acceptées par la ligne de commande, l'API et le
fichier de configuration.

## Fichier de configuration

Les deux formes prévues par les spécifications sont acceptées — une
s-expression englobante, ou une suite d'items :

```lisp
(:style-parentheses :cl
 :casse-symboles :minuscules
 :fichier-exceptions-casse "capitalisation.txt"
 :colonne-commentaires-en-ligne 40
 "entree.lsp")
```

Priorité : options de l'appel courant, puis fichier de configuration, puis
valeurs par défaut. Les noms d'options existent en anglais (`--style`) et en
français (`:style-parentheses`) ; ils désignent les mêmes clés internes.

## Exceptions de capitalisation

Un symbole par ligne, écrit exactement comme il doit être réémis :

```
PATH
CreateFileW
```

Toute occurrence de ces symboles, quelle que soit sa casse dans le source,
est réécrite ainsi — priorité sur la politique générale de casse.

## Modules

| Fichier | Rôle |
| --- | --- |
| `src/fmt-util.lsp` | chaînes, caractères, alists, erreurs |
| `src/fmt-scanner.lsp` | analyse lexicale (tokens + positions source) |
| `src/fmt-parser.lsp` | CST, détection des fermetures empilées |
| `src/fmt-options.lsp` | options : ligne de commande, config, API |
| `src/fmt-io.lsp` | lecture / écriture de fichiers |
| `src/fmt-case.lsp` | politique de casse et exceptions |
| `src/fmt-rules.lsp` | règles d'indentation par tête de forme |
| `src/fmt-printer.lsp` | réémission textuelle |
| `src/fmt-main.lsp` | API publique et pilote |

## Tests

```bash
make test-clautolisp
```

La suite couvre le scanner, le parseur, les golden tests de l'imprimeur, les
options, l'idempotence, et une non-régression sur corpus réel qui vérifie
que la suite des tokens de code est identique avant et après formatage.

## Limites connues (v1)

- L'alignement intra-ligne (plusieurs espaces pour aligner des colonnes) est
  normalisé à un espace : le formateur ne préserve pas les tableaux alignés
  à la main.
- Le mode `--comment-style cl` applique une heuristique de contexte ; la
  perfection éditoriale n'est pas visée, conformément aux spécifications.
- Pas de reflux du texte en prose dans les commentaires.

Spécifications : [docs/autolisp-formatter--specifications.org](docs/autolisp-formatter--specifications.org) —
manuel : [docs/autolisp-formatter--manual.org](docs/autolisp-formatter--manual.org) —
plan : [docs/plan.org](docs/plan.org)
