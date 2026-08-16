;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; fmt-printer.lsp --- Réémission textuelle déterministe du CST.
;;;;
;;;; Principe directeur : le formateur *ne reflue pas* le code. Les coupures
;;;; de ligne voulues par l'auteur sont conservées ; ce qui est recalculé,
;;;; c'est l'indentation, le placement des parenthèses fermantes, la casse
;;;; des symboles, la présentation des commentaires et les lignes blanches.
;;;;
;;;; C'est ce choix qui rend le formateur idempotent sans avoir à décider
;;;; d'une largeur de ligne : une forme tenant sur une ligne du source y
;;;; reste, une forme éclatée reste éclatée aux mêmes endroits.

;;; ------------------------------------------------------------------
;;; Tampon de sortie
;;; ------------------------------------------------------------------

(setq *fmt-out-lines* nil)              ; lignes terminées, en ordre inverse
(setq *fmt-cur*       "")               ; ligne en cours

(defun fmt-out-reset ()
  (setq *fmt-out-lines* nil)
  (setq *fmt-cur*       ""))

(defun fmt-out-emit (s)
  (setq *fmt-cur* (strcat *fmt-cur* s)))

(defun fmt-out-column ()
  (strlen *fmt-cur*))

(defun fmt-out-blank-p ()
  (fmt-blank-string-p *fmt-cur*))

(defun fmt-out-break ()
  (setq *fmt-out-lines* (cons (fmt-trim-right *fmt-cur*) *fmt-out-lines*))
  (setq *fmt-cur* ""))

;; Se placer en début de ligne, indenté de INDENT.
(defun fmt-out-fresh (indent)
  (if (not (fmt-out-blank-p))
    (fmt-out-break))
  (setq *fmt-cur* (fmt-spaces indent)))

;; Ligne blanche, sans jamais en produire deux de suite ni en tête de sortie.
(defun fmt-out-blank-line ()
  (if (not (fmt-out-blank-p))
    (fmt-out-break))
  (setq *fmt-cur* "")
  (if (and *fmt-out-lines*
           (/= (car *fmt-out-lines*) ""))
    (setq *fmt-out-lines* (cons "" *fmt-out-lines*))))

;; Texte final : lignes jointes par \n, sans lignes blanches en tête ni en
;; queue, terminé par exactement un \n.
(defun fmt-out-result (/ lines)
  (if (not (fmt-out-blank-p))
    (fmt-out-break))
  (setq lines *fmt-out-lines*)
  (while (and lines (= (car lines) ""))          ; queue
    (setq lines (cdr lines)))
  (setq lines (reverse lines))
  (while (and lines (= (car lines) ""))          ; tête
    (setq lines (cdr lines)))
  (if (null lines)
    ""
    (strcat (fmt-string-join lines "\n") "\n")))

;;; ------------------------------------------------------------------
;;; Options actives
;;; ------------------------------------------------------------------
;;; Recopiées dans des globales le temps d'une impression : AutoLISP n'a pas
;;; de fermetures lexicales, et passer sept paramètres à chaque fonction
;;; récursive nuirait plus à la lisibilité que ces variables explicites.

(setq *fmt-o-style*      'CL)
(setq *fmt-o-case*       'PRESERVE)
(setq *fmt-o-comment*    'PRESERVE)
(setq *fmt-o-block*      'PRESERVE)
(setq *fmt-o-ctx*        nil)
(setq *fmt-o-col*        nil)
(setq *fmt-o-exceptions* nil)

(defun fmt-printer-setup (opts exceptions)
  (setq *fmt-o-style*      (fmt-option opts "paren-style"))
  (setq *fmt-o-case*       (fmt-option opts "symbol-case"))
  (setq *fmt-o-comment*    (fmt-option opts "comment-style"))
  (setq *fmt-o-block*      (fmt-option opts "block-comments"))
  (setq *fmt-o-ctx*        (fmt-option opts "contextual-comments"))
  (setq *fmt-o-col*        (fmt-option opts "inline-comment-column"))
  (setq *fmt-o-exceptions* exceptions))

;;; ------------------------------------------------------------------
;;; Géométrie source
;;; ------------------------------------------------------------------

;; Dernière ligne source *du contenu* d'un nœud — la ligne de sa parenthèse
;; fermante est délibérément ignorée : en style nail elle est seule sur sa
;; ligne, et la prendre en compte empêcherait la conversion nail -> cl de
;; reconnaître une forme qui tenait sur une seule ligne.
(defun fmt-content-end (node / kind kids m)
  (setq kind (fmt-node-kind node))
  (cond
    ((eq kind 'LIST)
     (setq kids (fmt-node-children node))
     (if (null kids)
       (fmt-node-line node)
       (progn
         (setq m (fmt-node-line node))
         (foreach k kids
           (setq m (max m (fmt-content-end k))))
         m)))
    ((eq kind 'QUOTE) (fmt-content-end (fmt-node-child node)))
    (t                (fmt-node-end node))))

(defun fmt-has-trivia-p (nodes / out)
  (setq out nil)
  (foreach n nodes
    (if (or (fmt-node-comment-p n) (fmt-node-blank-p n))
      (setq out t)))
  out)

;; La forme tenait-elle sur une seule ligne source ? Un commentaire interne
;; force le multi-ligne (il mangerait le reste de la ligne).
(defun fmt-list-inline-p (node)
  (and (not (fmt-has-trivia-p (fmt-node-children node)))
       (= (fmt-content-end node) (fmt-node-line node))))

;; Le nœud sera-t-il émis sur plusieurs lignes ?
(defun fmt-node-multiline-p (node / kind)
  (setq kind (fmt-node-kind node))
  (cond
    ((eq kind 'LIST)  (and (fmt-node-children node)
                           (not (fmt-list-inline-p node))))
    ((eq kind 'QUOTE) (fmt-node-multiline-p (fmt-node-child node)))
    (t                nil)))

;;; ------------------------------------------------------------------
;;; Commentaires
;;; ------------------------------------------------------------------

;; Préfixe cible selon le contexte, en mode comment-style CL.
;; CONTEXTE ∈ BANNER (avant toute forme) TOP INNER INLINE
(defun fmt-comment-prefix (context)
  (cond
    ((eq context 'INLINE) ";")
    ((not *fmt-o-ctx*)    ";;")
    ((eq context 'BANNER) ";;;;")
    ((eq context 'TOP)    ";;;")
    (t                    ";;")))

;; Corps d'un commentaire de ligne : texte sans les « ; » de tête.
(defun fmt-comment-body (text / codes)
  (setq codes (vl-string->list text))
  (while (and codes (= (car codes) *fmt-ch-semi*))
    (setq codes (cdr codes)))
  (vl-list->string codes))

(defun fmt-line-comment-text (node context / body)
  (if (eq *fmt-o-comment* 'PRESERVE)
    (fmt-node-text node)
    (progn
      (setq body (fmt-comment-body (fmt-node-text node)))
      (cond
        ((= (fmt-trim body) "") (fmt-comment-prefix context))
        ((= (substr body 1 1) " ")
         (strcat (fmt-comment-prefix context) body))
        (t
         (strcat (fmt-comment-prefix context) " " body))))))

;; Lignes internes d'un commentaire bloc, « ;| » et « |; » retirés.
(defun fmt-block-comment-lines (text / body lines out)
  (setq body text)
  (if (= (substr body 1 2) ";|")
    (setq body (substr body 3)))
  (if (and (>= (strlen body) 2)
           (= (substr body (- (strlen body) 1) 2) "|;"))
    (setq body (substr body 1 (- (strlen body) 2))))
  (setq lines (mapcar (function fmt-trim-right) (fmt-split-lines body)))
  ;; lignes blanches de tête et de queue retirées
  (while (and lines (fmt-blank-string-p (car lines)))
    (setq lines (cdr lines)))
  (setq lines (reverse lines))
  (while (and lines (fmt-blank-string-p (car lines)))
    (setq lines (cdr lines)))
  (setq out (reverse lines))
  out)

;; Écrit un commentaire (ligne ou bloc) sur sa propre ligne, à INDENT.
(defun fmt-print-comment (node context indent / lines first)
  (if (eq (fmt-node-kind node) 'LCOMMENT)
    (fmt-out-emit (fmt-line-comment-text node context))
    (if (eq *fmt-o-block* 'PRESERVE)
      ;; conservé tel quel : la première ligne à l'indentation courante, les
      ;; suivantes verbatim (leur mise en page interne peut être signifiante)
      (progn
        (setq lines (fmt-split-lines (fmt-node-text node)))
        (setq first t)
        (foreach l lines
          (if first
            (progn (fmt-out-emit (fmt-trim-right l)) (setq first nil))
            (progn (fmt-out-break)
                   (setq *fmt-cur* (fmt-trim-right l))))))
      ;; converti en commentaires « ; »
      (progn
        (setq lines (fmt-block-comment-lines (fmt-node-text node)))
        (setq first t)
        (foreach l lines
          (if first
            (setq first nil)
            (fmt-out-fresh indent))
          (fmt-out-emit
            (if (fmt-blank-string-p l)
              (fmt-comment-prefix context)
              (strcat (fmt-comment-prefix context) " " (fmt-trim l)))))))))

;; Commentaire de fin de ligne, aligné si l'option le demande.
(defun fmt-print-inline-comment (node)
  (if (and *fmt-o-col*
           (> *fmt-o-col* (fmt-out-column)))
    (fmt-out-emit (fmt-spaces (- *fmt-o-col* (fmt-out-column))))
    (fmt-out-emit " "))
  (if (eq (fmt-node-kind node) 'LCOMMENT)
    (fmt-out-emit (fmt-line-comment-text node 'INLINE))
    (fmt-print-comment node 'INLINE (fmt-out-column))))

;;; ------------------------------------------------------------------
;;; Indentation
;;; ------------------------------------------------------------------

;; Indentation d'un enfant de rang IDX (l'en-tête est le rang 0).
;; BASE : colonne de la parenthèse ouvrante ; ARG-COL : colonne effective du
;; premier argument s'il a été émis sur la ligne d'en-tête, sinon nil.
(defun fmt-child-indent (base rule idx arg-col)
  (cond
    ((not (eq *fmt-o-style* 'CL)) (+ base 2))
    (rule (if (<= idx (nth 1 rule))
            (+ base (* 2 (nth 2 rule)))  ; arguments distingués
            (+ base (nth 2 rule))))      ; corps
    (arg-col arg-col)                    ; alignement fonctionnel
    (t (+ base 1))))

;;; ------------------------------------------------------------------
;;; Impression des nœuds
;;; ------------------------------------------------------------------

(defun fmt-print-node (node / kind)
  (setq kind (fmt-node-kind node))
  (cond
    ((eq kind 'ATOM)
     (fmt-out-emit (fmt-apply-case (fmt-node-text node)
                                   *fmt-o-case*
                                   *fmt-o-exceptions*)))
    ((eq kind 'STR)
     (fmt-out-emit (fmt-node-text node)))
    ((eq kind 'QUOTE)
     (fmt-out-emit "'")
     (fmt-print-node (fmt-node-child node)))
    ((eq kind 'LIST)
     (fmt-print-list node))
    ((fmt-node-comment-p node)
     (fmt-print-comment node 'INNER (fmt-out-column)))
    (t nil)))

;; La ligne courante ne contient-elle que des parenthèses fermantes ?
;; (mode stacked-nail : c'est la condition d'empilement)
(defun fmt-closers-only-p (/ codes only)
  (setq codes (vl-string->list (fmt-trim *fmt-cur*)))
  (setq only (if codes t nil))
  (foreach c codes
    (if (and (/= c *fmt-ch-rparen*)
             (/= c *fmt-ch-space*))
      (setq only nil)))
  only)

(defun fmt-print-closer (base)
  (cond
    ((eq *fmt-o-style* 'CL)
     (fmt-out-emit ")"))
    ((eq *fmt-o-style* 'STACKED-NAIL)
     (if (fmt-closers-only-p)
       (fmt-out-emit " )")
       (progn (fmt-out-fresh base) (fmt-out-emit ")"))))
    (t                                  ; NAIL
     (fmt-out-fresh base)
     (fmt-out-emit ")"))))

(defun fmt-print-list (node / base kids head head-name rule idx arg-col
                             prev kid rest indent)
  (setq base (fmt-out-column))
  (setq kids (fmt-node-children node))

  (cond
    ((null kids)
     (fmt-out-emit "()"))

    ((fmt-list-inline-p node)
     (fmt-out-emit "(")
     (setq idx 0)
     (foreach kid kids
       (if (> idx 0) (fmt-out-emit " "))
       (fmt-print-node kid)
       (setq idx (1+ idx)))
     (fmt-out-emit ")"))

    (t
     (fmt-out-emit "(")
     (setq head      (car kids))
     (setq head-name (if (eq (fmt-node-kind head) 'ATOM)
                       (fmt-node-text head)
                       nil))
     (setq rule    (if head-name (fmt-indent-rule head-name) nil))
     (setq arg-col nil)
     (setq idx     0)
     (setq prev    nil)

     (setq rest kids)
     (while rest
       (setq kid  (car rest))
       (setq rest (cdr rest))
       (cond

         ;; ligne blanche interne
         ((fmt-node-blank-p kid)
          (fmt-out-blank-line))

         ;; commentaire de fin de ligne
         ((and (fmt-node-comment-p kid)
               (fmt-node-inline kid)
               (not (fmt-out-blank-p)))
          (fmt-print-inline-comment kid))

         ;; commentaire sur ligne dédiée
         ((fmt-node-comment-p kid)
          (fmt-out-fresh (fmt-child-indent base rule (max idx 1) arg-col))
          (fmt-print-comment kid 'INNER
                             (fmt-child-indent base rule (max idx 1) arg-col)))

         ;; en-tête
         ((= idx 0)
          (fmt-print-node kid)
          (setq prev kid)
          (setq idx  1))

         ;; argument
         (t
          (setq indent (fmt-child-indent base rule idx arg-col))
          ;; Nouvelle ligne si le source en imposait une — ou, dans les
          ;; styles qui isolent les fermantes, si l'argument précédent vient
          ;; de se terminer par une fermante seule sur sa ligne : y accoler
          ;; un argument produirait « ) 'FOO », que la passe suivante
          ;; relirait comme une coupure de ligne, donc une sortie instable.
          (if (and prev
                   (or (> (fmt-node-line kid) (fmt-content-end prev))
                       (and (not (eq *fmt-o-style* 'CL))
                            (fmt-node-multiline-p prev))))
            (fmt-out-fresh indent)
            (if (not (fmt-out-blank-p))
              (fmt-out-emit " ")))
          (if (and (= idx 1) (not (fmt-out-blank-p)))
            (setq arg-col (fmt-out-column)))
          (fmt-print-node kid)
          (setq prev kid)
          (setq idx  (1+ idx)))))

     (fmt-print-closer base))))

;;; ------------------------------------------------------------------
;;; Niveau supérieur
;;; ------------------------------------------------------------------

(defun fmt-print-top (nodes / seen-code)
  (setq seen-code nil)
  (foreach n nodes
    (cond
      ((fmt-node-blank-p n)
       (fmt-out-blank-line))
      ((and (fmt-node-comment-p n)
            (fmt-node-inline n)
            (not (fmt-out-blank-p)))
       (fmt-print-inline-comment n))
      ((fmt-node-comment-p n)
       (fmt-out-fresh 0)
       (fmt-print-comment n (if seen-code 'TOP 'BANNER) 0))
      (t
       (fmt-out-fresh 0)
       (fmt-print-node n)
       (setq seen-code t))))
  (fmt-out-result))

;; Point d'entrée : nœuds + options -> texte formaté.
(defun fmt-print (nodes opts exceptions)
  (fmt-printer-setup opts exceptions)
  (fmt-out-reset)
  (fmt-print-top nodes))

(princ)

;;; fmt-printer.lsp ends here
