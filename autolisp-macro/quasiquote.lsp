;; ================================================================
;; Quasiquote / Unquote / Splice (portable; no reader backquote)
;;
;; Usage:
;;   (quasiquote (a (unquote x) (splice xs) b))
;;
;; Notes:
;; - Proper lists only (no dotted lists).
;; - Nested quasiquote supported: unquote/splice apply at the nearest level.
;; - unquote/splice are markers; we define them as functions that complain
;;   if evaluated at runtime (optional but helpful).
;; ================================================================

(defun m:qq-atom (x)
  (list 'quote x))

(defun m:qq-marker-p (form sym)
  (and (listp form)
       (eq (car form) sym)))

(defun m:qq-expand (form level)
  ;; Returns an AutoLISP form that, when evaluated, produces the quasiquoted value.
  (cond
    ((atom form)
     (m:qq-atom form))

    ;; (unquote X)
    ((m:qq-marker-p form 'unquote)
     (if (= level 1)
       (cadr form)
       ;; nested: keep the marker as data, but expand inside with level-1
       (m:qq-expand-list (list 'unquote (cadr form)) (1- level))))

    ;; (splice X)
    ((m:qq-marker-p form 'splice)
     (if (= level 1)
       ;; splice only meaningful in list context; if used as expression, treat as X
       (cadr form)
       (m:qq-expand-list (list 'splice (cadr form)) (1- level))))

    ;; (quasiquote X)  => increases nesting level
    ((m:qq-marker-p form 'quasiquote)
     (m:qq-expand-list (list 'quasiquote (cadr form)) (1+ level)))

    (t
     (m:qq-expand-list form level))))

(defun m:qq-expand-list (lst level / pieces e)
  ;; Build (append piece1 piece2 ...), where each piece is either:
  ;; - a list producing a single element, or
  ;; - a spliced list (when (splice ...) at current level)
  (setq pieces nil)

  (while lst
    (setq e (car lst))

    (cond
      ;; Splice at current level: contribute list directly
      ((and (= level 1)
            (m:qq-marker-p e 'splice))
       (setq pieces (cons (cadr e) pieces)))

      ;; Normal element: contribute a 1-element list
      (t
       (setq pieces
             (cons (list 'list (m:qq-expand e level))
                   pieces))))

    (setq lst (cdr lst)))

  (setq pieces (reverse pieces))

  (cond
    ((null pieces)
     (list 'quote nil))
    ((= (length pieces) 1)
     (car pieces))
    (t
     (cons 'append pieces))))

;; ------------------------------------------------
;; Macro: quasiquote
;; ------------------------------------------------

(defmacro quasiquote (x)
  (m:qq-expand x 1))

;; ------------------------------------------------
;; Optional runtime guards: unquote/splice should not run
;; ------------------------------------------------

(defun unquote (x)
  (prompt "\n[unquote] Error: UNQUOTE is only valid inside (quasiquote ...).")
  x)

(defun splice (x)
  (prompt "\n[splice] Error: SPLICE is only valid inside (quasiquote ...).")
  x)

