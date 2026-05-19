;;; cat.lsp --- Affichage du contenu d'un ou plusieurs fichiers

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
(setq cat 'cat)
(defun cat--emit-line (line / result)
  (if (vl-catch-all-error-p
       (vl-catch-all-apply
        (function (lambda ()
          (setq result (vl-catch-all-apply 'autolisp-emit-user-line (list line)))))))
    (progn
      (princ line)
      (terpri)))
  nil)

(defun cat (arg / paths path handle line)
  (cond
    ((= (type arg) 'STR)
      (setq paths (list arg)))
    ((= (type arg) 'LIST)
      (setq paths arg))
    (T
      (prompt "\ncat: argument attendu: chaîne ou liste de chaînes")
      (setq paths nil)))
  (foreach path paths
    (if (= (type path) 'STR)
      (progn
        (setq handle (open path "r"))
        (if handle
          (progn
            (setq line (read-line handle))
            (while line
              (cat--emit-line line)
              (setq line (read-line handle)))
            (close handle))
          (prompt (strcat "\ncat: impossible d'ouvrir " path))))
      (prompt "\ncat: chaque élément de la liste doit être une chaîne")))
  nil
)
