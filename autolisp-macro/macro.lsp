;; ------------------------------------------------------------------
;; Minimal macro system for AutoLISP / Visual LISP
;; - Intercepts (defmacro ...) when evaluating via (mload ...) or (meval ...)
;; - Stores expander functions on symbol property list via vl-symbol-putprop
;; ------------------------------------------------------------------

(vl-load-com)

(defun m:macro-expander (sym)
  (vl-symbol-getprop sym 'm:macro-expander))

(defun m:set-macro-expander (sym fn)
  (vl-symbol-putprop sym fn 'm:macro-expander))

(defun m:macro-p (sym)
  (and (eq (type sym) 'SYM)
       (m:macro-expander sym)))

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

(defun m:expand-rec (form)
  ;; Fully expand macros anywhere in the form tree.
  ;; Note: we don't attempt to preserve quoting semantics perfectly; keep macros out of quoted data.
  (cond
    ((atom form)
     form)
    (t
     (setq form (m:macroexpand form))
     (if (atom form)
       form
       (cons (m:expand-rec (car form))
             (m:expand-rec (cdr form)))))))

(defun m:meval (form)
  (eval (m:expand-rec form)))

(defun m:defmacro-form (form / name params body fn)
  ;; form = (defmacro NAME (PARAMS...) BODY...)
  (setq name   (cadr form))
  (setq params (caddr form))
  (setq body   (cdddr form))

  ;; Build expander function: (lambda params body...)
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

(defun mload (path / f form)
  "Macro-aware loader. Reads forms, handles (defmacro ...), expands macros, then evals."
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
