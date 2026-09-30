;; test-runner.lsp -- Harnais d'exécution des suites autolisp-test d'un projet.
;;
;; Ce fichier complète test-framework.lsp (qu'il charge) avec ce qu'il faut
;; pour faire tourner les tests d'une application sous clautolisp, BricsCAD et
;; AutoCAD, directement ou via alfe :
;;
;;   - chargement tolérant des sources (tu:load), des fichiers de tests
;;     (tu:load-test), d'un ensemble de fichiers désigné par un motif
;;     (tu:load-all) ou des sources d'un projet Visual LISP (tu:load-project) ;
;;   - lecteur de formes tolérant aux commentaires et normalisation des
;;     assertions à message optionnel : (is x) devient (tu:is x nil) ;
;;   - échecs d'assertion par throw/quit : un FAIL reste distinct d'une ERROR
;;     sur toutes les CAO (le t:fail d'origine repose sur ERROR, qui n'est pas
;;     une primitive AutoLISP) ; compteur ABORT ;
;;   - capture de (vl-bt) autour de chaque test, errors.log et marqueurs ;
;;   - points d'entrée C:MAIN (toutes les suites), C:RUN-NAMED (un test par
;;     appel) et C:WRITE-SUMMARY, écriture du statut.
;;
;; Il ne charge aucune source applicative ni aucune suite de tests.
;;
;; Variables à positionner AVANT de charger ce fichier :
;;   *tu:repo-dir*           racine du projet testé (obligatoire) ; les
;;                           chemins relatifs de tu:load... en partent.
;;   *outils-autolisp-root*  racine du dépôt outils-autolisp (obligatoire :
;;                           c'est elle qui a permis de trouver ce fichier).
;; Variables optionnelles :
;;   *tu:project-name*       libellé du bilan global, par exemple "SCHMS+".
;;   *tu:statusfile*         fichier de statut du harnais (prioritaire sur la
;;                           variable d'environnement STATUSFILE d'alfe).
;;   *AUTOLISP_OUTFILE*, *AUTOLISP_ERRFILE*, *AUTOLISP_STATUSFILE*,
;;   *AUTOLISP_WORKDIR*      replis des variables d'environnement OUTFILE,
;;                           ERRFILE, STATUSFILE et AUTOLISP_WORKDIR.
;;
;; Chargement : ce fichier doit être chargé par un (load ...) placé au
;; premier niveau d'un fichier lui-même chargé par alfe, pour que le lecteur
;; d'alfe normalise ses formes (sous AutoCAD, (princ) sans argument échoue
;; sinon). Il charge test-framework.lsp et vlisp-project.lsp de la même façon.
;; Il n'est pas listé dans autolisp-test.alpm : il redéfinit C:MAIN et une
;; partie du runner de test-framework.lsp.
;;
;; Les chaînes littérales restent en ASCII : les projets qui chargent ce
;; fichier lisent souvent leurs sources en WINDOWS-1252.

(vl-load-com)

(if (not (and (boundp '*tu:repo-dir*) *tu:repo-dir*))
  (progn
    (prompt "\n[tu] Error: set *tu:repo-dir* before loading autolisp-test/test-runner.lsp.")
    (exit)))
(if (not (and (boundp '*outils-autolisp-root*) *outils-autolisp-root*))
  (progn
    (prompt "\n[tu] Error: set *outils-autolisp-root* before loading autolisp-test/test-runner.lsp.")
    (exit)))

(load (strcat *outils-autolisp-root* "/autolisp-test/test-framework.lsp"))
(load (strcat *outils-autolisp-root* "/autolisp-test/vlisp-project.lsp"))

;; --- Chemins ---------------------------------------------------------------

;| @Global
  Indique si un chemin est absolu (/..., \..., ou lecteur C:...).
  @Param path string: chemin
  @Returns T|nil
|;
(defun tu:absolute-path-p (path)
  (and path
       (or (= (substr path 1 1) "/")
           (= (substr path 1 1) "\\")
           (= (substr path 2 1) ":"))))

;| @Global
  Chemin absolu d'un fichier du projet.
  @Param relative string: chemin relatif à *tu:repo-dir*, ou chemin absolu
  @Returns string: chemin absolu
|;
(defun tu:path (relative)
  (if (tu:absolute-path-p relative)
    relative
    (strcat *tu:repo-dir* "/" relative)))

(defun tu:find-first-file (paths / found)
  (while (and paths (null found))
    (setq found (findfile (car paths)))
    (setq paths (cdr paths)))
  found)

;| @Global
  Chemin d'un fichier du dépôt outils-autolisp.
  @Param relatif string: chemin relatif à *outils-autolisp-root*
  @Returns string|nil: chemin trouvé, ou nil
|;
(defun tu:outils-file (relatif)
  (findfile (strcat *outils-autolisp-root* "/" relatif)))

;; --- Chargement tolérant ---------------------------------------------------

;; Un échec de chargement (effet de bord, fichier manquant, dépendance non
;; résolue) est capturé et mémorisé, mais N'INTERROMPT PAS le harnais : sinon
;; C:RUN-NAMED et C:MAIN ne seraient jamais définis et le statut resterait à
;; 99. Les échecs sont comptés comme erreurs dans le bilan (C:MAIN et
;; C:WRITE-SUMMARY) : un test qui disparaît faute d'avoir été chargé ne doit
;; pas passer inaperçu.
(setq *tu:load-failures* nil)

;| @Global
  Mémorise un échec de chargement, compté comme erreur dans le bilan.
  @Param path string: fichier ou motif concerné
  @Param message string: diagnostic
  @Returns string: path
|;
(defun tu:note-load-failure (path message)
  (setq *tu:load-failures* (cons (cons path message) *tu:load-failures*))
  (princ (strcat "\n[tu] WARNING: echec chargement " path " : " message))
  path)

;| @Global
  Charge une source applicative et mémorise les échecs sans interrompre les suites.
  Sous alfe, utilise son lecteur pour normaliser les appels aux fonctions capturées.
  @Param path string: chemin relatif à la racine du projet, ou absolu
  @Returns string: chemin fourni, même si le chargement a échoué
|;
(defun tu:load (path / r)
  (setq r (vl-catch-all-apply 'tu:load-file (list (tu:path path))))
  (if (vl-catch-all-error-p r)
    (tu:note-load-failure path (vl-catch-all-error-message r)))
  path)

(setq *tu:test-counter* 0)

(defun tu:map-normalize (forms / form out)
  (setq out nil)
  (foreach form forms
    (setq out (cons (tu:normalize-form form) out)))
  (reverse out))

(defun tu:normalize-lambda (form)
  (cons 'lambda
        (cons (cadr form)
              (tu:map-normalize (cddr form)))))

(defun tu:normalize-form (form / op argc)
  (if (not (listp form))
    form
    (progn
      (setq op (car form))
      (setq argc (length (cdr form)))
      (cond
        ((eq op 'quote)
         form)
        ((and (eq op 'function) (listp (cadr form)) (eq (caadr form) 'lambda))
         (list 'function (tu:normalize-lambda (cadr form))))
        ((eq op 'lambda)
         (tu:normalize-lambda form))
        ((eq op 'is)
         (list 'tu:is
               (tu:normalize-form (cadr form))
               (if (> argc 1) (tu:normalize-form (caddr form)) nil)))
        ((eq op 'is-not)
         (list 'tu:is-not
               (tu:normalize-form (cadr form))
               (if (> argc 1) (tu:normalize-form (caddr form)) nil)))
        ((eq op 'is-equal)
         (list 'tu:is-equal
               (tu:normalize-form (cadr form))
               (tu:normalize-form (caddr form))
               (if (> argc 2) (tu:normalize-form (cadddr form)) nil)))
        ((eq op 'is-approx)
         (list 'tu:is-approx
               (tu:normalize-form (cadr form))
               (tu:normalize-form (caddr form))
               (tu:normalize-form (cadddr form))
               (if (> argc 3) (tu:normalize-form (nth 4 form)) nil)))
        ((eq op 'signals-error)
         (list 'tu:signals-error
               (tu:normalize-form (cadr form))
               (if (> argc 1) (tu:normalize-form (caddr form)) nil)))
        ((eq op 'expect-error)
         (list 'tu:expect-error
               (tu:normalize-form (cadr form))
               (if (> argc 1) (tu:normalize-form (caddr form)) nil)))
        (t
         (tu:map-normalize form))))))

(defun tu:blank-char-p (ch)
  (or (= ch 9) (= ch 10) (= ch 13) (= ch 32)))

(defun tu:skip-line-comment (stream / ch)
  (while (and (setq ch (read-char stream))
              (/= ch 10)
              (/= ch 13))))

(defun tu:skip-block-comment (stream / ch prev done)
  (setq prev nil)
  (setq done nil)
  (while (and (not done) (setq ch (read-char stream)))
    (if (and (= prev 124) (= ch 59))
      (setq done T)
      (setq prev ch))))

(defun tu:read-form-start-char (stream / ch next)
  ;; Les fichiers de tests peuvent contenir de la prose hors commentaires,
  ;; illisible par READ. Les formes de premier niveau utiles sont des listes :
  ;; on saute donc tout ce qui précède "(".
  (while (and (setq ch (read-char stream))
              (/= ch 40))
    (if (= ch 59)
      (progn
        (setq next (read-char stream))
        (if (and next (= next 124))
          (tu:skip-block-comment stream)
          (tu:skip-line-comment stream)))))
  ch)

;| @Global
  Lit une forme parenthésée en ignorant les commentaires de ligne et de bloc,
  y compris les blocs de documentation imbriqués dans une fonction.
  @Param stream file: fichier source ouvert en lecture
  @Returns string|nil: texte de la forme Lisp suivante, ou nil en fin de fichier
|;
(defun tu:read-form-string (stream / ch text depth in-string escape done comment-next)
  (setq ch (tu:read-form-start-char stream))
  (if (null ch)
    nil
    (progn
      (setq text "")
      (setq depth 0)
      (setq in-string nil)
      (setq escape nil)
      (setq done nil)
      (while (and ch (not done))
        (cond
          (in-string
           (setq text (strcat text (chr ch)))
           (cond
             (escape
              (setq escape nil))
             ((= ch 92)
              (setq escape T))
             ((= ch 34)
              (setq in-string nil))))
          ((= ch 34)
           (setq text (strcat text (chr ch)))
           (setq in-string T))
          ((= ch 59)
           (setq comment-next (read-char stream))
           (if (and comment-next (= comment-next 124))
             (tu:skip-block-comment stream)
             (tu:skip-line-comment stream))
           (setq text (strcat text " "))
           (setq ch nil))
          ((= ch 40)
           (setq text (strcat text (chr ch)))
           (setq depth (1+ depth)))
          ((= ch 41)
           (setq text (strcat text (chr ch)))
           (setq depth (1- depth))
           (if (= depth 0)
             (setq done T)))
          (t
           (setq text (strcat text (chr ch)))))
        (if (not done)
          (setq ch (read-char stream))))
      text)))

(defun tu:read-form (stream / text r)
  (setq text (tu:read-form-string stream))
  (if text
    (progn
      (setq r (vl-catch-all-apply 'read (list text)))
      (if (vl-catch-all-error-p r)
        (progn
          (prompt (strcat "\n[tu] cannot read test form: " text))
          (exit))
        r))
    nil))

(defun tu:lambda-local-arglist (arglist / item locals collect)
  (setq locals nil)
  (setq collect nil)
  (foreach item arglist
    (if collect
      (setq locals (cons item locals)))
    (if (eq item '/)
      (setq collect T)))
  (if collect
    (cons '/ (reverse locals))
    nil))

(defun tu:make-test-function (lambda-form / sym)
  (setq *tu:test-counter* (1+ *tu:test-counter*))
  (setq sym (read (strcat "TU-TEST-" (itoa *tu:test-counter*))))
  (defun-q-list-set sym (cons (tu:lambda-local-arglist (cadr lambda-form))
                              (cddr lambda-form)))
  sym)

(defun tu:test-thunk-form (form / thunk)
  (setq thunk (caddr form))
  (cond
    ((and (listp thunk) (eq (car thunk) 'function))
     (tu:make-test-function (tu:normalize-form (cadr thunk))))
    ((and (listp thunk) (eq (car thunk) 'quote))
     (tu:make-test-function (tu:normalize-form (cadr thunk))))
    ((and (listp thunk) (eq (car thunk) 'lambda))
     (tu:make-test-function (tu:normalize-form thunk)))
    (t
     (tu:normalize-form thunk))))

(defun tu:eval-test-form (form)
  (if (and (listp form) (eq (car form) 'deftest))
    (t:add-test *t:current-suite* (cadr form) (tu:test-thunk-form form))
    (eval form)))

;| @Global
  Charge un fichier absolu avec le lecteur normalisé d'alfe ou LOAD natif.
  @Param path string: chemin absolu du fichier Lisp
  @Returns A|string: valeur de la dernière forme, ou chemin avec le lecteur d'alfe
|;
(defun tu:load-file (path)
  (if (member "AUTOLISP-EVAL-REQUEST-FORM" (atoms-family 1))
    (tu:load-alfe-source path)
    (load path)))

;| @Global
  Lit une source avec le lecteur du harnais et applique la normalisation alfe.
  Ferme le fichier même lorsqu'une forme échoue ; propage alors cet échec.
  @Param path string: chemin absolu de la source
  @Returns string: chemin chargé
|;
(defun tu:load-alfe-source (path / source-stream source-form source-result)
  (setq source-stream (open path "r"))
  (if (null source-stream)
    (exit))
  (while (and (setq source-form (tu:read-form source-stream))
              (not (vl-catch-all-error-p source-result)))
    (setq source-result
          (vl-catch-all-apply 'autolisp-eval-request-form (list source-form))))
  (close source-stream)
  (if (vl-catch-all-error-p source-result)
    (progn
      (prompt (vl-catch-all-error-message source-result))
      (exit)))
  path)

;| @Global
  Charge un fichier de tests : chaque forme est lue par le lecteur du harnais,
  les deftest sont normalisés (assertions à message optionnel) et une forme
  en erreur est signalée sans interrompre les suivantes.
  @Param path string: chemin relatif à la racine du projet, ou absolu
  @Returns string: chemin fourni
|;
(defun tu:load-test (path / f form r)
  (setq f (open (tu:path path) "r"))
  (if (null f)
    (progn
      (prompt (strcat "\n[tu] cannot open " path))
      (exit)))
  (while (setq form (tu:read-form f))
    (setq r (vl-catch-all-apply 'tu:eval-test-form (list form)))
    (if (vl-catch-all-error-p r)
      (tu:report-error path (vl-princ-to-string form) "error"
                       (vl-catch-all-error-message r))))
  (close f)
  path)

;; --- Sélection de fichiers : tu:load-all et tu:load-project ----------------
;;
;; Motifs : chemins relatifs à *tu:repo-dir*, séparateur "/" (ou "\"), dont
;; chaque composant peut contenir les jokers * (toute suite de caractères),
;; ? (un caractère) et [...] (un caractère de l'ensemble ; [!...] pour
;; l'exclure). Tous les autres caractères sont littéraux ; la comparaison
;; ignore la casse, comme les systèmes de fichiers des CAO sous Windows.
;; Un joker ne franchit jamais un "/".
;;
;; Options : liste plate de 2n éléments (clé valeur ...), clés symboles :
;;   EXCLUDE motif   écarte les fichiers qui correspondent au motif ;
;;                   répétable.
;;   LOADER fonction symbole d'une fonction à un argument (chemin relatif)
;;                   utilisée pour charger chaque fichier ; tu:load par
;;                   défaut, tu:load-test pour des fichiers de tests.

(defun tu:string-index-p (ch text)
  (if (vl-string-search ch text) t nil))

;| @Global
  Indique si un composant de chemin contient un joker.
  @Param component string: composant de chemin (sans "/")
  @Returns T|nil
|;
(defun tu:wild-p (component)
  (or (tu:string-index-p "*" component)
      (tu:string-index-p "?" component)
      (tu:string-index-p "[" component)))

;| @Global
  Traduit un joker de fichier en motif WCMATCH : les caractères spéciaux de
  WCMATCH (# @ . ~ - , ` ]) hors jokers sont échappés par une apostrophe
  inverse, et [!...] devient [~...].
  @Param glob string: composant de chemin avec jokers
  @Returns string: motif WCMATCH équivalent
|;
(defun tu:glob->wcmatch (glob / i n ch out in-bracket bracket-start)
  (setq i 1)
  (setq n (strlen glob))
  (setq out "")
  (setq in-bracket nil)
  (while (<= i n)
    (setq ch (substr glob i 1))
    (cond
      (in-bracket
       (cond
         ((= ch "]")
          (setq out (strcat out ch))
          (setq in-bracket nil))
         ((and (= ch "!") bracket-start)
          (setq out (strcat out "~")))
         ((= ch "-")
          (setq out (strcat out ch)))
         ((tu:string-index-p ch "#@.*?~[,`")
          (setq out (strcat out "`" ch)))
         (t
          (setq out (strcat out ch))))
       (setq bracket-start nil))
      ((or (= ch "*") (= ch "?"))
       (setq out (strcat out ch)))
      ((= ch "[")
       (setq out (strcat out ch))
       (setq in-bracket t)
       (setq bracket-start t))
      ((tu:string-index-p ch "#@.~-,`]")
       (setq out (strcat out "`" ch)))
      (t
       (setq out (strcat out ch))))
    (setq i (1+ i)))
  out)

;| @Global
  Compare un nom de fichier à un composant de motif, sans tenir compte de la casse.
  @Param glob string: composant de motif
  @Param name string: nom de fichier ou de répertoire
  @Returns T|nil
|;
(defun tu:glob-match-p (glob name)
  (wcmatch (strcase name) (strcase (tu:glob->wcmatch glob))))

;| @Global
  Découpe un chemin en composants ; ignore les composants vides et ".".
  @Param path string: chemin, séparateurs "/" ou "\"
  @Returns string list: composants
|;
(defun tu:split-path (path / pos parts part result)
  (setq path (vl-string-translate "\\" "/" path))
  (setq parts nil)
  (while (setq pos (vl-string-search "/" path))
    (setq parts (cons (substr path 1 pos) parts))
    (setq path (substr path (+ pos 2))))
  (setq parts (cons path parts))
  (setq result nil)
  (foreach part parts
    (if (and (/= part "") (/= part "."))
      (setq result (cons part result))))
  result)

;| @Global
  Compare un chemin relatif à un motif, composant par composant.
  @Param glob string: motif de chemin
  @Param path string: chemin relatif
  @Returns T|nil
|;
(defun tu:glob-match-path-p (glob path / globs names ok)
  (setq globs (tu:split-path glob))
  (setq names (tu:split-path path))
  (setq ok (= (length globs) (length names)))
  (while (and ok globs)
    (setq ok (tu:glob-match-p (car globs) (car names)))
    (setq globs (cdr globs))
    (setq names (cdr names)))
  ok)

;| @Global
  Ordre lexicographique des chaînes, par codes de caractères. N'utilise pas
  (< a b) : clautolisp 2.2.85 ne compare pas les chaînes avec <.
  @Param a string
  @Param b string
  @Returns T|nil: T si a précède strictement b
|;
(defun tu:string< (a b / ca cb)
  (setq ca (vl-string->list a))
  (setq cb (vl-string->list b))
  (while (and ca cb (= (car ca) (car cb)))
    (setq ca (cdr ca))
    (setq cb (cdr cb)))
  (cond
    ((null cb) nil)
    ((null ca) t)
    (t (< (car ca) (car cb)))))

;| @Global
  Trie des chaînes par ordre lexicographique (tri par insertion, stable).
  @Param strings string list
  @Returns string list: nouvelle liste triée
|;
(defun tu:sort-strings (strings / s sorted head tail)
  (setq sorted nil)
  (foreach s strings
    (setq head nil)
    (setq tail sorted)
    (while (and tail (not (tu:string< s (car tail))))
      (setq head (cons (car tail) head))
      (setq tail (cdr tail)))
    (setq sorted (append (reverse head) (cons s tail))))
  sorted)

;| @Global
  Développe les composants restants d'un motif sous un répertoire.
  @Param directory string: répertoire absolu courant
  @Param prefix string: chemin relatif correspondant ("" ou "a/b/")
  @Param globs string list: composants de motif restant à développer
  @Returns string list: chemins relatifs des fichiers trouvés (non triés)
|;
(defun tu:expand-glob (directory prefix globs / glob entry found)
  (setq glob (car globs))
  (setq found nil)
  (cond
    ((null globs)
     nil)
    ((null (cdr globs))
     (if (tu:wild-p glob)
       (foreach entry (vl-directory-files directory nil 1)
         (if (tu:glob-match-p glob entry)
           (setq found (cons (strcat prefix entry) found))))
       (if (and (findfile (strcat directory "/" glob))
                (not (vl-file-directory-p (strcat directory "/" glob))))
         (setq found (list (strcat prefix glob))))))
    ((tu:wild-p glob)
     (foreach entry (vl-directory-files directory nil -1)
       (if (and (/= entry ".") (/= entry "..") (tu:glob-match-p glob entry))
         (setq found
               (append (tu:expand-glob (strcat directory "/" entry)
                                       (strcat prefix entry "/")
                                       (cdr globs))
                       found)))))
    (t
     (setq found (tu:expand-glob (strcat directory "/" glob)
                                 (strcat prefix glob "/")
                                 (cdr globs)))))
  found)

;| @Global
  Fichiers du projet désignés par un motif, en ordre lexicographique.
  @Param pattern string: motif relatif à *tu:repo-dir*
  @Returns string list: chemins relatifs
|;
(defun tu:glob (pattern)
  (tu:sort-strings (tu:expand-glob *tu:repo-dir* "" (tu:split-path pattern))))

;| @Global
  Vérifie une liste d'options (clé valeur ...) de tu:load-all / tu:load-project.
  @Param options A list: options
  @Returns string|nil: diagnostic de la première option invalide, ou nil
|;
(defun tu:load-options-error (options / key value problem)
  (setq problem nil)
  (while (and options (null problem))
    (setq key (car options))
    (setq value (cadr options))
    (cond
      ((null (cdr options))
       (setq problem (strcat "option sans valeur : " (vl-princ-to-string key))))
      ((eq key 'exclude)
       (if (/= (type value) 'STR)
         (setq problem (strcat "EXCLUDE attend un motif (chaine) : "
                               (vl-princ-to-string value)))))
      ((eq key 'loader)
       (if (not (and (= (type value) 'SYM)
                     (member (type (vl-symbol-value value))
                             '(SUBR USUBR EXRXSUBR))))
         (setq problem (strcat "LOADER attend le nom d'une fonction : "
                               (vl-princ-to-string value)))))
      (t
       (setq problem (strcat "option inconnue : " (vl-princ-to-string key)))))
    (setq options (cddr options)))
  problem)

;| @Global
  Valeurs d'une clé dans une liste d'options, dans l'ordre.
  @Param options A list: options (clé valeur ...)
  @Param key symbol: clé cherchée
  @Returns A list: valeurs associées à key
|;
(defun tu:load-option-values (options key / values)
  (setq values nil)
  (while options
    (if (eq (car options) key)
      (setq values (cons (cadr options) values)))
    (setq options (cddr options)))
  (reverse values))

;| @Global
  Indique si un chemin relatif correspond à l'un des motifs d'exclusion.
  @Param path string: chemin relatif
  @Param excludes string list: motifs
  @Returns T|nil
|;
(defun tu:excluded-p (path excludes / excluded)
  (setq excluded nil)
  (while (and excludes (not excluded))
    (setq excluded (tu:glob-match-path-p (car excludes) path))
    (setq excludes (cdr excludes)))
  excluded)

;| @Global
  Charge des fichiers dans l'ordre donné, sauf ceux exclus par les options.
  @Param origin string: motif ou projet d'origine, pour les diagnostics
  @Param paths string list: chemins relatifs candidats
  @Param options A list: options vérifiées (EXCLUDE, LOADER)
  @Returns string list: chemins effectivement passés au chargeur
|;
(defun tu:load-selected (origin paths options / excludes loader path loaded r)
  (setq excludes (tu:load-option-values options 'exclude))
  (setq loader (car (tu:load-option-values options 'loader)))
  (if (null loader)
    (setq loader 'tu:load))
  (setq loaded nil)
  (foreach path paths
    (if (not (tu:excluded-p path excludes))
      (progn
        (setq r (vl-catch-all-apply loader (list path)))
        (if (vl-catch-all-error-p r)
          (tu:note-load-failure path (vl-catch-all-error-message r)))
        (setq loaded (cons path loaded)))))
  (reverse loaded))

;| @Global
  Charge, en ordre lexicographique, les fichiers désignés par un motif, sauf
  ceux qu'excluent les options. Un motif qui ne désigne aucun fichier, ou des
  options invalides, sont signalés comme échecs de chargement.
  Exemple : (tu:load-all "tests/test-unitaire-*.lsp"
                         '(exclude "tests/test-unitaire-foo*.lsp"
                           exclude "tests/test-unitaire-broken.lsp"))
  @Param pattern string: motif relatif à *tu:repo-dir*
  @Param options A list: (clé valeur ...) ; clés EXCLUDE et LOADER
  @Returns string list: chemins relatifs chargés
|;
(defun tu:load-all (pattern options / problem paths)
  (setq problem (tu:load-options-error options))
  (cond
    (problem
     (tu:note-load-failure pattern problem)
     nil)
    ((null (setq paths (tu:glob pattern)))
     (tu:note-load-failure pattern "aucun fichier ne correspond au motif")
     nil)
    (t
     (tu:load-selected pattern paths options))))

;| @Global
  Charge, dans l'ordre de :OWN-LIST, les sources d'un projet Visual LISP,
  sauf celles qu'excluent les options. Les éléments de :OWN-LIST sont relatifs
  au répertoire du .prj ; les motifs EXCLUDE s'appliquent aux chemins relatifs
  à *tu:repo-dir* (par exemple "src-vlx/termine.lsp").
  @Param prj-path string: fichier .prj, relatif à *tu:repo-dir*
  @Param options A list: (clé valeur ...) ; clés EXCLUDE et LOADER
  @Returns string list: chemins relatifs chargés
|;
(defun tu:load-project (prj-path options / problem project)
  (setq problem (tu:load-options-error options))
  (cond
    (problem
     (tu:note-load-failure prj-path problem)
     nil)
    ((null (setq project (read-vlisp-project-file (tu:path prj-path))))
     (tu:note-load-failure prj-path "projet VLISP illisible ou invalide")
     nil)
    (t
     (tu:load-selected
       prj-path
       (vlisp-project-sources project (vl-filename-directory prj-path))
       options))))

;; --- Introspection des entités (tests CAD seulement) -----------------------
;; ei-snapshot / ei-diff (photo avant / après) et le DSL d'assertions
;; attendu-... sont chargés à la demande : les suites unitaires n'en ont pas
;; besoin.

;| @Global
  Charge les outils d'introspection et d'assertion CAD avec le lecteur adapté.
  @Returns T: outils chargés ; interrompt le chargement si fichiers absents
|;
(defun tu:load-introspection (/ introspection entites)
  (setq introspection
         (tu:outils-file "autolisp-introspection/src/autolisp-introspection.lsp"))
  (setq entites
         (tu:outils-file "autolisp-test/test-entites.lsp"))
  (if (or (null introspection) (null entites))
    (progn
      (prompt
        (strcat "\n[tu] Error: cannot resolve autolisp-introspection under "
                *outils-autolisp-root*))
      (exit)))
  ;; L'ordre compte : test-entites.lsp utilise ei--value-equal.
  (tu:load-file introspection)
  (tu:load-file entites)
  t)

;; --- Exécution des tests ---------------------------------------------------

(setq *t:trace-tests* nil)

(defun t:trace (label value /)
  (if *t:trace-tests*
    (t:emit-out
      (strcat "TRACE " label " " (vl-princ-to-string value))))
  value)

(defun t:trace-caught-result (label r / s)
  (setq s
        (if (vl-catch-all-error-p r)
          (strcat "ERROR " (vl-catch-all-error-message r))
          (strcat "VALUE " (vl-princ-to-string r))))
  (t:trace label s)
  r)

(setq *t:throw-tag* nil)
(setq *t:throw-value* nil)

(defun t:throw (tag value /)
  (t:trace "t:throw/entry" (list tag value))
  (setq *t:throw-tag* tag)
  (setq *t:throw-value* value)
  (t:trace "t:throw/before-quit" (list *t:throw-tag* *t:throw-value*))
  (quit))

(defun t:fail (msg /)
  (t:trace "t:fail" msg)
  (t:throw 'fail msg))

(defun fail (msg /)
  (t:fail msg))

(defun tu:is (condition msg)
  (if (not condition)
    (t:fail (if msg msg "is: condition is false"))
    t))

(defun tu:is-not (condition msg)
  (if condition
    (t:fail (if msg msg "is-not: condition is true"))
    t))

(defun tu:is-equal (expected actual msg)
  (if (not (equal expected actual))
    (t:fail (if msg msg (t:format-compare "is-equal:" expected actual)))
    t))

(defun tu:is-approx (expected actual tol msg)
  (if (not (equal expected actual tol))
    (t:fail
      (if msg
        msg
        (strcat "is-approx:"
                " expected="
                (t:str expected)
                " actual="
                (t:str actual)
                " tol="
                (t:str tol))))
    t))

(defun t:unwrap-thunk (thunk)
  (cond
    ((and (listp thunk) (eq (car thunk) 'function))
     (t:unwrap-thunk (cadr thunk)))
    ((and (listp thunk) (eq (car thunk) 'quote))
     (t:unwrap-thunk (cadr thunk)))
    (t
     thunk)))

(defun t:call-thunk (thunk / fn)
  (setq fn (t:unwrap-thunk thunk))
  (t:trace "t:call-thunk/fn" fn)
  (cond
    ((and (listp fn) (eq (car fn) 'lambda))
     (t:trace "t:call-thunk/call" "lambda")
     (eval (list fn)))
    ((not (listp fn))
     (t:trace "t:call-thunk/call" fn)
     (eval (list fn)))
    (t
     (t:trace "t:call-thunk/call" "apply")
     (apply fn nil))))

(defun t:run-test (suite-name test / name fn r em tag value prev-err)
  (setq name (car test))
  (setq fn   (cadr test))
  (setq *t:throw-tag* nil)
  (setq *t:throw-value* nil)
  (setq *tu:last-error-msg* nil)
  (t:trace "t:run-test/start" (list suite-name name fn))

  (setq prev-err *error*)
  (setq *error* tu:tests-error-handler)
  (setq r (vl-catch-all-apply 't:call-thunk (list fn)))
  (setq *error* prev-err)
  (t:trace-caught-result "t:run-test/result" r)
  (setq tag *t:throw-tag*)
  (setq value *t:throw-value*)
  (t:trace "t:run-test/tag-value" (list tag value))

  (cond
    ((eq tag 'fail)
     (list 'fail suite-name name value))
    (tag
     (tu:report-error suite-name name "abort"
                      (vl-princ-to-string (list tag value)))
     (list 'abort suite-name name (list tag value)))
    ((vl-catch-all-error-p r)
     (setq em (vl-catch-all-error-message r))
     (tu:report-error suite-name name "error" em)
     (list 'error suite-name name em))
    (t
     (list 'ok suite-name name nil))))

(defun tu:expected-error-message (msg)
  (setq msg (if msg msg "signals-error: expected an error"))
  msg)

(defun tu:expect-error (thunk msg / r tag value)
  (setq msg (tu:expected-error-message msg))
  (setq *t:throw-tag* nil)
  (setq *t:throw-value* nil)
  (t:trace "tu:expect-error/start" thunk)
  (setq r (vl-catch-all-apply 't:call-thunk (list thunk)))
  (t:trace-caught-result "tu:expect-error/result" r)
  (setq tag *t:throw-tag*)
  (setq value *t:throw-value*)
  (t:trace "tu:expect-error/tag-value" (list tag value))
  (cond
    ((eq tag 'fail)
     (t:throw tag value))
    (tag
     (t:throw tag value))
    ((vl-catch-all-error-p r)
     t)
    (t
     (t:fail msg))))

(defun tu:signals-error (thunk msg /)
  (tu:expect-error thunk msg))

(defun t:result-message (res)
  (if (nth 3 res)
    (strcat " -- " (vl-princ-to-string (nth 3 res)))
    ""))

(defun t:print-result (res / kind suite name prefix)
  (setq kind (car res))
  (setq suite (cadr res))
  (setq name (caddr res))
  (t:trace "t:print-result/res" res)
  (setq prefix
        (cond
          ((eq kind 'ok) "OK   ")
          ((eq kind 'fail) "FAIL ")
          ((eq kind 'error) "ERROR")
          ((eq kind 'abort) "ABORT")
          (t "???? ")))
  (t:emit-out
    (strcat prefix " [" suite "] " name (t:result-message res))))

(defun run-suite (suite-name / cell tests test total ok fail err abort res)
  (setq cell (assoc suite-name *t:suites*))
  (if (null cell)
    (progn
      (prompt (strcat "\n[run-suite] Unknown suite: " suite-name))
      nil)
    (progn
      (setq tests (reverse (cdr cell)))
      (setq total 0)
      (setq ok 0)
      (setq fail 0)
      (setq err 0)
      (setq abort 0)

      (foreach test tests
        (setq total (1+ total))
        (setq res (t:run-test suite-name test))
        (t:print-result res)
        (cond
          ((eq (car res) 'ok)    (setq ok (1+ ok)))
          ((eq (car res) 'fail)  (setq fail (1+ fail)))
          ((eq (car res) 'error) (setq err (1+ err)))
          (t                     (setq abort (1+ abort)))))

      (t:emit-out (strcat "---- Suite [" suite-name "] ----"))
      (t:emit-out (tu:summary-line total ok fail err abort))
      (setq *t:last-total* (+ *t:last-total* total))
      (setq *t:last-ok* (+ *t:last-ok* ok))
      (setq *t:last-fail* (+ *t:last-fail* fail))
      (setq *t:last-error* (+ *t:last-error* err))
      (setq *t:last-abort* (+ *t:last-abort* abort))
      (list 'suite suite-name 'total total 'ok ok 'fail fail 'error err 'abort abort))))

(defun run-all (/ s summaries)
  (setq *t:last-total* 0)
  (setq *t:last-ok* 0)
  (setq *t:last-fail* 0)
  (setq *t:last-error* 0)
  (setq *t:last-abort* 0)
  (setq summaries nil)
  (foreach s *t:suites*
    (setq summaries (cons (run-suite (car s)) summaries)))
  (reverse summaries))

;; --- Canaux de sortie et statut --------------------------------------------

(defun tu:write-line-to (path s / f)
  (if (and path (/= path ""))
    (progn
      (setq f (open path "a"))
      (if f
        (progn
          (write-line s f)
          (close f))))))

(defun tu:write-file-line (path s / f)
  (if (and path (/= path ""))
    (progn
      (setq f (open path "w"))
      (if f
        (progn
          (write-line s f)
          (close f))))))

;| @Global
  Résout un fichier du harnais. Le statut Lisp explicite *tu:statusfile* est
  prioritaire sur STATUSFILE, qui peut désigner le statut du protocole alfe.
  @Param name string: OUTFILE, ERRFILE ou STATUSFILE
  @Returns string|nil: chemin configuré
|;
(defun tu:channel-path (name / v)
  (setq v (if (and (= name "STATUSFILE")
                   (boundp '*tu:statusfile*)
                   *tu:statusfile*
                   (/= *tu:statusfile* ""))
            *tu:statusfile*
            (getenv name)))
  (if (or (null v) (= v ""))
    (cond
      ((= name "OUTFILE") *AUTOLISP_OUTFILE*)
      ((= name "ERRFILE") *AUTOLISP_ERRFILE*)
      ((= name "STATUSFILE") *AUTOLISP_STATUSFILE*)
      (t nil))
    v))

;| @Global
  Écrit le statut du harnais et, quand alfe ou clautolisp le fournit, le
  transmet aussi par autolisp-set-status.
  @Param code int: 0 si tout est passé, non nul sinon
  @Returns int: code
|;
(defun tu:set-status (code)
  (tu:write-file-line (tu:channel-path "STATUSFILE") (itoa code))
  (if (member "AUTOLISP-SET-STATUS" (atoms-family 1))
    (vl-catch-all-apply 't:set-status (list code)))
  code)

(defun tu:log-out (s)
  (tu:write-line-to (tu:channel-path "OUTFILE") s))

(defun tu:log-err (s)
  (tu:write-line-to (tu:channel-path "ERRFILE") s))

(defun tu:slurp (path / f line text)
  (setq f (open path "r"))
  (setq text "")
  (if (null f)
    (progn
      (prompt (strcat "\n[tu] cannot open " path))
      (exit)))
  (while (setq line (read-line f))
    (setq text (strcat text line "\n")))
  (close f)
  text)

(defun tu:contains (hay needle)
  (if (vl-string-search needle hay) t nil))

(setq *tu:error-counter* 0)

(defun tu:workdir (/ v out)
  (cond
    ((and (boundp '*AUTOLISP_WORKDIR*) *AUTOLISP_WORKDIR*
          (/= *AUTOLISP_WORKDIR* ""))
     *AUTOLISP_WORKDIR*)
    ((and (setq v (getenv "AUTOLISP_WORKDIR")) (/= v ""))
     v)
    ((setq out (tu:channel-path "OUTFILE"))
     (vl-filename-directory out))
    (t nil)))

(defun tu:errlog-path (/ wd)
  (setq wd (tu:workdir))
  (if wd (strcat wd "/errors.log") nil))

(defun tu:report-line (s / errlog)
  (setq errlog (tu:errlog-path))
  (tu:log-out s)
  (tu:log-err s)
  (if errlog (tu:write-line-to errlog s)))

;; --- Capture de (vl-bt) ----------------------------------------------------
;; AutoCAD (accoreconsole) redirige sa console vers un fichier via le
;; harnais ; (vl-bt) y atterrit naturellement. BricsCAD en /B ne redirige pas
;; la console LISP : on force LOGFILE pendant le backtrace pour qu'il soit
;; écrit dans le journal (LOGFILENAME), retrouvable depuis errors.log par les
;; marqueurs TU-BT-START / TU-BT-END.

(defun tu:engine (/ r)
  ;; Nom du programme hôte en majuscules, ou "".
  (setq r (vl-catch-all-apply 'getvar (list "PROGRAM")))
  (cond
    ((vl-catch-all-error-p r) "")
    ((null r) "")
    (t (strcase r))))

(defun tu:bt-target-file (/ r)
  ;; Fichier où la sortie de (vl-bt) est capturée.
  (cond
    ((wcmatch (tu:engine) "*BRICS*")
     (setq r (vl-catch-all-apply 'getvar (list "LOGFILENAME")))
     (if (or (vl-catch-all-error-p r) (null r) (= r ""))
       "(LOGFILE BricsCAD)"
       r))
    (t "console-cao.out")))

(defun tu:bt-marker (suite name kind n)
  ;; Texte du marqueur placé autour de (vl-bt), identique au début et à la
  ;; fin (au préfixe START/END près), quel que soit le moteur.
  (strcat "[" (if suite suite "") "] "
          (if name name "")
          " (" (strcase kind) " #" (itoa n) ")"))

(defun tu:report-error (suite name kind msg / banner tag)
  (setq *tu:error-counter* (1+ *tu:error-counter*))
  (setq banner
    "========================================================================")
  (setq tag (tu:bt-marker suite name kind *tu:error-counter*))
  (tu:report-line "")
  (tu:report-line banner)
  (tu:report-line
    (strcat (strcase kind) " #" (itoa *tu:error-counter*)
            " [" (if suite suite "") "] "
            (if name name "")))
  (tu:report-line (strcat "MESSAGE: " (if msg msg "")))
  (tu:report-line
    (strcat "BACKTRACE: voir " (tu:bt-target-file)
            " entre les marqueurs"))
  (tu:report-line
    (strcat "           === TU-BT-START " tag " ==="))
  (tu:report-line
    (strcat "           === TU-BT-END "   tag " ==="))
  (tu:report-line banner)
  (tu:report-line "")
  (princ))

(defun tu:tests-error-handler (msg)
  ;; *error* installé par t:run-test autour de chaque thunk de test. La pile
  ;; est encore intacte ici (avant le retour de vl-catch-all-apply), donc
  ;; (vl-bt) produit un vrai backtrace.
  (setq *tu:last-error-msg* msg)
  (princ (strcat "\n*error*: " (if msg msg "")))
  (tu:emit-bt
    (tu:bt-marker
      (if (boundp '*tu:current-suite*) *tu:current-suite* "")
      (if (boundp '*tu:current-test*)  *tu:current-test*  "")
      "error"
      (1+ *tu:error-counter*)))
  (princ))

(defun tu:logfile-on (/ wd prev)
  ;; Active LOGFILE et renvoie l'ancienne valeur de LOGFILEMODE (0 ou 1).
  (setq prev (vl-catch-all-apply 'getvar (list "LOGFILEMODE")))
  (if (vl-catch-all-error-p prev) (setq prev 0))
  (setq wd (tu:workdir))
  (if wd (vl-catch-all-apply 'setvar (list "LOGFILEPATH" wd)))
  (vl-catch-all-apply 'setvar (list "LOGFILEMODE" 1))
  prev)

(defun tu:logfile-restore (prev)
  (vl-catch-all-apply 'setvar (list "LOGFILEMODE" (if prev prev 0))))

(defun tu:emit-bt (tag / prev)
  (setq prev (tu:logfile-on))
  (princ (strcat "\n=== TU-BT-START " tag " ===\n"))
  (vl-catch-all-apply 'vl-bt nil)
  (princ (strcat "\n=== TU-BT-END "   tag " ===\n"))
  (tu:logfile-restore prev)
  (princ))

;; --- Points d'entrée ---------------------------------------------------------

(setq *tu:total-count* 0)
(setq *tu:ok-count*    0)
(setq *tu:fail-count*  0)
(setq *tu:error-count* 0)

(defun tu:trap-error (msg)
  ;; *error* invoqué par AutoLISP au site de l'erreur, hors
  ;; vl-catch-all-apply : la pile est intacte, vl-bt produit donc un vrai
  ;; backtrace.
  (cond
    ((eq *t:throw-tag* 'fail)
     (setq *tu:fail-count* (1+ *tu:fail-count*))
     (t:emit-out
       (strcat "FAIL  ["
               (if (boundp '*tu:current-suite*) *tu:current-suite* "")
               "] "
               (if (boundp '*tu:current-test*) *tu:current-test* "")
               " -- "
               (vl-princ-to-string *t:throw-value*))))
    (t
     (setq *tu:error-count* (1+ *tu:error-count*))
     ;; tu:report-error numérotera (1+ *tu:error-counter*) : on l'anticipe
     ;; pour le marqueur.
     (tu:emit-bt
       (tu:bt-marker
         (if (boundp '*tu:current-suite*) *tu:current-suite* "")
         (if (boundp '*tu:current-test*)  *tu:current-test*  "")
         "error"
         (1+ *tu:error-counter*)))
     (tu:report-error
       (if (boundp '*tu:current-suite*) *tu:current-suite* "")
       (if (boundp '*tu:current-test*) *tu:current-test* "")
       "error"
       msg)))
  nil)

(defun C:RUN-NAMED (suite-name test-name / cell tests cur match fn)
  (setq cell (assoc suite-name *t:suites*))
  (cond
    ((null cell)
     (setq *tu:total-count* (1+ *tu:total-count*))
     (setq *tu:error-count* (1+ *tu:error-count*))
     (tu:report-error suite-name test-name "error"
                      "(suite introuvable)"))
    (t
     (setq tests (cdr cell))
     (setq match nil)
     (foreach cur tests
       (if (= (car cur) test-name)
         (setq match cur)))
     (cond
       ((null match)
        (setq *tu:total-count* (1+ *tu:total-count*))
        (setq *tu:error-count* (1+ *tu:error-count*))
        (tu:report-error suite-name test-name "error"
                         "(test introuvable)"))
       (t
        (setq fn (cadr match))
        (setq *tu:current-suite* suite-name)
        (setq *tu:current-test*  test-name)
        (setq *t:throw-tag*   nil)
        (setq *t:throw-value* nil)
        (setq *tu:total-count* (1+ *tu:total-count*))
        (setq *error* tu:trap-error)
        (eval (list (t:unwrap-thunk fn)))
        ;; Atteint seulement si le test est passé sans erreur.
        (setq *tu:ok-count* (1+ *tu:ok-count*))
        (t:emit-out (strcat "OK    [" suite-name "] " test-name))))))
  (princ))

;| @Global
  Formate un bilan avec les cinq compteurs.
  @Param total int: nombre total de tests
  @Param ok int: nombre de tests réussis
  @Param fail int: nombre d'échecs d'assertion
  @Param err int: nombre d'erreurs d'exécution
  @Param abort int: nombre de tests interrompus
  @Returns string: bilan
|;
(defun tu:summary-line (total ok fail err abort)
  (strcat "Total: " (itoa total)
          "  OK: "    (itoa ok)
          "  FAIL: "  (itoa fail)
          "  ERROR: " (itoa err)
          "  ABORT: " (itoa abort)))

;| @Global
  Bilan global, préfixé par *tu:project-name* quand il est défini.
  @Returns string: bilan global
|;
(defun tu:global-summary-line (total ok fail err abort)
  (strcat (if (and (boundp '*tu:project-name*) *tu:project-name*)
            (strcat "==== " *tu:project-name* " ==== ")
            "")
          (tu:summary-line total ok fail err abort)))

;| @Global
  Signale chaque échec de chargement mémorisé comme une erreur.
  @Returns int: nombre d'échecs de chargement
|;
(defun tu:report-load-failures (/ failure)
  (foreach failure (reverse *tu:load-failures*)
    (t:emit-out (strcat "ERROR [(chargement)] " (car failure)
                        " -- " (cdr failure)))
    (tu:report-error "(chargement)" (car failure) "error" (cdr failure)))
  (length *tu:load-failures*))

;| @Global
  Écrit le bilan global des tests exécutés par C:RUN-NAMED et leur statut.
  Les interruptions du chemin natif sont comptées comme erreurs ; ABORT vaut 0.
|;
(defun C:WRITE-SUMMARY (/ load-failures)
  (setq load-failures (tu:report-load-failures))
  (setq *tu:total-count* (+ *tu:total-count* load-failures))
  (setq *tu:error-count* (+ *tu:error-count* load-failures))
  (t:emit-out
    (tu:global-summary-line *tu:total-count* *tu:ok-count*
                            *tu:fail-count* *tu:error-count* 0))
  (if (or (> *tu:fail-count* 0) (> *tu:error-count* 0))
    (tu:set-status 1)
    (tu:set-status 0))
  (princ))

;| @Global
  Exécute toutes les suites, écrit le bilan global et le statut. Un échec,
  une erreur, une interruption ou un échec de chargement rend le statut non nul.
|;
(defun C:MAIN (/ total ok fail err abort r load-failures)
  (setq *error*
    (lambda (msg)
      (if (and msg (wcmatch (strcase msg) "*QUIT*EXIT*ABORT*"))
        (princ)
        (progn
          (tu:report-error "(framework)" "*error*" "error" msg)
          (tu:set-status 1)))
      (princ)))

  (setq r (vl-catch-all-apply 'run-all nil))
  (if (vl-catch-all-error-p r)
    (progn
      (tu:report-error "(framework)" "run-all" "error"
                       (vl-catch-all-error-message r))
      (tu:set-status 1)))
  (setq load-failures (tu:report-load-failures))
  (setq total (+ *t:last-total* load-failures))
  (setq ok *t:last-ok*)
  (setq fail *t:last-fail*)
  (setq err (+ *t:last-error* load-failures))
  (setq abort *t:last-abort*)

  (t:emit-out (tu:global-summary-line total ok fail err abort))
  (if (or (vl-catch-all-error-p r) (> (+ fail err abort) 0))
    (tu:set-status 1)
    (tu:set-status 0))
  (princ))

(princ)
