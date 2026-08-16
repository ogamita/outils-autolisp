;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; fmt-rules.lsp --- Règles d'indentation par tête de forme (style CL).
;;;;
;;;; Une règle est (NOM ARGS-DISTINGUES INDENT-CORPS) :
;;;;
;;;;   ARGS-DISTINGUES : nombre d'arguments qui, s'ils débordent sur une
;;;;                     ligne suivante, s'indentent de INDENT-CORPS × 2 —
;;;;                     l'usage Lisp pour les arguments « de tête »
;;;;                     (nom et liste d'arguments d'un defun, par exemple) ;
;;;;   INDENT-CORPS    : indentation du corps, relative à la parenthèse
;;;;                     ouvrante de la forme.
;;;;
;;;; Les têtes absentes de la table sont indentées « comme un appel de
;;;; fonction » : les arguments s'alignent sous le premier argument. C'est
;;;; le cas voulu pour IF et SETQ, dont la spécification demande un
;;;; traitement dédié : leur règle dédiée est précisément l'alignement
;;;; fonctionnel, documenté ici plutôt qu'implicite.
;;;;
;;;; Le style NAIL n'utilise pas cette table : il indente uniformément de 2.

(defun fmt-indent-rules ()
  (list
    (list "DEFUN"    2 2)
    (list "DEFUN-Q"  2 2)
    (list "LAMBDA"   1 2)
    (list "PROGN"    0 2)
    (list "COND"     0 2)
    (list "WHILE"    1 2)
    (list "REPEAT"   1 2)
    (list "FOREACH"  2 2)
    (list "VLAX-FOR" 2 2)))

;; Têtes explicitement traitées en alignement fonctionnel.
(defun fmt-function-style-heads ()
  (list "IF" "SETQ" "QUOTE" "SETVAR" "COMMAND"))

(defun fmt-indent-rule (head-name)
  (if (member (strcase head-name) (fmt-function-style-heads))
    nil
    (assoc (strcase head-name) (fmt-indent-rules))))

(princ)

;;; fmt-rules.lsp ends here
