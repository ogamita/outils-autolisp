(vl-load-com)

;; -----------------------------
;; Macro registry (symbol plist)
;; -----------------------------

(defun m:macro-expander (sym)
  (vl-symbol-getprop sym 'm:macro-expander))

(defun m:set-macro-expander (sym fn)
  (vl-symbol-putprop sym fn 'm:macro-expander))

(defun m:macro-p (sym)
  (and (eq (type sym) 'SYM)
       (m:macro-expander sym)))

;; -----------------------------
;; Gensym (minimal hygiene helper)
;; -----------------------------

(defun m:gensym (/ n)
  (setq n (1+ (cond ((vl-symbol-getprop 'm:*gensym-counter* 'm:value))
                    (t 0))))
  (vl-symbol-putprop 'm:*gensym-counter* n 'm:value)
  (read (strcat "G" (itoa n))))

;; -----------------------------
;; Macroexpand
;; -----------------------------

(defun m:macroexpand-1 (form / head expander)
  (cond
    ((atom form)
     form)
    (t
     (setq head (car form))
     (cond
       ((and (eq (type head) 'SYM)
             (setq expander (m:macro-expander head)))
        (apply expander (cdr form)))
       (t
        form)))))

(defun m:macroexpand (form / prev next)
  (setq prev form)
  (setq next (m:macroexpand-1 prev))
  (while (not (equal next prev))
    (setq prev next)
    (setq next (m:macroexpand-1 prev)))
  next)

(defun m:macroexpand-all (form)
  ;; Expand macros everywhere, but *do not expand inside (quote ...)*.
  (cond
    ((atom form)
     form)
    (t
     (setq form (m:macroexpand form))
     (cond
       ((atom form)
        form)
       ((and (eq (car form) 'quote)
             (cdr form))
        form)
       (t
        (cons (m:macroexpand-all (car form))
              (m:macroexpand-all (cdr form))))))))

(defun m:meval (form)
  (eval (m:macroexpand-all form)))

;; -----------------------------
;; defmacro handling
;; -----------------------------

(defun m:defmacro-form (form / name params body fn)
  ;; (defmacro NAME (PARAMS...) BODY...)
  (setq name   (cadr form))
  (setq params (caddr form))
  (setq body   (cdddr form))

  ;; expander = (lambda params body...)
  (setq fn (eval (cons 'lambda (cons params body))))
  (m:set-macro-expander name fn)
  name)

(defun m:eval-form (form)
  (cond
    ((and (listp form)
          (eq (car form) 'defmacro))
     (m:defmacro-form form))
    (t
     (m:meval form))))

;; -----------------------------
;; Macro-aware loader
;; -----------------------------

(defun mload (path / f form)
  "Macro-aware loader. Interprets (defmacro ...), expands macros, then evals."
  (setq f (open path "r"))
  (if (null f)
    (progn
      (prompt (strcat "\n[mload] Cannot open: " path))
      nil)
    (progn
      (while (setq form (read f nil 'm:eof))
        (if (eq form 'm:eof)
          (setq form nil)
          (m:eval-form form)))
      (close f)
      (princ))))

;; -----------------------------
;; AutoCAD command wrapper
;; -----------------------------

(defun c:loadm (/ path)
  (setq path (getfiled "Load macro-aware LISP" "" "lsp" 0))
  (if path
    (mload path))
  (princ))
