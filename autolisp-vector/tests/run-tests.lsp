;;; run-tests.lsp --- BricsCAD/AutoLISP entry point for autolisp-vector tests

(defun av--env-true-p (av-name / av-value)
  (setq av-value (getenv av-name))
  (and av-value
       (not (= av-value ""))
       (not (= (strcase av-value) "0"))
       (not (= (strcase av-value) "FALSE"))
       (not (= (strcase av-value) "NO"))))

(defun av--benchmarks-enabled-p ()
  (or (and (boundp 'av-run-benchmarks-flag)
           av-run-benchmarks-flag)
      (av--env-true-p "AV_RUN_BENCHMARKS")))

(defun C:MAIN (/ av-summary av-bench-result)
  (setq av-summary (run-suite "autolisp-vector"))
  (if (av--benchmarks-enabled-p)
    (setq av-bench-result
          (vl-catch-all-apply 'av-run-benchmarks nil)))
  (if (and av-summary
           (= (car av-summary) :suite)
           (= (cadr (member :fail av-summary)) 0)
           (= (cadr (member :error av-summary)) 0)
           (or (null av-bench-result)
               (not (vl-catch-all-error-p av-bench-result))))
    (autolisp-set-status 0)
    (autolisp-set-status 1))
  (if (and av-bench-result
           (vl-catch-all-error-p av-bench-result))
    (autolisp-log-err
      (strcat "ERROR benchmark: "
              (if (vl-catch-all-error-message av-bench-result)
                (vl-catch-all-error-message av-bench-result)
                "unknown error"))))
  (princ ""))
