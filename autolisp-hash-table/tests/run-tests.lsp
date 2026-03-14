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

(defun C:MAIN (/ ah-summary ah-bench-summary ah-bench-results-state ah-bench-stage-state)
  (setq ah-summary (run-suite "autolisp-hash-table"))
  (if (ah--benchmarks-enabled-p)
    (setq ah-bench-summary (run-suite "autolisp-hash-table-bench")))
  (setq ah-bench-results-state (ah--getprop 'ah-bench-state 'ah-results))
  (setq ah-bench-stage-state (ah--getprop 'ah-bench-state 'ah-stage))
  (if (and ah-summary
           (= (car ah-summary) :suite)
           (= (cadr (member :fail ah-summary)) 0)
           (= (cadr (member :error ah-summary)) 0)
           (or (null ah-bench-summary)
               (and (= (car ah-bench-summary) :suite)
                    (= (cadr (member :fail ah-bench-summary)) 0)
                    (= (cadr (member :error ah-bench-summary)) 0))))
    (autolisp-set-status 0)
    (autolisp-set-status 1))
  (if ah-bench-summary
    (progn
      (t:emit-out
        (strcat "BENCH raw=" (vl-princ-to-string ah-bench-results-state)
                " stage=" (vl-princ-to-string ah-bench-stage-state)))
      (setq ah-bench-results ah-bench-results-state)
      (ah-bench--print-table)))
  (princ ""))
