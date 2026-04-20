;;; fs.lsp --- Utilitaires « répertoire courant » façon Unix : pwd, cd, ls
;;;
;;; Ces trois fonctions exposent un répertoire courant virtuel, stocké
;;; dans la variable globale *misc-cwd* et initialisé au premier appel
;;; à partir de la variable d'environnement PWD (Unix/macOS) ou CD
;;; (Windows).
;;;
;;; Attention : ce cwd virtuel n'affecte PAS les fonctions qui ouvrent
;;; des fichiers (open, load, cat, etc.). Il sert de repère partagé
;;; uniquement pour pwd, cd et ls.
;;;
;;; Exemples :
;;;   (pwd)
;;;   (cd "docs")
;;;   (ls nil)
;;;   (ls ':l)

(setq pwd 'pwd)
(setq cd  'cd)
(setq ls  'ls)

;;; --- Sortie ---

(defun fs--emit-line (line / result)
  (if (vl-catch-all-error-p
        (setq result (vl-catch-all-apply 'autolisp-emit-user-line (list line))))
    (progn (princ line) (terpri)))
  nil)

;;; --- Gestion du cwd virtuel ---

(defun fs--env-or (name default / v)
  (setq v (getenv name))
  (if (and v (/= v "")) v default))

(defun fs--cwd ()
  (if (null *misc-cwd*)
    (setq *misc-cwd* (fs--env-or "PWD" (fs--env-or "CD" "."))))
  *misc-cwd*)

;;; --- Manipulation de chemins ---

(defun fs--absolute-p (path)
  (cond
    ((= (strlen path) 0) nil)
    ((= (substr path 1 1) "/") T)
    ((and (>= (strlen path) 3)
          (= (substr path 2 1) ":")
          (or (= (substr path 3 1) "/")
              (= (substr path 3 1) "\\")))
      T)
    (T nil)))

(defun fs--split (str sep / parts start i ch)
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

(defun fs--join-with (parts sep / result first)
  (setq result "" first T)
  (foreach p parts
    (if first
      (setq result p first nil)
      (setq result (strcat result sep p))))
  result)

(defun fs--join (base rel)
  (cond
    ((= (strlen base) 0) rel)
    ((= (substr base (strlen base) 1) "/") (strcat base rel))
    (T (strcat base "/" rel))))

(defun fs--normalize (path / parts acc p)
  (setq path (vl-string-translate "\\" "/" path))
  (setq parts (fs--split path "/"))
  (setq acc nil)
  (foreach p parts
    (cond
      ((= p "") nil)
      ((= p ".") nil)
      ((= p "..") (if acc (setq acc (cdr acc))))
      (T (setq acc (cons p acc)))))
  (setq acc (reverse acc))
  (cond
    ((and (> (strlen path) 0) (= (substr path 1 1) "/"))
      (strcat "/" (fs--join-with acc "/")))
    ((and (> (strlen path) 1) (= (substr path 2 1) ":"))
      (if acc
        (strcat (car acc) "/" (fs--join-with (cdr acc) "/"))
        path))
    ((null acc) ".")
    (T (fs--join-with acc "/"))))

(defun fs--resolve (path / cwd)
  (setq cwd (fs--cwd))
  (fs--normalize (if (fs--absolute-p path) path (fs--join cwd path))))

;;; --- Formatage pour ls :l ---

(defun fs--pad-left (s width / r)
  (setq r s)
  (while (< (strlen r) width) (setq r (strcat " " r)))
  r)

(defun fs--pad2 (n / s)
  (setq s (itoa n))
  (if (< n 10) (strcat "0" s) s))

(defun fs--format-stime (stime)
  (if (null stime)
    "-"
    (strcat
      (itoa (nth 0 stime)) "-"
      (fs--pad2 (nth 1 stime)) "-"
      (fs--pad2 (nth 3 stime)) " "
      (fs--pad2 (nth 4 stime)) ":"
      (fs--pad2 (nth 5 stime)))))

;;; --- pwd ---
;;;
;;; Affiche et renvoie le répertoire courant virtuel.
(defun pwd (/ dir)
  (setq dir (fs--cwd))
  (fs--emit-line dir)
  dir)

;;; --- cd ---
;;;
;;; Change le répertoire courant virtuel.
;;; Argument : chaîne (chemin absolu ou relatif au cwd courant).
;;; Retourne le nouveau cwd normalisé en cas de succès, nil sinon.
(defun cd (path / target)
  (cond
    ((/= (type path) 'STR)
      (prompt "\ncd: argument attendu: chaîne")
      nil)
    (T
      (fs--cwd)
      (setq target (fs--resolve path))
      (cond
        ((vl-file-directory-p target)
          (setq *misc-cwd* target)
          target)
        (T
          (prompt (strcat "\ncd: répertoire introuvable: " target))
          nil)))))

;;; --- ls ---
;;;
;;; Liste le contenu du répertoire courant virtuel.
;;; Argument : nil pour un listing court ; ':l ou ':long pour un listing
;;; détaillé (type, taille, date, nom).
;;; NOTE : AutoLISP n'offre pas d'arguments optionnels ; utilisez donc
;;; (ls nil) pour la forme courte.
(defun ls (flag / cwd long entries entry full size stime)
  (setq cwd (fs--cwd))
  (setq long (or (eq flag ':l) (eq flag ':long)))
  (setq entries (vl-directory-files cwd nil 1))
  (cond
    ((null entries)
      (prompt (strcat "\nls: répertoire illisible: " cwd))
      nil)
    (T
      (foreach entry (vl-sort entries '<)
        (if (and (/= entry ".") (/= entry ".."))
          (progn
            (setq full (fs--join cwd entry))
            (if long
              (progn
                (setq size  (vl-file-size full))
                (setq stime (vl-file-systime full))
                (fs--emit-line
                  (strcat
                    (if (vl-file-directory-p full) "d " "- ")
                    (fs--pad-left (if size (itoa size) "-") 10) " "
                    (fs--format-stime stime) " "
                    entry)))
              (fs--emit-line entry)))))
      nil)))
