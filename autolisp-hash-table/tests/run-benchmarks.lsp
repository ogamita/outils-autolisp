;;; run-benchmarks.lsp --- BricsCAD/AutoLISP entry point for autolisp-hash-table benchmarks

(defun C:MAIN (/ ah-bench-results-state ah-bench-stage-state)
  (ah-run-benchmarks)
  (setq ah-bench-results-state (ah--getprop 'ah-bench-state 'ah-results))
  (setq ah-bench-stage-state (ah--getprop 'ah-bench-state 'ah-stage))
  (setq ah-bench-results ah-bench-results-state)
  (t:emit-out
    (strcat "BENCH raw=" (vl-princ-to-string ah-bench-results-state)
            " stage=" (vl-princ-to-string ah-bench-stage-state)))
  (ah-bench--print-table)
  (if ah-bench-results-state
    (autolisp-set-status 0)
    (autolisp-set-status 1))
  (princ ""))

(princ "")
