# Prompt — Cabler proprement `--autocad` + COM `AutoCAD.Application` sur MS-Windows

## Pour qui ce prompt

Un agent (Claude Code ou equivalent) qui va modifier le script
`outils-autolisp/autolisp-script/autolisp` (bash, ~3920 lignes) pour
finaliser le support `--autocad` sur MS-Windows, en passant par le pont
COM `AutoCAD.Application`. Le travail est mecanique : l'infrastructure
existe deja, il faut la rendre selectionnable proprement par CLI,
documentee, robuste et testee.

L'agent est suppose ne connaitre ni le repo, ni le contexte. Tout ce
qui suit doit etre suffisant pour qu'il execute la tache sans poser
de question.

## Localisation du code

Le repo `outils-autolisp` est un clone independant, sibling du repo
`schms`. Depuis le poste de travail principal, on a typiquement :

```
<works>/sncf-reseau/src/
    schms/                      # consommateur (dev/makefiles/deploy.mk)
    outils-autolisp/
        autolisp-script/
            autolisp            # LE script bash a modifier
            VERSION.TXT
            lib/autolisp-remote-io.sh
            runtime/autolisp-remote-io.lsp
            docs/autolisp-script--specifications.org
            tests/
    outils-autocad/
        autocad-script/
            PROMPT-autocad-com-mode.md   # CE prompt
```

Le binaire `autolisp` est utilise par `schms/dev/makefiles/deploy.mk`
via la variable `AUTOLISP_BIN` (voir `BUILD_LOADER_RECIPE`,
`BUILD_VLX_RECIPE`).

## Contexte / motivation

`schms/dev/makefiles/deploy.mk` contient `BUILD_VLX_RECIPE` : la
generation des `.vlx` (SCHMSPLUS.vlx, export.VLX) ne peut se faire
qu'avec AutoCAD VLIDE car DESCoder n'existe que pour BricsCAD. Pour le
moment, la recette est entierement manuelle (prompt `read` qui demande
a l'utilisateur d'ouvrir AutoCAD, lancer `_VLIDE`, naviguer dans le
menu, selectionner le `.prj`, etc.).

On veut pouvoir automatiser cela via :

```
autolisp --autocad --mode automation \
    -x '(vlisp-compile (quote lsa) "src-vlx/schmsplus.prj")' \
    --quit
```

`vlisp-compile` est la fonction AutoLISP officielle qui fait exactement
ce que le menu VLIDE > "Creer une application" fait sous le capot.

### Pourquoi pas un VLIDE standalone ?

**Important pour comprendre la contrainte** : la fenetre VLIDE *parait*
etre une appli separee mais ce n'est PAS un executable autonome. Sur une
install AutoCAD 2022 typique (`C:\Program Files\Autodesk\AutoCAD 2022\`)
on ne trouve QUE :

- `vlide.dll`, `vlide_u.dll` (DLL, pas d'EXE)
- `vl.arx`, `vl_u.arx` (modules ARX charges DANS acad.exe)

Aucun `vlide.exe` n'existe — l'IDE est une fenetre top-level MFC
heberge dans le processus `acad.exe`. Le runtime AutoLISP et
`vlisp-compile` lui-meme vivent dans `acad.exe`. Aucune echappatoire :
pour produire un `.vlx`, il faut une instance `acad.exe` qui tourne.

C'est pour cela que la voie COM `AutoCAD.Application` (ou `acad.exe /b`)
est incontournable. Contraste avec BricsCAD, qui livre `DESCoder.exe`
comme outil reellement standalone (voir `compile-prv` dans
`schms/dev/makefiles/deploy.mk:368-374`).

**Important** : `vlisp-compile` n'existe PAS non plus dans
`accoreconsole.exe` (Core Console headless, qui n'embarque pas VLIDE).
Il faut donc absolument piloter un `acad.exe` complet via COM, pas le
Core Console. C'est pour cela que `--mode automation` (et non `--mode
batch`, qui mappe sur accoreconsole / `acad.exe /b`) est requis.

## Etat existant — lire d'abord

L'infrastructure est *deja largement en place*. Avant toute modification,
**lire integralement** les sections suivantes du script :

- `outils-autolisp/autolisp-script/autolisp` lignes ~50-102 (usage),
  ~105-260 (parsing CLI : `--autocad`, `--mode`, `--backend`,
  `--epure`, etc.),
- lignes ~1230-1290 (auto-detection moteur, mapping `--mode` ->
  `AUTOCAD_COM_MODE` / `BRICSCAD_COM_MODE`),
- lignes ~3140-3320 (`write_windows_autocad_vbs`,
  `run_windows_autocad` : le pont COM VBScript pour
  `AutoCAD.Application` existe deja).

Resume des constats :

1. `--autocad` existe deja (selection du moteur).
2. `--mode` existe deja mais est documente "BricsCAD macOS" seulement.
   Les valeurs sont `automation | batch` (et `auto` accepte par
   defaut).
3. La logique de mapping (~ligne 1268) fait :
   - `--mode automation` => `AUTOCAD_COM_MODE = $CAD_BACKEND`
     (`attach` ou `launch`, defaut `launch`)
   - `--mode batch` => `AUTOCAD_COM_MODE = off`
   - cas par defaut (`auto`) : laisse `AUTOCAD_COM_MODE` a sa valeur
     d'env (`auto` => attache si possible, sinon lance).
4. `run_windows_autocad` : si `AUTOCAD_COM_MODE != off` et que
   `cscript.exe` est present, genere et execute un VBScript qui
   `CreateObject("AutoCAD.Application")` (ou `GetObject` selon mode),
   force `Visible = True`, ouvre/cree un document, et envoie
   `(load "...")` via `Document.SendCommand`.
5. Le pont est branche : sous Windows + ENGINE=autocad, l'execution
   passe deja par ce code path quand l'utilisateur le demande.

**Donc on est tres proches** — il manque essentiellement de la
finition, de la documentation et un test.

## Travail demande

### 1. Documenter explicitement `--mode automation` pour AutoCAD/Windows

Dans le bloc d'usage (`usage() { cat <<'EOU'... }`, ~lignes 18-102) :

- Remplacer la ligne actuelle
  `--mode MODE             automation | batch (BricsCAD macOS)`
  par une description qui couvre les 3 cas :

  ```
  --mode MODE             automation | batch
                          Sur Windows + AutoCAD : automation active le
                            pont COM AutoCAD.Application (acad.exe
                            visible) ; batch lance acad.exe /b sans
                            COM, ou accoreconsole.exe en fallback.
                          Sur Windows + BricsCAD : automation active le
                            pont COM BricsCAD.Application ; batch lance
                            bricscad.exe /b sans COM.
                          Sur macOS + BricsCAD : automation = AppleScript
                            UI-bridge ; batch = bricscad headless.
  ```

- Ajouter un exemple d'invocation AutoCAD :

  ```
  autolisp --autocad --mode automation \
           -x '(vlisp-compile (quote lsa) "src-vlx/schmsplus.prj")' \
           --quit
  ```

### 2. Choisir le defaut `--mode` correct sur Windows + AutoCAD

Aujourd'hui, sans `--mode`, `CAD_MODE` vaut `auto` (ou la valeur de
`AUTOLISP_MODE`). Verifier au travers du switch lignes ~1268-1290 que
le defaut `auto` sur Windows + AutoCAD fait bien :
- `AUTOCAD_COM_MODE = auto` (=> attache si une instance AutoCAD tourne,
  sinon lance une nouvelle via COM).

Si ce n'est pas deja le cas, l'ajuster. Ne pas modifier le comportement
existant pour BricsCAD ou pour macOS.

### 3. Verifier la robustesse du pont COM (VBScript ligne ~3151-3258)

Cas a couvrir / verifier (et corriger si necessaire) :

- **Verrouillage par dialog modal au demarrage** (activation, profil,
  splash) : le `CreateObject` peut reussir mais `SendCommand` echoue
  silencieusement. Ajouter (cote VBScript) un petit `WScript.Sleep`
  initial + une boucle de retry sur `app.GetAcadState.IsQuiescent`
  avant le premier `SendCommand`. Timeout = `AUTOLISP_WAIT_SECS`
  (variable bash exportee dans l'env du `cscript`).

- **Profil EPURE** : si `--epure` est passe, il faut que l'instance
  COM utilise le profil EPURE. Actuellement le code `--epure` n'est
  cable que pour le mode `acad.exe /b`. Pour le mode COM, deux
  options :
  1. (recommande) avant `CreateObject`, lancer
     `acad.exe /p Epure /nologo` en background et attendre puis
     `GetObject(, "AutoCAD.Application")` pour s'attacher. Eviter
     `CreateObject` qui ne permet pas de passer `/p`.
  2. via COM : `app.Preferences.Profiles.ActiveProfile = "Epure"`
     si le profil existe deja.

  Choisir l'option 2 (plus simple). Si elle echoue (profil inexistant),
  emettre un warning sur `stderr` et continuer avec le profil par
  defaut.

- **Pas de document ouvert** : code existant fait
  `Documents.Add` si pas d'ActiveDocument. Verifier que ca marche
  bien quand AutoCAD demarre sur l'ecran d'accueil sans drawing
  initial. `vlisp-compile` exige un document ouvert.

- **Lecture du status / stdout / stderr** : le runtime AutoLISP cote
  CAD ecrit dans `STATUSFILE`, `OUTFILE`, `ERRFILE` (voir
  `runtime/autolisp-remote-io.lsp`). Le pont actuel envoie un seul
  `(load "RUNLSPFILE")` et exit. Verifier que la sequence
  `wait_for_status` (ligne ~3276) attend bien la fin reelle de
  l'evaluation, et pas seulement la fin du `SendCommand` (qui rend la
  main immediatement, `SendCommand` etant asynchrone cote AutoCAD).

- **Pas de garbage de l'instance** : en mode `launch`, l'instance
  lancee doit-elle etre fermee a la fin ? Aujourd'hui le VBScript
  fait `WScript.Quit rc` sans faire `app.Quit`. Comportement attendu :
  - mode `launch` => `app.Quit` a la fin (sauf si `--keep-cad`,
    optionnel a ajouter).
  - mode `attach` => ne pas tuer l'instance attachee.

  Implementer `app.Quit` conditionnel a `created = True`.

### 4. Detection automatique de `AUTOCAD_EXE`

Aujourd'hui le defaut de `AUTOCAD_EXE` est vide (ligne 111). Ajouter
une auto-detection apres le parsing CLI, du meme genre que pour
`BRICSCAD_EXE`, en cherchant dans :

```
/c/Program Files/Autodesk/AutoCAD */acad.exe
/c/Program Files/Autodesk/AutoCAD LT */acadlt.exe
```

Prendre le plus recent (lexicographique decroissant). Ne rien changer
si `AUTOCAD_EXE` est deja defini.

### 5. Bump version

Conformement a `sncf-reseau/CLAUDE.md` ("Versioning autolisp") : toute
modification du script ou de ses dependances runtime *doit* incrementer
`VERSION_PATCH` dans `outils-autolisp/autolisp-script/VERSION.TXT`.
Faire le bump dans le meme commit.

### 6. Test de fumee

Ajouter, sous `outils-autolisp/autolisp-script/tests/`, un test
manuel documente (script bash) qui :

1. Verifie que `cscript.exe` et `AUTOCAD_EXE` (ou registre COM
   `HKCR\AutoCAD.Application\CurVer`) sont presents ; sinon, `skip`.
2. Lance :
   ```
   autolisp --autocad --mode automation \
       -x '(princ "hello-from-autocad-com")' \
       --quit
   ```
3. Verifie que le code de sortie est 0 et que `stdout` contient la
   chaine attendue (via le mecanisme OUTFILE).
4. (Optionnel) lance une deuxieme fois avec `--mode automation
   --backend attach` pour valider la branche d'attache.

Le test doit etre marque clairement comme "Windows-only, AutoCAD
installe, execution manuelle" — *ne pas* le brancher dans la cible
CI par defaut.

### 7. Documenter cote `docs/`

Dans `outils-autolisp/autolisp-script/docs/autolisp-script--specifications.org`,
ajouter une section "AutoCAD COM bridge (Windows)" qui :

- liste les variables d'env pertinentes (`AUTOCAD_EXE`,
  `AUTOCAD_COM_MODE`, `AUTOCAD_ACCORECONSOLE`),
- decrit le mapping `--mode` => `AUTOCAD_COM_MODE`,
- documente que `--mode automation` est requis pour `vlisp-compile`
  (use-case SCHMS+ `BUILD_VLX_RECIPE`),
- explique brievement pourquoi : pas de `vlide.exe` standalone, pas de
  `vlisp-compile` dans `accoreconsole.exe`.

Regenerer le PDF si le `Makefile` du repertoire `docs/` le fait
automatiquement (sinon, ne pas s'en soucier).

## Branchement cote consommateur (schms)

Une fois ces modifications faites cote `outils-autolisp`, le consommateur
(`schms/dev/makefiles/deploy.mk`) sera mis a jour separement (hors du
scope de ce prompt). Pour reference, le branchement cible ressemblera a :

```makefile
define BUILD_VLX_RECIPE
    @if [ -n "$(AUTOLISP_BIN)" ] && [ -x "$(AUTOLISP_BIN)" ] && [ "$(PLATFORM)" = "windows" ]; then \
        echo "[autolisp --autocad] -> $(2)" ; \
        "$(AUTOLISP_BIN)" --autocad --mode automation \
            -x '(vlisp-compile (quote lsa) "$(1)")' \
            --quit ; \
    else \
        # ... ancien prompt manuel ...
    fi
    # ... verifications de presence et timestamp inchangees ...
endef
```

Ne pas faire cette modification dans le cadre du present prompt. La
mentionner seulement comme cible pour valider la coherence des choix
d'API CLI.

## Contraintes generales (issues de CLAUDE.md)

- Pas de chemin absolu code en dur dans les fichiers commitees — utiliser
  les variables d'env / auto-detection.
- Pas de lecture de fichiers `*~` ou `.~N~` (backups).
- Le shell cible est `bash` (MSYS2 / Git Bash) sous Windows. `cscript.exe`
  est invoque via son chemin Windows. Penser `MSYS_NO_PATHCONV=1` si
  necessaire pour passer des chemins sans traduction.
- Le script doit continuer a marcher sur macOS et Linux sans regression :
  les chemins de code `--autocad` Windows sont gardes derriere des tests
  `PLATFORM=windows` ou equivalents.

## Criteres d'acceptation

1. `autolisp --help` mentionne `--mode automation` pour AutoCAD/Windows.
2. `autolisp --autocad --mode automation -x '(princ "ok")' --quit`
   sous Windows + AutoCAD installe :
   - lance ou attache une instance AutoCAD.Application via COM,
   - charge le runtime,
   - evalue l'expression,
   - rend `stdout` contenant `ok` et code de sortie 0.
3. `AUTOCAD_EXE` est auto-detecte si non defini.
4. `VERSION.TXT` a un `VERSION_PATCH` incremente.
5. Aucune regression sur les chemins `--bricscad` (Windows ou macOS) ni
   sur le fallback `accoreconsole.exe`.
6. Le code passe `shellcheck` (au moins sans nouvelles warnings).

## Hors scope (ne pas faire)

- Modifier `schms/dev/makefiles/deploy.mk` (sera fait separement).
- Ajouter un mode "UI scripting" (UIA, AutoIt) — on reste sur COM pur.
- Modifier le pont BricsCAD COM ou la branche macOS.
- Supprimer le fallback `accoreconsole.exe` (il reste utile pour les
  scripts qui n'ont pas besoin de `vlisp-compile` ni du GUI).

## Pour aller plus loin (notes, pas de l'implementation)

- `vlisp-compile` est documente cote AutoLISP officiel :
  https://help.autodesk.com (chercher "vlisp-compile").
- Mode du second argument :
  - `'st` => `.fas` non compresse (single project file)
  - `'lsa` => `.vlx` application compressee (notre cas SCHMS+)
- Pour BricsCAD, l'equivalent est `vle-vlx` / DESCoder ; on n'y touche
  pas ici.
- Le ProgID `AutoCAD.Application` est version-independant (point a la
  derniere version installee via `HKCR\AutoCAD.Application\CurVer`).
  Pour cibler une version precise, utiliser `AutoCAD.Application.24`
  (R2021), `.25` (R2024), etc. — pas requis ici.
- Alternative plus legere a COM : `acad.exe /b script.scr` ou `acad.exe
  /b file.lsp`. Lance acad.exe, execute, quitte. Pas de gestion
  d'erreurs COM mais suffit pour la majorite des cas si on se contente
  de verifier le `.vlx` produit a posteriori (timestamp). A garder en
  fallback si le pont COM echoue.
- L'EXE `AutoLispDebugAdapter.exe` present dans l'install AutoCAD est
  un Debug Adapter Protocol pour l'extension VS Code AutoCAD AutoLISP
  — NE PRODUIT PAS de `.vlx`, ne pas le confondre avec un compilateur.
