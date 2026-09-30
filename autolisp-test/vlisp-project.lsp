;; vlisp-project.lsp -- Lecture des fichiers projet Visual LISP (.prj).
;;
;; Un fichier .prj est une forme (VLISP-PROJECT-LIST :NAME nom :OWN-LIST (...)
;; ...) précédée de commentaires. READ d'AutoLISP ne sait pas sauter les
;; commentaires : on les retire donc (hors chaînes) avant de lire la forme.
;;
;; API (compatible avec dev/lisp/make-loader.lsp de SCHMS+) :
;;   (read-vlisp-project-file path)          -> alist | nil
;;   (vlisp-project-name alist)              -> string | nil
;;   (vlisp-project-own-list alist)          -> liste de chaînes
;;   (vlisp-project-fas-directory alist)     -> valeur | nil
;;   (vlisp-project-tmp-directory alist)     -> valeur | nil
;;   (vlisp-project-keys alist)              -> valeur | nil
;;   (vlisp-project-context-id alist)        -> valeur | nil
;;   (vlisp-project-sources alist directory) -> liste de chemins
;;
;; Contrairement à make-loader.lsp, un fichier illisible ou invalide ne
;; signale pas d'erreur : read-vlisp-project-file renvoie nil et l'appelant
;; décide (AutoLISP n'a pas de primitive portable pour signaler une erreur).
;; Les chaînes littérales de ce fichier restent en ASCII : il est chargé par
;; des projets qui lisent leurs sources en WINDOWS-1252.

;| @Global
  Lit un fichier texte en entier.
  @Param path string: chemin du fichier
  @Returns string|nil: contenu, lignes séparées par des sauts de ligne ; nil si illisible
|;
(defun vlisp-project--slurp (path / stream line lines)
  (setq stream (open path "r"))
  (if stream
    (progn
      (setq lines nil)
      (while (setq line (read-line stream))
        (setq lines (cons "\n" (cons line lines))))
      (close stream)
      (apply 'strcat (reverse lines)))
    nil))

;| @Global
  Retire les commentaires de ligne et de bloc situés hors des chaînes littérales.
  @Param text string: texte source
  @Returns string: texte sans commentaires, chaque commentaire remplacé par une espace
|;
(defun vlisp-project--strip-comments (text / codes out ch next state)
  (setq codes (vl-string->list text))
  (setq out nil)
  ;; state : nil (code), string, escape, line-comment, block-comment
  (setq state nil)
  (while codes
    (setq ch (car codes))
    (setq next (cadr codes))
    (setq codes (cdr codes))
    (cond
      ((eq state 'string)
       (setq out (cons ch out))
       (cond
         ((= ch 92) (setq state 'escape))
         ((= ch 34) (setq state nil))))
      ((eq state 'escape)
       (setq out (cons ch out))
       (setq state 'string))
      ((eq state 'line-comment)
       (if (or (= ch 10) (= ch 13))
         (progn
           (setq out (cons ch out))
           (setq state nil))))
      ((eq state 'block-comment)
       (if (and (= ch 124) next (= next 59))
         (progn
           (setq codes (cdr codes))
           (setq out (cons 32 out))
           (setq state nil))))
      ((= ch 34)
       (setq out (cons ch out))
       (setq state 'string))
      ((= ch 59)
       (if (and next (= next 124))
         (progn
           (setq codes (cdr codes))
           (setq state 'block-comment))
         (setq state 'line-comment))
       (setq out (cons 32 out)))
      (t
       (setq out (cons ch out)))))
  (vl-list->string (reverse out)))

;| @Global
  Nom d'une clé de propriété (symbole ou autre valeur), en majuscules.
  @Param key A: clé lue dans la liste de propriétés
  @Returns string: par exemple ":OWN-LIST"
|;
(defun vlisp-project--key-name (key)
  (strcase
    (if (= (type key) 'SYM)
      (vl-symbol-name key)
      (vl-princ-to-string key))))

;| @Global
  Extrait du texte le jeton qui suit :NAME, en respectant sa casse
  (READ convertirait le nom en symbole majuscule).
  @Param text string: texte du projet, sans commentaires
  @Returns string|nil: nom du projet tel qu'écrit dans le fichier
|;
(defun vlisp-project--raw-name (text / pos codes token ch)
  (setq pos (vl-string-search ":NAME" (strcase text)))
  (if pos
    (progn
      (setq codes (vl-string->list (substr text (+ pos 6))))
      (while (and codes (member (car codes) '(9 10 13 32)))
        (setq codes (cdr codes)))
      (setq token nil)
      (while (and codes (not (member (car codes) '(9 10 13 32 40 41))))
        (setq ch (car codes))
        (if (/= ch 34)
          (setq token (cons ch token)))
        (setq codes (cdr codes)))
      (if token (vl-list->string (reverse token)) nil))
    nil))

;| @Global
  Lit un fichier projet Visual LISP.
  @Param path string: chemin du fichier .prj
  @Returns (A . A) list|nil: alist (clé . valeur) dans l'ordre du fichier ;
    nil si le fichier est illisible ou n'est pas un projet VLISP
|;
(defun read-vlisp-project-file (path / text form plist alist name)
  (setq text (vlisp-project--slurp path))
  (if text
    (progn
      (setq text (vlisp-project--strip-comments text))
      (setq form (vl-catch-all-apply 'read (list text)))
      (if (and (not (vl-catch-all-error-p form))
               (listp form)
               (= (type (car form)) 'SYM)
               (= (vlisp-project--key-name (car form)) "VLISP-PROJECT-LIST"))
        (progn
          (setq plist (cdr form))
          (setq alist nil)
          (while (and plist (cdr plist))
            (setq alist (cons (cons (car plist) (cadr plist)) alist))
            (setq plist (cddr plist)))
          (if plist
            nil
            (progn
              (setq alist (reverse alist))
              (setq name (vlisp-project--raw-name text))
              (if name
                (vlisp-project--replace alist ":NAME" name)
                alist))))
        nil))
    nil))

;| @Global
  Remplace la valeur associée à une clé.
  @Param alist (A . A) list: projet lu par read-vlisp-project-file
  @Param key-name string: nom de clé en majuscules, par exemple ":NAME"
  @Param new-value A: nouvelle valeur
  @Returns (A . A) list: nouvelle alist
|;
(defun vlisp-project--replace (alist key-name new-value / pair result)
  (setq result nil)
  (foreach pair alist
    (if (= (vlisp-project--key-name (car pair)) key-name)
      (setq result (cons (cons (car pair) new-value) result))
      (setq result (cons pair result))))
  (reverse result))

;| @Global
  Valeur associée à une clé du projet.
  @Param alist (A . A) list: projet lu par read-vlisp-project-file
  @Param key-name string: nom de clé en majuscules, par exemple ":OWN-LIST"
  @Returns A|nil: valeur, ou nil si la clé est absente
|;
(defun vlisp-project--get (alist key-name / pair value)
  (setq value nil)
  (foreach pair alist
    (if (= (vlisp-project--key-name (car pair)) key-name)
      (setq value (cdr pair))))
  value)

(defun vlisp-project-name (alist)
  (vlisp-project--get alist ":NAME"))

(defun vlisp-project-own-list (alist)
  (vlisp-project--get alist ":OWN-LIST"))

(defun vlisp-project-fas-directory (alist)
  (vlisp-project--get alist ":FAS-DIRECTORY"))

(defun vlisp-project-tmp-directory (alist)
  (vlisp-project--get alist ":TMP-DIRECTORY"))

(defun vlisp-project-keys (alist)
  (vlisp-project--get alist ":PROJECT-KEYS"))

(defun vlisp-project-context-id (alist)
  (vlisp-project--get alist ":CONTEXT-ID"))

;| @Global
  Chemins des sources d'un projet, dans l'ordre de :OWN-LIST. Un élément
  sans extension reçoit ".lsp" ; un élément relatif est préfixé par
  directory (en général le répertoire du fichier .prj).
  @Param alist (A . A) list: projet lu par read-vlisp-project-file
  @Param directory string: répertoire préfixé aux éléments relatifs ; "" pour aucun
  @Returns string list: chemins des sources, séparateurs "/"
|;
(defun vlisp-project-sources (alist directory / entry paths)
  (setq directory (vl-string-right-trim "/" (vl-string-translate "\\" "/" directory)))
  (setq paths nil)
  (foreach entry (vlisp-project-own-list alist)
    (setq entry (vl-string-translate "\\" "/" entry))
    (if (null (vl-filename-extension entry))
      (setq entry (strcat entry ".lsp")))
    (if (or (= directory "")
            (= (substr entry 1 1) "/")
            (= (substr entry 2 1) ":"))
      (setq paths (cons entry paths))
      (setq paths (cons (strcat directory "/" entry) paths))))
  (reverse paths))

(princ)
