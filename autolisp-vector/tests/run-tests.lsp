;;; run-tests.lsp --- Point d'entrée des tests autolisp-vector.
;;; (Les benchmarks sont découplés : voir `make benchmark` / vector-benchmarks.lsp.)

(defun C:MAIN (/ av-summary)
  (setq av-summary (run-suite "autolisp-vector"))
  (if (and av-summary
           (= (car av-summary) :suite)
           (= (cadr (member :fail av-summary)) 0)
           (= (cadr (member :error av-summary)) 0))
    (t:set-status 0)
    (t:set-status 1))
  (princ ""))
