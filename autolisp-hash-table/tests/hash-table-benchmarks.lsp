;;; hash-table-benchmarks.lsp --- Optional benchmarks for autolisp-hash-table

(defsuite "autolisp-hash-table-bench")
(in-suite "autolisp-hash-table-bench")

(setq ah-bench-results nil)
(setq ah-bench-table-cache nil)
(setq ah-bench-last-stage nil)

(defun ah-bench--set-cache (ah-cache)
  (setq ah-bench-table-cache ah-cache)
  (ah--putprop 'ah-bench-state ah-cache 'ah-cache)
  ah-cache)

(defun ah-bench--set-stage (ah-stage)
  (setq ah-bench-last-stage ah-stage)
  (ah--putprop 'ah-bench-state ah-stage 'ah-stage)
  ah-stage)

(defun ah-bench--set-results (ah-results)
  (setq ah-bench-results ah-results)
  (ah--putprop 'ah-bench-state ah-results 'ah-results)
  ah-results)

(defun ah-bench--atoi-default (ah-text ah-default / ah-value)
  (if (or (null ah-text) (= ah-text ""))
    ah-default
    (progn
      (setq ah-value (atoi ah-text))
      (if (> ah-value 0) ah-value ah-default))))

(defun ah-bench--samples ()
  (ah-bench--atoi-default (getenv "AH_BENCH_SAMPLES") 1000))

(defun ah-bench--sizes ()
  '(11 23 47 97))

(defun ah-bench--now-ms ()
  (getvar "MILLISECS"))

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
  (ah-bench--set-results
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
  (t:emit-out "BENCHMARKS")
  (t:emit-out "kind                   | size   | iterations | ms       | note")
  (t:emit-out "----------------------+--------+------------+----------+----------------")
  (foreach ah-row (reverse ah-bench-results)
    (t:emit-out
      (ah-bench--row-string
        (nth 0 ah-row)
        (nth 1 ah-row)
        (nth 2 ah-row)
        (nth 3 ah-row)
        (nth 4 ah-row)))))

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

(defun ah-bench--prepare-cache (/ bh-size bh-table)
  (ah-bench--set-cache nil)
  (foreach bh-size (ah-bench--sizes)
    (setq bh-table (ah-bench--make-table bh-size))
    (ah-bench--set-cache
      (cons (cons bh-size bh-table) ah-bench-table-cache)))
  ah-bench-table-cache)

(defun ah-bench--make-table (bh-size / bh-table bh-empty bh-deleted bh-capacity bh-slots)
  (ah-bench--set-stage "make-table:start")
  (setq bh-table (ah--make-table-symbol))
  (ah-bench--set-stage "make-table:table-symbol")
  (setq bh-empty (ah--make-symbol "ah-empty-"))
  (ah-bench--set-stage "make-table:empty-symbol")
  (setq bh-deleted (ah--make-symbol "ah-deleted-"))
  (ah-bench--set-stage "make-table:deleted-symbol")
  (setq bh-capacity (ah--next-prime bh-size))
  (ah-bench--set-stage "make-table:capacity")
  (setq bh-slots (ah--make-slot-vector bh-capacity bh-empty))
  (ah-bench--set-stage "make-table:slots")
  (ah--putprop bh-table 'equal 'ah-test)
  (ah--putprop bh-table 0 'ah-count)
  (ah--putprop bh-table 0 'ah-deleted-count)
  (ah--putprop bh-table bh-capacity 'ah-size)
  (ah--putprop bh-table 2.0 'ah-rehash-size)
  (ah--putprop bh-table 0.5 'ah-rehash-threshold)
  (ah--putprop bh-table bh-slots 'ah-slots)
  (ah--putprop bh-table bh-empty 'ah-empty-marker)
  (ah--putprop bh-table bh-deleted 'ah-deleted-marker)
  (ah-bench--set-stage "make-table:done")
  bh-table)

(defun ah-bench--table-for-size (bh-size / bh-cell bh-table)
  (if (null ah-bench-table-cache)
    (ah-bench--set-cache (ah--getprop 'ah-bench-state 'ah-cache)))
  (ah-bench--set-stage "table-for-size:assoc")
  (setq bh-cell (assoc bh-size ah-bench-table-cache))
  (if bh-cell
    (progn
      (ah-bench--set-stage "table-for-size:hit")
      (cdr bh-cell))
    (progn
      (ah-bench--set-stage "table-for-size:make")
      (setq bh-table (ah-bench--make-table bh-size))
      (ah-bench--set-stage "table-for-size:made")
      (ah-bench--set-cache
        (cons (cons bh-size bh-table) ah-bench-table-cache))
      (ah-bench--set-stage "table-for-size:cached")
      bh-table)))

(defun ah-bench--bench-put (bh-size bh-items / bh-table bh-start bh-item bh-ms bh-count)
  (ah-bench--set-stage "put:start")
  (setq bh-table (ah-bench--table-for-size bh-size))
  (ah-bench--set-stage "put:table")
  (ah-clrhash bh-table)
  (ah-bench--set-stage "put:clear")
  (setq bh-start (ah-bench--now-ms))
  (ah-bench--set-stage "put:clock")
  (foreach bh-item bh-items
    (ah-puthash bh-table (car bh-item) (cadr bh-item)))
  (ah-bench--set-stage "put:loop")
  (ah-bench--emit "ah-puthash" bh-size (length bh-items)
                  (ah-bench--elapsed-ms bh-start)
                  (strcat "count=" (vl-princ-to-string
                                    (ah-hash-table-count bh-table)))))

(defun ah-bench--bench-get (bh-size bh-items / bh-table bh-start bh-sum bh-item)
  (setq bh-table (ah-bench--table-for-size bh-size))
  (ah-clrhash bh-table)
  (foreach bh-item bh-items
    (ah-puthash bh-table (car bh-item) (cadr bh-item)))
  (setq bh-sum 0)
  (setq bh-start (ah-bench--now-ms))
  (foreach bh-item bh-items
    (setq bh-sum (+ bh-sum (ah-gethash bh-table (car bh-item) 0))))
  (ah-bench--emit "ah-gethash" bh-size (length bh-items)
                  (ah-bench--elapsed-ms bh-start)
                  (strcat "sum=" (vl-princ-to-string bh-sum))))

(defun ah-bench--bench-rem (bh-size bh-items / bh-table bh-start bh-item)
  (setq bh-table (ah-bench--table-for-size bh-size))
  (ah-clrhash bh-table)
  (foreach bh-item bh-items
    (ah-puthash bh-table (car bh-item) (cadr bh-item)))
  (setq bh-start (ah-bench--now-ms))
  (foreach bh-item bh-items
    (ah-remhash bh-table (car bh-item)))
  (ah-bench--emit "ah-remhash" bh-size (length bh-items)
                  (ah-bench--elapsed-ms bh-start)
                  (strcat "count=" (vl-princ-to-string
                                    (ah-hash-table-count bh-table)))))

(defun ah-bench--run-size (bh-size / bh-items)
  (ah-bench--set-stage "run-size:start")
  (setq bh-items (ah-bench--data bh-size))
  (ah-bench--set-stage "run-size:data")
  (ah-bench--bench-put bh-size bh-items)
  (ah-bench--set-stage "run-size:after-put")
  (ah-bench--bench-get bh-size bh-items)
  (ah-bench--set-stage "run-size:after-get")
  (ah-bench--bench-rem bh-size bh-items)
  (ah-bench--set-stage "run-size:after-rem"))

(defun ah-run-benchmarks (/ bh-samples bh-size)
  (ah-bench--set-results nil)
  (ah-bench--set-stage "run:start")
  (setq bh-samples (ah-bench--samples))
  (repeat bh-samples
    nil)
  (ah-bench--set-stage "run:samples")
  (foreach bh-size (ah-bench--sizes)
    (ah-bench--run-size bh-size))
  (ah-bench--set-stage "run:done")
  nil)

(deftest
  "benchmarks collect rows"
  (function
    (lambda ()
      (ah-bench--prepare-cache)
      (ah-run-benchmarks)
      (is (> (length ah-bench-results) 0)
          "benchmark produced no rows"))))
