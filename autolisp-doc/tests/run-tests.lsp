;;; run-tests.lsp --- BricsCAD/AutoLISP entry point for autolisp-doc tests

(defun ad--summary-ok-p (ad-summary)
  (and ad-summary
       (= (car ad-summary) :suite)
       (= (cadr (member :fail ad-summary)) 0)
       (= (cadr (member :error ad-summary)) 0)))

(defun C:MAIN (/ ad-summary)
  (setq ad-summary (run-suite "autolisp-doc"))
  (if (ad--summary-ok-p ad-summary)
    (autolisp-set-status 0)
    (autolisp-set-status 1))
  (princ ""))

(princ)

;;; run-tests.lsp ends here
