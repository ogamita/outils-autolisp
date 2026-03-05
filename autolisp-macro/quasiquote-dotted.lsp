;; ================================================================
;; Quasiquote / Unquote / Splice with dotted-list support
;;
;; Forms:
;;   (quasiquote <form>)
;;   (unquote <expr>)
;;   (splice  <expr>)   ; only meaningful in list position
;;
;; Supports dotted lists: (quasiquote (a b . (unquote tail))) etc.
;; ================================================================

(defun m:qq-atom (x)
  (list 'quote x))

(defun m:qq-marker-p (form sym)
  (and (listp form)
       (eq (car form) sym)))

;; Runtime helper: append that permits a non-list tail (dotted result).
(defun m:qq-append2 (a b)
  (cond
    ((null a) b)
    ((atom a)
     (prompt "\n[m:qq-append2] Error: SPLICE value is not a proper list.")
     b)
    (t
     (cons (car a)
           (m:qq-append2 (cdr a) b)))))

(defun m:qq-expand (form level)
  ;; Expand FORM at quasiquote nesting LEVEL (1 = active).
  (cond
    ((atom form)
     (m:qq-atom form))

    ;; (unquote X)
    ((m:qq-marker-p form 'unquote)
     (if (= level 1)
       (cadr form)
       ;; nested: treat marker as data
       (m:qq-expand-cons (cons 'unquote (cons (cadr form) nil)) (1- level))))

    ;; (splice X) as a whole expression:
    ;; at level 1, it's just X (mostly useful for debugging);
    ;; in list position, it's handled specially by m:qq-expand-cons.
    ((m:qq-marker-p form 'splice)
     (if (= level 1)
       (cadr form)
       (m:qq-expand-cons (cons 'splice (cons (cadr form) nil)) (1- level))))

    ;; (quasiquote X) increases nesting
    ((m:qq-marker-p form 'quasiquote)
     (m:qq-expand-cons (cons 'quasiquote (cons (cadr form) nil)) (1+ level)))

    (t
     (m:qq-expand-cons form level))))

(defun m:qq-expand-cons (cell level / a d)
  ;; CELL is a cons (possibly improper list).
  (setq a (car cell))
  (setq d (cdr cell))

  (cond
    ;; If the CAR is (splice X) at the active level:
    ;; concatenate X onto the expansion of the CDR, allowing dotted tails.
    ((and (= level 1)
          (m:qq-marker-p a 'splice))
     (list 'm:qq-append2
           (cadr a)
           (m:qq-expand d level)))

    ;; Otherwise, build a cons of expanded car and cdr.
    (t
     (list 'cons
           (m:qq-expand a level)
           (m:qq-expand d level)))))

(defmacro quasiquote (x)
  (m:qq-expand x 1))

;; Optional runtime guards: these should never be evaluated directly.
(defun unquote (x)
  (prompt "\n[unquote] Error: UNQUOTE is only valid inside (quasiquote ...).")
  x)

(defun splice (x)
  (prompt "\n[splice] Error: SPLICE is only valid inside (quasiquote ...).")
  x)
