;;; run-tests.lsp --- BricsCAD/AutoLISP entry point for autolisp-hash-table tests

(defun ah--env-true-p (ah-name / ah-value)
  (setq ah-value (getenv ah-name))
  (and ah-value
       (not (= ah-value ""))
       (not (= (strcase ah-value) "0"))
       (not (= (strcase ah-value) "FALSE"))
       (not (= (strcase ah-value) "NO"))))

(defun ah--benchmarks-enabled-p ()
  (or (and (boundp 'ah-run-benchmarks-flag)
           ah-run-benchmarks-flag)
      (ah--env-true-p "AH_RUN_BENCHMARKS")))

(defun C:MAIN (/ ah-summary ah-bench-result)
  (setq ah-summary (run-suite "autolisp-hash-table"))
  (if (ah--benchmarks-enabled-p)
    (setq ah-bench-result
          (vl-catch-all-apply 'ah-run-benchmarks nil)))
  (if (and ah-summary
           (= (car ah-summary) :suite)
           (= (cadr (member :fail ah-summary)) 0)
           (= (cadr (member :error ah-summary)) 0)
           (or (null ah-bench-result)
               (not (vl-catch-all-error-p ah-bench-result))))
    (autolisp-set-status 0)
    (autolisp-set-status 1))
  (if (and ah-bench-result
           (vl-catch-all-error-p ah-bench-result))
    (autolisp-log-err
      (strcat "ERROR benchmark: "
              (if (vl-catch-all-error-message ah-bench-result)
                (vl-catch-all-error-message ah-bench-result)
                "unknown error"))))
  (princ ""))
