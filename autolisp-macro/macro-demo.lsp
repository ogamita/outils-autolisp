(defmacro when (test &rest body)
  (list 'if test
        (cons 'progn body)))

(defmacro unless (test &rest body)
  (list 'if (list 'not test)
        (cons 'progn body)))

(defmacro incf (place &optional (delta 1))
  (list 'setq place
        (list '+ place delta)))

(defmacro with-gensym ((name) &rest body)
  ;; Example helper macro using m:gensym.
  ;; Usage: (with-gensym (g) ... g ...)
  (list 'let (list (list name '(m:gensym)))
        (cons 'progn body)))

(defun c:macro-demo (/ x)
  (setq x 0)
  (when (< x 3)
    (incf x)
    (print x))
  (unless (= x 0)
    (print "x is non-zero"))
  (with-gensym (g)
    (print g))
  (princ))
