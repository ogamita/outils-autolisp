;;; cat.lsp --- Affichage du contenu d'un ou plusieurs fichiers

(defun cat--print-file (path / handle line)
  (setq handle (open path "r"))
  (if handle
    (progn
      (setq line (read-line handle))
      (while line
        (princ line)
        (terpri)
        (setq line (read-line handle))
      )
      (close handle)
    )
    (prompt (strcat "\ncat: impossible d'ouvrir " path))
  )
)

(defun cat--normalize-paths (arg /)
  (cond
    ((= (type arg) 'STR)
      (list arg))
    ((= (type arg) 'LIST)
      arg)
    (T
      (prompt "\ncat: argument attendu: chaîne ou liste de chaînes")
      nil)
  )
)

;;; cat
;;;
;;; Affiche le contenu d'un ou plusieurs fichiers texte.
;;;
;;; Argument :
;;; - une chaîne, pour afficher un seul fichier ;
;;; - une liste de chaînes, pour afficher plusieurs fichiers dans l'ordre.
;;;
;;; Exemples :
;;;   (cat "abc.txt")
;;;   (cat '("abc.txt" "def.txt" "ghi.txt"))
;;;
;;; La fonction retourne silencieusement nil après l'affichage.
(defun cat (arg / paths)
  (setq paths (cat--normalize-paths arg))
  (foreach path paths
    (if (= (type path) 'STR)
      (cat--print-file path)
      (prompt "\ncat: chaque élément de la liste doit être une chaîne")
    )
  )
  (princ)
)
