;;; run-tests.lsp --- Point d'entrée des tests autolisp-hash-table.
;;; (Les benchmarks sont découplés : voir `make benchmark` / hash-table-benchmarks.lsp.)

(defun C:MAIN (/ ah-summary)
  (setq ah-summary (run-suite "autolisp-hash-table"))
  (if (and ah-summary
           (= (car ah-summary) :suite)
           (= (cadr (member :fail ah-summary)) 0)
           (= (cadr (member :error ah-summary)) 0))
    (t:set-status 0)
    (t:set-status 1))
  (princ ""))
