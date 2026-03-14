;;; hash-table-benchmarks.lsp --- Optional benchmarks for autolisp-hash-table

(setq ah-bench-results nil)

(defun ah-bench--atoi-default (ah-text ah-default / ah-value)
  (if (or (null ah-text) (= ah-text ""))
    ah-default
    (progn
      (setq ah-value (atoi ah-text))
      (if (> ah-value 0) ah-value ah-default))))

(defun ah-bench--samples ()
  (ah-bench--atoi-default (getenv "AH_BENCH_SAMPLES") 1000))

(defun ah-bench--sizes ()
  '(11 97 997 5003))

(defun ah-bench--now-ms (/ ah-result)
  (setq ah-result (vl-catch-all-apply 'getvar (list "MILLISECS")))
  (if (vl-catch-all-error-p ah-result)
    0
    ah-result))

(defun ah-bench--elapsed-ms (ah-start)
  (- (ah-bench--now-ms) ah-start))

(defun ah-bench--pad-right (ah-text ah-width / ah-out)
  (setq ah-out ah-text)
  (while (< (strlen ah-out) ah-width)
    (setq ah-out (strcat ah-out " ")))
  ah-out)

(defun ah-bench--row-string (ah-kind ah-size ah-iterations ah-ms ah-note)
  (strcat
    (ah-bench--pad-right ah-kind 22)
    " | "
    (ah-bench--pad-right (vl-princ-to-string ah-size) 6)
    " | "
    (ah-bench--pad-right (vl-princ-to-string ah-iterations) 10)
    " | "
    (ah-bench--pad-right (vl-princ-to-string ah-ms) 8)
    (if ah-note
      (strcat " | " ah-note)
      "")))

(defun ah-bench--emit (ah-label ah-size ah-iterations ah-ms ah-note)
  (setq ah-bench-results
        (cons (list ah-label ah-size ah-iterations ah-ms ah-note)
              ah-bench-results))
  (autolisp-log-out
    (strcat "BENCH "
            ah-label
            " size=" (vl-princ-to-string ah-size)
            " iterations=" (vl-princ-to-string ah-iterations)
            " ms=" (vl-princ-to-string ah-ms)
            (if ah-note (strcat " " ah-note) ""))))

(defun ah-bench--print-table ()
  (autolisp-log-out "BENCHMARKS")
  (autolisp-log-out "kind                   | size   | iterations | ms       | note")
  (autolisp-log-out "----------------------+--------+------------+----------+----------------")
  (foreach ah-row (reverse ah-bench-results)
    (autolisp-log-out
      (ah-bench--row-string
        (nth 0 ah-row)
        (nth 1 ah-row)
        (nth 2 ah-row)
        (nth 3 ah-row)
        (nth 4 ah-row)))))

(defun ah-bench--call (ah-label ah-fn ah-args / ah-result)
  (autolisp-log-out (strcat "BENCH step-enter " ah-label))
  (setq ah-result (vl-catch-all-apply ah-fn ah-args))
  (if (vl-catch-all-error-p ah-result)
    (progn
      (autolisp-log-err
        (strcat "ERROR benchmark-step "
                ah-label
                ": "
                (vl-princ-to-string
                  (vl-catch-all-error-message ah-result))))
      (error
        (strcat "benchmark-step "
                ah-label
                ": "
                (vl-princ-to-string
                  (vl-catch-all-error-message ah-result))))))
  (autolisp-log-out (strcat "BENCH step-leave " ah-label))
  ah-result)

(defun ah-bench--range-list (ah-count / ah-items)
  (setq ah-items nil)
  (while (> ah-count 0)
    (setq ah-count (1- ah-count))
    (setq ah-items (cons ah-count ah-items)))
  ah-items)

(defun ah-bench--data (ah-size / ah-items ah-index)
  (setq ah-items nil)
  (setq ah-index 0)
  (while (< ah-index ah-size)
    (setq ah-items
          (cons (list (strcat "k" (itoa ah-index))
                      ah-index)
                ah-items))
    (setq ah-index (1+ ah-index)))
  (reverse ah-items))

(defun ah-bench--bench-put (ah-size ah-items / ah-table ah-start ah-item ah-result ah-ms ah-count)
  (autolisp-log-out "BENCH bench-put-enter")
  (setq ah-result
        (vl-catch-all-apply 'ah-make-hash-table (list 'equal ah-size 2.0 0.5)))
  (if (vl-catch-all-error-p ah-result)
    (progn
      (autolisp-log-err
        (strcat "ERROR bench-put make-table size="
                (vl-princ-to-string ah-size)
                " message="
                (vl-princ-to-string
                  (vl-catch-all-error-message ah-result))))
      (error "bench-put make-table failed")))
  (setq ah-table ah-result)
  (autolisp-log-out "BENCH bench-put-made-table")
  (setq ah-start (ah-bench--now-ms))
  (foreach ah-item ah-items
    (setq ah-result
          (vl-catch-all-apply 'ah-puthash
                              (list ah-table (car ah-item) (cadr ah-item))))
    (if (vl-catch-all-error-p ah-result)
      (progn
        (autolisp-log-err
          (strcat "ERROR bench-put key="
                  (vl-princ-to-string (car ah-item))
                  " value="
                  (vl-princ-to-string (cadr ah-item))
                  " message="
                  (vl-princ-to-string
                    (vl-catch-all-error-message ah-result))))
        (error "bench-put insert failed"))))
  (autolisp-log-out "BENCH put-loop-done")
  (setq ah-ms (ah-bench--elapsed-ms ah-start))
  (autolisp-log-out (strcat "BENCH put-elapsed ms=" (vl-princ-to-string ah-ms)))
  (setq ah-count (ah-hash-table-count ah-table))
  (autolisp-log-out (strcat "BENCH put-count count=" (vl-princ-to-string ah-count)))
  (ah-bench--emit "ah-puthash" ah-size (length ah-items)
                  ah-ms
                  (strcat "count=" (vl-princ-to-string ah-count))))

(defun ah-bench--bench-get (ah-size ah-items / ah-table ah-start ah-sum)
  (setq ah-table (ah-make-hash-table 'equal ah-size 2.0 0.5))
  (foreach ah-item ah-items
    (ah-puthash ah-table (car ah-item) (cadr ah-item)))
  (setq ah-sum 0)
  (setq ah-start (ah-bench--now-ms))
  (foreach ah-item ah-items
    (setq ah-sum (+ ah-sum (ah-gethash ah-table (car ah-item) 0))))
  (ah-bench--emit "ah-gethash" ah-size (length ah-items)
                  (ah-bench--elapsed-ms ah-start)
                  (strcat "sum=" (vl-princ-to-string ah-sum))))

(defun ah-bench--bench-rem (ah-size ah-items / ah-table ah-start)
  (setq ah-table (ah-make-hash-table 'equal ah-size 2.0 0.5))
  (foreach ah-item ah-items
    (ah-puthash ah-table (car ah-item) (cadr ah-item)))
  (setq ah-start (ah-bench--now-ms))
  (foreach ah-item ah-items
    (ah-remhash ah-table (car ah-item)))
  (ah-bench--emit "ah-remhash" ah-size (length ah-items)
                  (ah-bench--elapsed-ms ah-start)
                  (strcat "count=" (vl-princ-to-string
                                    (ah-hash-table-count ah-table)))))

(defun ah-bench--run-size (ah-size / ah-items)
  (setq ah-items (ah-bench--data ah-size))
  (autolisp-log-out
    (strcat "BENCH-SIZE size=" (vl-princ-to-string ah-size)
            " iterations=" (vl-princ-to-string (length ah-items))))
  (ah-bench--call "put" 'ah-bench--bench-put (list ah-size ah-items))
  (ah-bench--call "get" 'ah-bench--bench-get (list ah-size ah-items))
  (ah-bench--call "rem" 'ah-bench--bench-rem (list ah-size ah-items)))

(defun ah-run-benchmarks (/ ah-samples)
  (setq ah-bench-results nil)
  (setq ah-samples (ah-bench--samples))
  (autolisp-log-out
    (strcat "BENCH-BEGIN samples=" (vl-princ-to-string ah-samples)))
  (repeat ah-samples
    nil)
  (foreach ah-size (ah-bench--sizes)
    (ah-bench--run-size ah-size))
  (ah-bench--print-table)
  (autolisp-log-out "BENCH-END")
  nil)
