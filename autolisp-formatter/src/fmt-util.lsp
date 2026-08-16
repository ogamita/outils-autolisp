;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; fmt-util.lsp --- Utilitaires du formateur AutoLISP.
;;;;
;;;; Fonctions de base sur les chaînes, les listes et les caractères,
;;;; utilisées par tous les autres modules. Aucune dépendance.

;;; ------------------------------------------------------------------
;;; Codes de caractères
;;; ------------------------------------------------------------------

(setq *fmt-ch-tab*      9)
(setq *fmt-ch-newline*  10)
(setq *fmt-ch-return*   13)
(setq *fmt-ch-space*    32)
(setq *fmt-ch-dquote*   34)
(setq *fmt-ch-quote*    39)
(setq *fmt-ch-lparen*   40)
(setq *fmt-ch-rparen*   41)
(setq *fmt-ch-semi*     59)
(setq *fmt-ch-backslash* 92)
(setq *fmt-ch-bar*      124)

(defun fmt-whitespace-code-p (c)
  (or (= c *fmt-ch-space*)
      (= c *fmt-ch-tab*)
      (= c *fmt-ch-newline*)
      (= c *fmt-ch-return*)))

;; Caractères qui terminent un atome.
(defun fmt-delimiter-code-p (c)
  (or (fmt-whitespace-code-p c)
      (= c *fmt-ch-lparen*)
      (= c *fmt-ch-rparen*)
      (= c *fmt-ch-quote*)
      (= c *fmt-ch-dquote*)
      (= c *fmt-ch-semi*)))

;;; ------------------------------------------------------------------
;;; Chaînes
;;; ------------------------------------------------------------------

(defun fmt-spaces (n / out)
  (setq out "")
  (repeat (max 0 n)
    (setq out (strcat out " ")))
  out)

(defun fmt-string-join (items sep / out first)
  (setq out   "")
  (setq first t)
  (foreach s items
    (if first
      (setq out   s
            first nil)
      (setq out (strcat out sep s))))
  out)

;; Découpe TEXT sur les fins de ligne ; \r\n et \n sont acceptés.
;; Renvoie une liste de chaînes sans les fins de ligne.
(defun fmt-split-lines (text / out cur codes c)
  (setq out   nil)
  (setq cur   nil)
  (setq codes (vl-string->list text))
  (while codes
    (setq c     (car codes))
    (setq codes (cdr codes))
    (cond
      ((= c *fmt-ch-newline*)
       (setq out (cons (vl-list->string (reverse cur)) out))
       (setq cur nil))
      ((= c *fmt-ch-return*)
       nil)                             ; ignoré : \r\n traité comme \n
      (t
       (setq cur (cons c cur)))))
  (setq out (cons (vl-list->string (reverse cur)) out))
  (reverse out))

;; Supprime les espaces et tabulations en fin de chaîne.
(defun fmt-trim-right (s / codes)
  (setq codes (reverse (vl-string->list s)))
  (while (and codes
              (or (= (car codes) *fmt-ch-space*)
                  (= (car codes) *fmt-ch-tab*)
                  (= (car codes) *fmt-ch-return*)))
    (setq codes (cdr codes)))
  (vl-list->string (reverse codes)))

(defun fmt-trim-left (s / codes)
  (setq codes (vl-string->list s))
  (while (and codes
              (or (= (car codes) *fmt-ch-space*)
                  (= (car codes) *fmt-ch-tab*)))
    (setq codes (cdr codes)))
  (vl-list->string codes))

(defun fmt-trim (s)
  (fmt-trim-left (fmt-trim-right s)))

(defun fmt-blank-string-p (s)
  (= (fmt-trim s) ""))

;; La chaîne est-elle un littéral numérique AutoLISP ?
;; Sert à ne pas appliquer la politique de casse aux nombres.
(defun fmt-number-string-p (s / codes c seen-digit seen-dot seen-exp ok prev-exp)
  (setq codes (vl-string->list s))
  (setq ok t)
  (setq seen-digit nil)
  (setq seen-dot   nil)
  (setq seen-exp   nil)
  (setq prev-exp   nil)
  (if (null codes)
    (setq ok nil))
  ;; signe initial
  (if (and codes
           (or (= (car codes) 43) (= (car codes) 45)))
    (setq codes (cdr codes)))
  (if (null codes)
    (setq ok nil))
  (while (and ok codes)
    (setq c (car codes))
    (cond
      ((and (>= c 48) (<= c 57))
       (setq seen-digit t)
       (setq prev-exp nil))
      ((= c 46)                          ; point décimal
       (if (or seen-dot seen-exp)
         (setq ok nil)
         (setq seen-dot t))
       (setq prev-exp nil))
      ((or (= c 101) (= c 69))           ; e / E
       (if (or seen-exp (not seen-digit))
         (setq ok nil)
         (progn
           (setq seen-exp t)
           (setq prev-exp t))))
      ((or (= c 43) (= c 45))            ; signe d'exposant
       (if (not prev-exp)
         (setq ok nil))
       (setq prev-exp nil))
      (t
       (setq ok nil)))
    (setq codes (cdr codes)))
  (and ok seen-digit))

;;; ------------------------------------------------------------------
;;; Listes et alists de chaînes
;;; ------------------------------------------------------------------

;; assoc insensible à la casse sur des clés chaînes.
(defun fmt-assoc-ci (key alist / out up)
  (setq up  (strcase key))
  (setq out nil)
  (foreach cell alist
    (if (and (null out)
             (= (strcase (car cell)) up))
      (setq out cell)))
  out)

;; Renvoie ALIST où KEY vaut VALUE (remplace l'entrée existante).
(defun fmt-alist-put (alist key value / out done)
  (setq out  nil)
  (setq done nil)
  (foreach cell alist
    (if (= (strcase (car cell)) (strcase key))
      (progn
        (setq out (cons (cons key value) out))
        (setq done t))
      (setq out (cons cell out))))
  (if (not done)
    (setq out (cons (cons key value) out)))
  (reverse out))

(defun fmt-alist-get (alist key / cell)
  (setq cell (fmt-assoc-ci key alist))
  (if cell (cdr cell) nil))

;; Nom d'un symbole ou d'une chaîne, en majuscules — sert à comparer les
;; valeurs d'options quel que soit leur mode de saisie (symbole lu dans un
;; fichier de configuration, chaîne venant de la ligne de commande).
(defun fmt-name-of (x)
  (cond
    ((null x)            "NIL")
    ((= (type x) 'STR)   (strcase x))
    ((= (type x) 'SYM)   (strcase (vl-symbol-name x)))
    (t                   (strcase (vl-princ-to-string x)))))

(defun fmt-name= (x y)
  (= (fmt-name-of x) (fmt-name-of y)))

;; Nom d'une *valeur* d'option : comme fmt-name-of, mais sans les « - » et
;; « : » de tête. Une même valeur s'écrit « cl » en ligne de commande et
;; « :cl » dans un fichier de configuration ; les deux doivent coïncider.
(defun fmt-value-name (x / codes)
  (setq codes (vl-string->list (fmt-name-of x)))
  (while (and codes
              (or (= (car codes) 45)      ; -
                  (= (car codes) 58)))    ; :
    (setq codes (cdr codes)))
  (vl-list->string codes))

;;; ------------------------------------------------------------------
;;; Erreurs
;;; ------------------------------------------------------------------

;; Toutes les erreurs du formateur passent par ici : préfixe stable
;; « FMT-ERROR: », position source quand elle est connue.
(defun fmt-error (msg line col)
  (error (strcat "FMT-ERROR: " msg
                 (if line
                   (strcat " (ligne " (itoa line)
                           (if col (strcat ", colonne " (itoa col)) "")
                           ")")
                   ""))))

(princ)

;;; fmt-util.lsp ends here
