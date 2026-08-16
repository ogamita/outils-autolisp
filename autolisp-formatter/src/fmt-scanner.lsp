;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; fmt-scanner.lsp --- Analyseur lexical du formateur AutoLISP.
;;;;
;;;; Transforme un texte source en séquence de tokens. Les espaces sont
;;;; consommés (la mise en page est reconstruite par l'imprimeur), mais les
;;;; positions source sont conservées : elles servent à préserver les
;;;; coupures de ligne voulues par l'auteur.
;;;;
;;;; Un token est la liste :
;;;;
;;;;     (TYPE TEXTE LIGNE COLONNE LIGNE-FIN EN-LIGNE)
;;;;
;;;; TYPE       : LPAREN RPAREN QUOTE STR ATOM LCOMMENT BCOMMENT
;;;; TEXTE      : le texte source exact du token (guillemets et « ;| |; »
;;;;              inclus pour les chaînes et les commentaires bloc)
;;;; LIGNE      : ligne de début, 1 pour la première
;;;; COLONNE    : colonne de début, 1 pour la première
;;;; LIGNE-FIN  : ligne de fin (≠ LIGNE pour une chaîne ou un commentaire
;;;;              bloc multi-lignes)
;;;; EN-LIGNE   : T si un token le précède sur la même ligne — seuls les
;;;;              commentaires exploitent ce drapeau (commentaire de fin de
;;;;              ligne contre commentaire sur ligne dédiée)

;;; ------------------------------------------------------------------
;;; Accesseurs
;;; ------------------------------------------------------------------

(defun fmt-tok-type    (tk) (nth 0 tk))
(defun fmt-tok-text    (tk) (nth 1 tk))
(defun fmt-tok-line    (tk) (nth 2 tk))
(defun fmt-tok-col     (tk) (nth 3 tk))
(defun fmt-tok-endline (tk) (nth 4 tk))
(defun fmt-tok-inline  (tk) (nth 5 tk))

(defun fmt-tok-comment-p (tk)
  (or (eq (fmt-tok-type tk) 'LCOMMENT)
      (eq (fmt-tok-type tk) 'BCOMMENT)))

;;; ------------------------------------------------------------------
;;; Analyse lexicale
;;; ------------------------------------------------------------------

;; Renvoie la liste des tokens de TEXT, dans l'ordre du source.
;; Signale une erreur (fmt-error) sur chaîne ou commentaire bloc non terminé.
(defun fmt-scan (text / codes line col toks acc c start-line start-col
                       has-token done)
  (setq codes      (vl-string->list text))
  (setq line       1)
  (setq col        1)
  (setq toks       nil)
  (setq has-token  nil)

  (while codes
    (setq c (car codes))
    (cond

      ;; --- fin de ligne --------------------------------------------
      ((= c *fmt-ch-newline*)
       (setq codes     (cdr codes))
       (setq line      (1+ line))
       (setq col       1)
       (setq has-token nil))

      ;; --- autres espaces ------------------------------------------
      ((fmt-whitespace-code-p c)
       (setq codes (cdr codes))
       (setq col   (1+ col)))

      ;; --- ponctuation structurelle --------------------------------
      ((or (= c *fmt-ch-lparen*)
           (= c *fmt-ch-rparen*)
           (= c *fmt-ch-quote*))
       (setq toks (cons (list (cond ((= c *fmt-ch-lparen*) 'LPAREN)
                                    ((= c *fmt-ch-rparen*) 'RPAREN)
                                    (t                     'QUOTE))
                              (chr c) line col line has-token)
                        toks))
       (setq codes     (cdr codes))
       (setq col       (1+ col))
       (setq has-token t))

      ;; --- chaîne ---------------------------------------------------
      ((= c *fmt-ch-dquote*)
       (setq start-line line)
       (setq start-col  col)
       (setq acc        (list c))
       (setq codes      (cdr codes))
       (setq col        (1+ col))
       (setq done       nil)
       (while (and codes (not done))
         (setq c (car codes))
         (cond
           ;; échappement : le caractère suivant est pris tel quel
           ((= c *fmt-ch-backslash*)
            (setq acc   (cons c acc))
            (setq codes (cdr codes))
            (setq col   (1+ col))
            (if codes
              (progn
                (setq c (car codes))
                (setq acc (cons c acc))
                (setq codes (cdr codes))
                (if (= c *fmt-ch-newline*)
                  (progn (setq line (1+ line)) (setq col 1))
                  (setq col (1+ col))))))
           ((= c *fmt-ch-dquote*)
            (setq acc   (cons c acc))
            (setq codes (cdr codes))
            (setq col   (1+ col))
            (setq done  t))
           ((= c *fmt-ch-newline*)
            (setq acc   (cons c acc))
            (setq codes (cdr codes))
            (setq line  (1+ line))
            (setq col   1))
           (t
            (setq acc   (cons c acc))
            (setq codes (cdr codes))
            (setq col   (1+ col)))))
       (if (not done)
         (fmt-error "chaîne non terminée" start-line start-col))
       (setq toks (cons (list 'STR (vl-list->string (reverse acc))
                              start-line start-col line has-token)
                        toks))
       (setq has-token t))

      ;; --- commentaires ---------------------------------------------
      ((= c *fmt-ch-semi*)
       (setq start-line line)
       (setq start-col  col)
       (if (and (cdr codes)
                (= (cadr codes) *fmt-ch-bar*))
         ;; commentaire bloc  ;| ... |;
         (progn
           (setq acc   (list *fmt-ch-bar* c))
           (setq codes (cddr codes))
           (setq col   (+ col 2))
           (setq done  nil)
           (while (and codes (not done))
             (setq c (car codes))
             (cond
               ((and (= c *fmt-ch-bar*)
                     (cdr codes)
                     (= (cadr codes) *fmt-ch-semi*))
                (setq acc   (cons *fmt-ch-semi* (cons c acc)))
                (setq codes (cddr codes))
                (setq col   (+ col 2))
                (setq done  t))
               ((= c *fmt-ch-newline*)
                (setq acc   (cons c acc))
                (setq codes (cdr codes))
                (setq line  (1+ line))
                (setq col   1))
               (t
                (setq acc   (cons c acc))
                (setq codes (cdr codes))
                (setq col   (1+ col)))))
           (if (not done)
             (fmt-error "commentaire bloc non terminé" start-line start-col))
           (setq toks (cons (list 'BCOMMENT (vl-list->string (reverse acc))
                                  start-line start-col line has-token)
                            toks)))
         ;; commentaire de ligne
         (progn
           (setq acc nil)
           (while (and codes
                       (/= (car codes) *fmt-ch-newline*))
             (setq acc   (cons (car codes) acc))
             (setq codes (cdr codes))
             (setq col   (1+ col)))
           (setq toks (cons (list 'LCOMMENT
                                  (fmt-trim-right
                                    (vl-list->string (reverse acc)))
                                  start-line start-col start-line has-token)
                            toks))))
       (setq has-token t))

      ;; --- atome ----------------------------------------------------
      (t
       (setq start-line line)
       (setq start-col  col)
       (setq acc        nil)
       (while (and codes
                   (not (fmt-delimiter-code-p (car codes))))
         (setq acc   (cons (car codes) acc))
         (setq codes (cdr codes))
         (setq col   (1+ col)))
       (setq toks (cons (list 'ATOM (vl-list->string (reverse acc))
                              start-line start-col start-line has-token)
                        toks))
       (setq has-token t))))

  (reverse toks))

(princ)

;;; fmt-scanner.lsp ends here
