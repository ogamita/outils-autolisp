;;; run-tests.lsp --- Point d'entrée BricsCAD/AutoLISP pour les tests autolisp-json

(defun C:MAIN (/ aj-summary)
  (setq aj-summary (run-suite "autolisp-json"))
  (if (and aj-summary
           (= (car aj-summary) :suite)
           (= (cadr (member :fail aj-summary)) 0)
           (= (cadr (member :error aj-summary)) 0))
    (autolisp-set-status 0)
    (autolisp-set-status 1))
  (princ ""))
