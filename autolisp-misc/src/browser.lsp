;;; browser.lsp --- Navigation et inspection façon shell sur le cwd réel du processus
;;;
;;; Contrairement à fs.lsp qui maintient un répertoire courant virtuel
;;; dans *misc-cwd*, ce module agit sur le cwd réel du processus
;;; AutoCAD / BricsCAD via l'objet COM WScript.Shell. Les fonctions de
;;; lecture qui résolvent leurs chemins via l'OS -- (findfile "."),
;;; (open ...), (load ...), (vl-directory-files ".") -- voient donc le
;;; changement.
;;;
;;; API publique :
;;;   (pwd)                  affiche et renvoie le répertoire courant
;;;   (cd path)              change de répertoire
;;;   (pushd path)           empile le cwd courant puis change
;;;   (popd)                 dépile et restaure le cwd
;;;   (ls)                   liste courte du répertoire courant
;;;   (ls ':l)               liste détaillée (type, taille, date, nom)
;;;   (cat path)             affiche un fichier
;;;   (cat '(p1 p2 ...))     affiche plusieurs fichiers dans l'ordre
;;;   (truename path)        résout un chemin contre (pwd) si relatif
;;;   (path path)            alias de (truename path)
;;;   (user-home-directory)  répertoire personnel de l'utilisateur
;;;   (home)                 alias de (user-home-directory)
;;;
;;; Remarques :
;;; - Charger ce fichier APRÈS fs.lsp redéfinit pwd / cd / ls pour
;;;   qu'ils opèrent sur le cwd réel ; charger fs.lsp après ce fichier
;;;   les ramène sur le cwd virtuel. Choisir un seul des deux modèles
;;;   par session pour éviter la confusion.
;;; - Le changement de cwd vaut pour la session CAO en cours. Au
;;;   prochain démarrage, le cwd revient à celui du raccourci AutoCAD
;;;   / BricsCAD (champ « Démarrer dans »).

(setq pwd                 'pwd)
(setq cd                  'cd)
(setq pushd               'pushd)
(setq popd                'popd)
(setq ls                  'ls)
(setq cat                 'cat)
(setq truename            'truename)
(setq path                'path)
(setq user-home-directory 'user-home-directory)
(setq home                'home)

;;; --- Sortie ---

(defun browser--emit-line (line / result)
  (if (vl-catch-all-error-p
       (vl-catch-all-apply
        (function (lambda ()
          (setq result (vl-catch-all-apply 'autolisp-emit-user-line (list line)))))
        '()))
      (progn (princ line) (terpri)))
  nil)

;;; --- Accès au cwd réel via WScript.Shell ---
;;;
;;; L'objet COM est mis en cache dans *browser-shell* pour éviter
;;; le coût d'un vlax-create-object à chaque appel.

(defun browser--shell ()
  (if (null *browser-shell*)
    (setq *browser-shell* (vlax-create-object "WScript.Shell")))
  *browser-shell*)

(defun browser--get-cwd ()
  (vlax-get-property (browser--shell) 'CurrentDirectory))

(defun browser--set-cwd (path)
  (vlax-put-property (browser--shell) 'CurrentDirectory path)
  (browser--get-cwd))

;;; --- Manipulation de chemins ---

(defun browser--join (base rel)
  (cond
    ((= (strlen base) 0) rel)
    ((= (substr base (strlen base) 1) "/")  (strcat base rel))
    ((= (substr base (strlen base) 1) "\\") (strcat base rel))
    (T (strcat base "/" rel))))

(defun browser--absolute-p (p)
  (cond
    ((= (strlen p) 0) nil)
    ((= (substr p 1 1) "/")  T)
    ((= (substr p 1 1) "\\") T)
    ((and (>= (strlen p) 3)
          (= (substr p 2 1) ":")
          (or (= (substr p 3 1) "/")
              (= (substr p 3 1) "\\")))
      T)
    (T nil)))

(defun browser--split (str sep / parts start i ch)
  (setq parts nil start 1 i 1)
  (while (<= i (strlen str))
    (setq ch (substr str i 1))
    (if (= ch sep)
      (progn
        (setq parts (cons (substr str start (- i start)) parts))
        (setq start (1+ i))))
    (setq i (1+ i)))
  (setq parts (cons (substr str start (- (1+ (strlen str)) start)) parts))
  (reverse parts))

(defun browser--join-with (parts sep / result first)
  (setq result "" first T)
  (foreach p parts
    (if first
      (setq result p first nil)
      (setq result (strcat result sep p))))
  result)

;;; Normalise un chemin : antislashs -> slashes ; segments . et ..
;;; supprimés / remontés ; séparateurs vides écrasés.
(defun browser--normalize (p / parts acc q)
  (setq p (vl-string-translate "\\" "/" p))
  (setq parts (browser--split p "/"))
  (setq acc nil)
  (foreach q parts
    (cond
      ((= q "") nil)
      ((= q ".") nil)
      ((= q "..") (if acc (setq acc (cdr acc))))
      (T (setq acc (cons q acc)))))
  (setq acc (reverse acc))
  (cond
    ((and (> (strlen p) 0) (= (substr p 1 1) "/"))
      (strcat "/" (browser--join-with acc "/")))
    ((and (> (strlen p) 1) (= (substr p 2 1) ":"))
      (if acc
        (strcat (car acc) "/" (browser--join-with (cdr acc) "/"))
        p))
    ((null acc) ".")
    (T (browser--join-with acc "/"))))

(defun browser--pad-left (s width / r)
  (setq r s)
  (while (< (strlen r) width) (setq r (strcat " " r)))
  r)

(defun browser--pad2 (n / s)
  (setq s (itoa n))
  (if (< n 10) (strcat "0" s) s))

(defun browser--format-stime (stime)
  (if (null stime)
    "-"
    (strcat
      (itoa (nth 0 stime)) "-"
      (browser--pad2 (nth 1 stime)) "-"
      (browser--pad2 (nth 3 stime)) " "
      (browser--pad2 (nth 4 stime)) ":"
      (browser--pad2 (nth 5 stime)))))

;;; --- pwd ---
;;;
;;; Affiche et renvoie le répertoire courant réel du processus CAO.
(defun pwd (/ dir)
  (setq dir (browser--get-cwd))
  (browser--emit-line dir)
  dir)

;;; --- cd ---
;;;
;;; Change le répertoire courant réel.
;;; Argument : chemin absolu ou relatif au cwd courant.
;;; Retourne le nouveau cwd en cas de succès, nil sinon.
(defun cd (path)
  (cond
    ((/= (type path) 'STR)
      (prompt "\ncd : argument attendu : chaîne")
      nil)
    ((not (vl-file-directory-p path))
      (prompt (strcat "\ncd : répertoire introuvable : " path))
      nil)
    (T
      (browser--set-cwd path))))

;;; --- pushd / popd ---
;;;
;;; Pile de répertoires partagée entre les deux fonctions, stockée
;;; dans *browser-stack*.

(defun pushd (path / old new)
  (setq old (browser--get-cwd))
  (setq new (cd path))
  (cond
    (new
      (setq *browser-stack* (cons old *browser-stack*))
      new)
    (T nil)))

(defun popd (/ target)
  (cond
    ((null *browser-stack*)
      (prompt "\npopd : pile vide")
      nil)
    (T
      (setq target (car *browser-stack*))
      (setq *browser-stack* (cdr *browser-stack*))
      (browser--set-cwd target))))

;;; --- ls ---
;;;
;;; Liste le contenu du répertoire courant réel.
;;; Argument : nil pour un listing court ; ':l ou ':long pour un
;;; listing détaillé (type, taille, date, nom).
;;; AutoLISP n'a pas d'arguments optionnels ; passer explicitement nil
;;; pour la forme courte.
(defun ls (flag / cwd long entries entry full is-dir size stime)
  (setq cwd (browser--get-cwd))
  (setq long (or (eq flag ':l) (eq flag ':long)))
  (setq entries (vl-directory-files cwd nil 0))
  (cond
    ((null entries)
      (prompt (strcat "\nls : répertoire illisible ou vide : " cwd))
      nil)
    (T
      (foreach entry (vl-sort entries '<)
        (if (and (/= entry ".") (/= entry ".."))
          (progn
            (setq full   (browser--join cwd entry))
            (setq is-dir (vl-file-directory-p full))
            (if long
              (progn
                (setq size  (vl-file-size full))
                (setq stime (vl-file-systime full))
                (browser--emit-line
                  (strcat
                    (if is-dir "d " "- ")
                    (browser--pad-left (if size (itoa size) "-") 10) " "
                    (browser--format-stime stime) " "
                    entry
                    (if is-dir "/" ""))))
              (browser--emit-line
                (if is-dir (strcat entry "/") entry))))))
      nil)))

;;; --- cat ---
;;;
;;; Affiche le contenu d'un ou plusieurs fichiers texte.
;;; Argument :
;;; - une chaîne, pour un seul fichier ;
;;; - une liste de chaînes, pour plusieurs fichiers dans l'ordre.
(defun browser--cat-one (path / handle line)
  (setq handle (open path "r"))
  (cond
    (handle
      (setq line (read-line handle))
      (while line
        (browser--emit-line line)
        (setq line (read-line handle)))
      (close handle))
    (T
      (prompt (strcat "\ncat : impossible d'ouvrir " path))))
  nil)

(defun cat (arg / paths path)
  (cond
    ((= (type arg) 'STR)  (setq paths (list arg)))
    ((= (type arg) 'LIST) (setq paths arg))
    (T
      (prompt "\ncat : argument attendu : chaîne ou liste de chaînes")
      (setq paths nil)))
  (foreach path paths
    (if (= (type path) 'STR)
      (browser--cat-one path)
      (prompt "\ncat : chaque élément de la liste doit être une chaîne")))
  nil)

;;; --- truename / path ---
;;;
;;; Résout un chemin contre le cwd réel : un chemin relatif est
;;; préfixé par (pwd), un chemin absolu est renvoyé tel quel. Dans
;;; les deux cas le résultat est normalisé (antislashs convertis en
;;; slashes, segments . et .. réduits).
;;;
;;; Usage typique pour faire suivre load au cwd :
;;;
;;;   (cd "C:/a/b/c/")
;;;   (load (path "foo.lsp"))   ; charge C:/a/b/c/foo.lsp
;;;
;;; path est un alias de truename.
(defun truename (p)
  (cond
    ((/= (type p) 'STR)
      (prompt "\ntruename : argument attendu : chaîne")
      nil)
    (T
      (browser--normalize
        (if (browser--absolute-p p)
          p
          (browser--join (browser--get-cwd) p))))))

(defun path (p) (truename p))

;;; --- user-home-directory / home ---
;;;
;;; Renvoie le répertoire personnel de l'utilisateur.
;;; Sur Windows : USERPROFILE. Repli sur HOME (Unix / macOS) si défini.
(defun user-home-directory (/ h)
  (cond
    ((and (setq h (getenv "USERPROFILE")) (/= h "")) h)
    ((and (setq h (getenv "HOME"))        (/= h "")) h)
    (T nil)))

(defun home () (user-home-directory))
