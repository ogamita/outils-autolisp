;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; fmt-io.lsp --- Entrées/sorties fichier du formateur AutoLISP.

;; Lit PATH et renvoie son contenu, lignes jointes par \n.
;; La fin de ligne d'origine (LF ou CRLF) n'est pas conservée : le formateur
;; réémet le fichier avec les fins de ligne de la plate-forme d'écriture.
(defun fmt-read-file (path / f line lines full)
  (setq full (findfile path))
  (if (null full)
    (fmt-error (strcat "fichier introuvable : " path) nil nil))
  (setq f (open full "r"))
  (if (null f)
    (fmt-error (strcat "lecture impossible : " path) nil nil))
  (setq lines nil)
  (while (setq line (read-line f))
    (setq lines (cons line lines)))
  (close f)
  (fmt-string-join (reverse lines) "\n"))

;; Écrit TEXT dans PATH. TEXT est une chaîne dont les lignes sont séparées
;; par \n ; write-line ajoute la fin de ligne native.
(defun fmt-write-file (path text / f lines)
  (setq f (open path "w"))
  (if (null f)
    (fmt-error (strcat "écriture impossible : " path) nil nil))
  (setq lines (fmt-split-lines text))
  ;; une chaîne terminée par \n produit une dernière ligne vide : on ne la
  ;; réémet pas, write-line ayant déjà terminé la ligne précédente
  (if (and lines (= (car (reverse lines)) ""))
    (setq lines (reverse (cdr (reverse lines)))))
  (foreach line lines
    (write-line line f))
  (close f)
  t)

(defun fmt-file-exists-p (path)
  (if (findfile path) t nil))

(princ)

;;; fmt-io.lsp ends here
