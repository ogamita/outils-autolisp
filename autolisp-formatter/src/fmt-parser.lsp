;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; fmt-parser.lsp --- Parseur syntaxique léger (CST) du formateur AutoLISP.
;;;;
;;;; Reconstruit la structure des s-expressions sans les évaluer. Les
;;;; commentaires et les lignes blanches ne sont pas des trivia attachés mais
;;;; des nœuds à part entière, insérés dans la séquence là où ils
;;;; apparaissent : c'est ce qui permet à l'imprimeur de les réémettre à leur
;;;; place sans analyse supplémentaire.
;;;;
;;;; Un nœud est la liste :
;;;;
;;;;     (GENRE CHARGE LIGNE COLONNE LIGNE-FIN EN-LIGNE)
;;;;
;;;; GENRE  ∈ ATOM STR LIST QUOTE LCOMMENT BCOMMENT BLANK
;;;; CHARGE : texte (ATOM STR LCOMMENT BCOMMENT), liste d'enfants (LIST),
;;;;          nœud unique cité (QUOTE), nil (BLANK)

;;; ------------------------------------------------------------------
;;; Accesseurs
;;; ------------------------------------------------------------------

(defun fmt-node-kind     (n) (nth 0 n))
(defun fmt-node-text     (n) (nth 1 n))
(defun fmt-node-children (n) (nth 1 n))
(defun fmt-node-child    (n) (nth 1 n))
(defun fmt-node-line     (n) (nth 2 n))
(defun fmt-node-col      (n) (nth 3 n))
(defun fmt-node-end      (n) (nth 4 n))
(defun fmt-node-inline   (n) (nth 5 n))

(defun fmt-node-comment-p (n)
  (or (eq (fmt-node-kind n) 'LCOMMENT)
      (eq (fmt-node-kind n) 'BCOMMENT)))

(defun fmt-node-blank-p (n)
  (eq (fmt-node-kind n) 'BLANK))

;; Un nœud « de code » : ni commentaire, ni ligne blanche.
(defun fmt-node-code-p (n)
  (not (or (fmt-node-comment-p n) (fmt-node-blank-p n))))

;;; ------------------------------------------------------------------
;;; État du parseur
;;; ------------------------------------------------------------------
;;; Les tokens restants sont conservés dans une variable globale : AutoLISP
;;; n'offre pas de passage par référence, et un index explicite coûterait un
;;; parcours de liste à chaque accès.

(setq *fmt-toks* nil)
(setq *fmt-prev-end* 0)                 ; ligne de fin du token précédent

(defun fmt-peek ()
  (car *fmt-toks*))

(defun fmt-next (/ tk)
  (setq tk (car *fmt-toks*))
  (setq *fmt-toks* (cdr *fmt-toks*))
  (if tk
    (setq *fmt-prev-end* (fmt-tok-endline tk)))
  tk)

;;; ------------------------------------------------------------------
;;; Analyse
;;; ------------------------------------------------------------------

;; Séquence de nœuds. IN-LIST-P : on s'arrête sur une parenthèse fermante
;; sans la consommer (c'est l'appelant qui la consomme).
(defun fmt-parse-sequence (in-list-p / nodes tk node gap)
  (setq nodes nil)
  (while (and (setq tk (fmt-peek))
              (not (eq (fmt-tok-type tk) 'RPAREN)))
    ;; ligne(s) blanche(s) avant ce token ?
    (setq gap (- (fmt-tok-line tk) *fmt-prev-end*))
    (if (and nodes (>= gap 2))
      (setq nodes (cons (list 'BLANK nil (fmt-tok-line tk) 1
                              (fmt-tok-line tk) nil)
                        nodes)))
    (setq node  (fmt-parse-form))
    (setq nodes (cons node nodes)))
  (if (and (null in-list-p) (fmt-peek))
    (fmt-error "parenthèse fermante en trop"
               (fmt-tok-line (fmt-peek))
               (fmt-tok-col (fmt-peek))))
  (reverse nodes))

(defun fmt-parse-form (/ tk children close inner)
  (setq tk (fmt-next))
  (cond

    ((eq (fmt-tok-type tk) 'LPAREN)
     (setq children (fmt-parse-sequence t))
     (setq close    (fmt-peek))
     (if (null close)
       (fmt-error "parenthèse ouvrante non fermée"
                  (fmt-tok-line tk) (fmt-tok-col tk)))
     (fmt-next)
     (list 'LIST children
           (fmt-tok-line tk) (fmt-tok-col tk)
           (fmt-tok-line close) nil))

    ((eq (fmt-tok-type tk) 'QUOTE)
     (if (or (null (fmt-peek))
             (eq (fmt-tok-type (fmt-peek)) 'RPAREN))
       (fmt-error "quote orpheline" (fmt-tok-line tk) (fmt-tok-col tk)))
     (setq inner (fmt-parse-form))
     (list 'QUOTE inner
           (fmt-tok-line tk) (fmt-tok-col tk)
           (fmt-node-end inner) nil))

    ((or (eq (fmt-tok-type tk) 'ATOM)
         (eq (fmt-tok-type tk) 'STR))
     (list (fmt-tok-type tk) (fmt-tok-text tk)
           (fmt-tok-line tk) (fmt-tok-col tk)
           (fmt-tok-endline tk) nil))

    (t                                  ; LCOMMENT / BCOMMENT
     (list (fmt-tok-type tk) (fmt-tok-text tk)
           (fmt-tok-line tk) (fmt-tok-col tk)
           (fmt-tok-endline tk) (fmt-tok-inline tk)))))

;; Point d'entrée : liste de tokens -> liste de nœuds de premier niveau.
(defun fmt-parse (toks / nodes)
  (setq *fmt-toks*     toks)
  (setq *fmt-prev-end* (if toks (fmt-tok-line (car toks)) 1))
  (setq nodes (fmt-parse-sequence nil))
  nodes)

;;; ------------------------------------------------------------------
;;; Diagnostic : nail-clipping à fermetures empilées
;;; ------------------------------------------------------------------

;; Renvoie la liste des numéros de ligne dont le seul contenu est une suite
;; d'au moins deux parenthèses fermantes dont deux au moins sont séparées par
;; des espaces — le style « ) ) ) » que la spécification proscrit.
(defun fmt-stacked-closer-lines (toks / by-line line cur out rparens others
                                       spaced prev)
  ;; regroupement par ligne, dans l'ordre
  (setq by-line nil)
  (foreach tk toks
    (if (and by-line (= (car (car by-line)) (fmt-tok-line tk)))
      (setq by-line (cons (cons (car (car by-line))
                                (cons tk (cdr (car by-line))))
                          (cdr by-line)))
      (setq by-line (cons (list (fmt-tok-line tk) tk) by-line))))
  (setq out nil)
  (foreach cell by-line
    (setq line (car cell))
    (setq cur  (reverse (cdr cell)))
    (setq rparens 0)
    (setq others  0)
    (setq spaced  nil)
    (setq prev    nil)
    (foreach tk cur
      (if (eq (fmt-tok-type tk) 'RPAREN)
        (progn
          (setq rparens (1+ rparens))
          (if (and prev (> (- (fmt-tok-col tk) (fmt-tok-col prev)) 1))
            (setq spaced t))
          (setq prev tk))
        (setq others (1+ others))))
    (if (and (= others 0) (>= rparens 2) spaced)
      (setq out (cons line out))))
  out)

(princ)

;;; fmt-parser.lsp ends here
