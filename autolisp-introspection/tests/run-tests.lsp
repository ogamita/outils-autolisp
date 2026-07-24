;;; run-tests.lsp --- Point d'entrée des tests autolisp-introspection

(defun C:MAIN (/ summary)
  (setq summary (run-suite "autolisp-introspection"))
  (if (and summary
           (= (car summary) :suite)
           (= (cadr (member :fail summary)) 0)
           (= (cadr (member :error summary)) 0))
    (t:set-status 0)
    (t:set-status 1))
  (princ ""))
