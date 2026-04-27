
(defun fboundp (sym)
  "Whether the symbol is bound to a function."
  (not (null (car (atoms-family 0 (list (vl-symbol-name sym)))))))
