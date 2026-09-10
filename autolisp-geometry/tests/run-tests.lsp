;;; run-tests.lsp --- Point d'entrée des tests autolisp-geometry.

(defun C:MAIN (/ geom-summary)
  (setq geom-summary (run-suite "autolisp-geometry"))
  (if (and geom-summary
           (= (car geom-summary) :suite)
           (= (cadr (member :fail geom-summary)) 0)
           (= (cadr (member :error geom-summary)) 0))
    (t:set-status 0)
    (t:set-status 1))
  (princ ""))
