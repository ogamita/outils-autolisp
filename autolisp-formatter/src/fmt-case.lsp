;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; fmt-case.lsp --- Politique de casse des symboles.
;;;;
;;;; Ordre de priorité imposé par la spécification :
;;;;   1. exceptions de capitalisation fournies par fichier ;
;;;;   2. politique générale (PRESERVE / DOWNCASE / UPCASE) ;
;;;;   3. texte source d'origine.
;;;;
;;;; La transformation ne s'applique qu'aux tokens ATOM non numériques : ni
;;;; les chaînes, ni le texte des commentaires, ni les nombres.

;; Symboles du fichier d'exceptions effectivement rencontrés dans le source
;; (diagnostic « check-case-exceptions »).
(setq *fmt-case-seen* nil)

(defun fmt-case-reset-seen ()
  (setq *fmt-case-seen* nil))

;; Charge le fichier d'exceptions : un symbole par ligne, tel qu'il doit être
;; réécrit. Les lignes blanches sont ignorées ; « ; » en tête permet un
;; commentaire (extension tolérée, sans incidence sur la v1).
;; Renvoie une alist (NOM-MAJUSCULE . TEXTE-EXACT).
(defun fmt-load-case-exceptions (path / f line out trimmed)
  (setq f (open (fmt-resolve-path path) "r"))
  (if (null f)
    (fmt-error (strcat "fichier d'exceptions de casse introuvable : " path)
               nil nil))
  (setq out nil)
  (while (setq line (read-line f))
    (setq trimmed (fmt-trim line))
    (if (and (/= trimmed "")
             (/= (substr trimmed 1 1) ";"))
      (setq out (cons (cons (strcase trimmed) trimmed) out))))
  (close f)
  (reverse out))

(defun fmt-resolve-path (path / full)
  (setq full (findfile path))
  (if full full path))

;; Applique la politique de casse à TEXT (texte d'un ATOM).
;; EXCEPTIONS : alist renvoyée par fmt-load-case-exceptions, ou nil.
(defun fmt-apply-case (text policy exceptions / hit up)
  (cond
    ;; les nombres ne sont jamais transformés
    ((fmt-number-string-p text) text)
    (t
     (setq up  (strcase text))
     (setq hit (assoc up exceptions))
     (cond
       (hit
        (if (not (member up *fmt-case-seen*))
          (setq *fmt-case-seen* (cons up *fmt-case-seen*)))
        (cdr hit))
       ((eq policy 'DOWNCASE) (strcase text t))
       ((eq policy 'UPCASE)   (strcase text))
       (t                     text)))))

;; Entrées du fichier d'exceptions jamais rencontrées dans le source.
(defun fmt-unused-case-exceptions (exceptions / out)
  (setq out nil)
  (foreach cell exceptions
    (if (not (member (car cell) *fmt-case-seen*))
      (setq out (cons (cdr cell) out))))
  (reverse out))

(princ)

;;; fmt-case.lsp ends here
