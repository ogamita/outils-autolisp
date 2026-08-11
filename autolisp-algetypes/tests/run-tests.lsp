;;; run-tests.lsp --- Point d'entrée des tests autolisp-algetypes

(defun C:MAIN (/ al-summary)
  (setq al-summary (run-suite "autolisp-algetypes"))
  (if (and al-summary
           (= (car al-summary) :suite)
           (= (cadr (member :fail al-summary)) 0)
           (= (cadr (member :error al-summary)) 0))
    (t:set-status 0)
    (t:set-status 1))
  (princ ""))
