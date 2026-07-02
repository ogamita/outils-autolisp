;;; vector-benchmarks.lsp --- Optional benchmarks for autolisp-vector

(setq av-bench-results nil)

(defun av-bench--atoi-default (av-text av-default / av-value)
  (if (or (null av-text) (= av-text ""))
    av-default
    (progn
      (setq av-value (atoi av-text))
      (if (> av-value 0) av-value av-default))))

(defun av-bench--samples ()
  (av-bench--atoi-default (getenv "AV_BENCH_SAMPLES") 1000))

(defun av-bench--sizes ()
  '(5 10 50 100 500 1000 5000))

(defun av-bench--now-ms ()
  (getvar "MILLISECS"))

(defun av-bench--elapsed-ms (av-start)
  (- (av-bench--now-ms) av-start))

(defun av-bench--max2 (av-a av-b)
  (if (> av-a av-b) av-a av-b))

(defun av-bench--min2 (av-a av-b)
  (if (< av-a av-b) av-a av-b))

(defun av-bench--rand-step (av-state)
  (rem (+ (* av-state 1103515245) 12345) 2147483647))

(defun av-bench--random-indices (av-count av-size / av-items av-state)
  (setq av-items nil)
  (setq av-state 1234567)
  (while (> av-count 0)
    (setq av-state (av-bench--rand-step av-state))
    (setq av-items (cons (rem av-state av-size) av-items))
    (setq av-count (1- av-count)))
  (reverse av-items))

(defun av-bench--range-list (av-count / av-items)
  (setq av-items nil)
  (while (> av-count 0)
    (setq av-count (1- av-count))
    (setq av-items (cons av-count av-items)))
  av-items)

(defun av-bench--drop (av-list av-count)
  (while (and av-list (> av-count 0))
    (setq av-list (cdr av-list))
    (setq av-count (1- av-count)))
  av-list)

(defun av-bench--take (av-list av-count / av-items)
  (setq av-items nil)
  (while (and av-list (> av-count 0))
    (setq av-items (cons (car av-list) av-items))
    (setq av-list (cdr av-list))
    (setq av-count (1- av-count)))
  (reverse av-items))

(defun av-bench--list-subseq (av-list av-start av-end)
  (av-bench--take (av-bench--drop av-list av-start) (- av-end av-start)))

(defun av-bench--list-set-at (av-list av-index av-value / av-prefix av-tail)
  (setq av-prefix (av-bench--take av-list av-index))
  (setq av-tail (av-bench--drop av-list (1+ av-index)))
  (append av-prefix (cons av-value av-tail)))

(defun av-bench--list-replace-range (av-list av-start av-end av-replacement
                                      / av-prefix av-suffix)
  (setq av-prefix (av-bench--take av-list av-start))
  (setq av-suffix (av-bench--drop av-list av-end))
  (append av-prefix av-replacement av-suffix))

(defun av-bench--list-clone (av-list)
  (append av-list nil))

(defun av-bench--vector-clone (av-vec / vv-copy)
  (setq vv-copy (av-copy-vector av-vec))
  (if (av--fill-pointer-present-p av-vec)
    (av--putprop vv-copy (av-fill-pointer av-vec) 'av-fill-pointer))
  vv-copy)

(defun av-bench--emit (av-label av-size av-iterations av-ms av-note)
  (setq av-bench-results
        (cons (list av-label av-size av-iterations av-ms av-note)
              av-bench-results))
  (autolisp-log-out
    (strcat "BENCH "
            av-label
            " size=" (itoa av-size)
            " iterations=" (itoa av-iterations)
            " ms=" (itoa av-ms)
            (if av-note (strcat " " av-note) ""))))

(defun av-bench--pad-right (av-text av-width / av-out)
  (setq av-out av-text)
  (while (< (strlen av-out) av-width)
    (setq av-out (strcat av-out " ")))
  av-out)

(defun av-bench--row-string (av-kind av-size av-iterations av-ms av-note)
  (strcat
    (av-bench--pad-right av-kind 22)
    " | "
    (av-bench--pad-right (itoa av-size) 6)
    " | "
    (av-bench--pad-right (itoa av-iterations) 10)
    " | "
    (av-bench--pad-right (itoa av-ms) 8)
    (if av-note
      (strcat " | " av-note)
      "")))

(defun av-bench--call (vv-label vv-fn vv-args / vv-result)
  (autolisp-log-out (strcat "BENCH step-enter " vv-label))
  (setq vv-result (vl-catch-all-apply vv-fn vv-args))
  (if (vl-catch-all-error-p vv-result)
    (progn
      (autolisp-log-err
        (strcat "ERROR benchmark-step "
                vv-label
                ": "
                (vl-catch-all-error-message vv-result)))
      (error
        (strcat "benchmark-step "
                vv-label
                ": "
                (vl-catch-all-error-message vv-result)))))
  (autolisp-log-out (strcat "BENCH step-leave " vv-label))
  vv-result)

(defun av-bench--print-table ()
  (autolisp-log-out "BENCHMARKS")
  (autolisp-log-out "kind                   | size   | iterations | ms       | note")
  (autolisp-log-out "----------------------+--------+------------+----------+----------------")
  (foreach av-row (reverse av-bench-results)
    (autolisp-log-out
      (av-bench--row-string
        (nth 0 av-row)
        (nth 1 av-row)
        (nth 2 av-row)
        (nth 3 av-row)
        (nth 4 av-row)))))

(defun av-bench--bench-length (av-vec av-list av-iterations / av-start av-dummy)
  (setq av-dummy 0)
  (setq av-start (av-bench--now-ms))
  (repeat av-iterations
    (setq av-dummy (+ av-dummy (av-length av-vec))))
  (av-bench--emit "av-length" (av-length av-vec) av-iterations
                  (av-bench--elapsed-ms av-start)
                  (strcat "dummy=" (itoa av-dummy)))
  (setq av-dummy 0)
  (setq av-start (av-bench--now-ms))
  (repeat av-iterations
    (setq av-dummy (+ av-dummy (length av-list))))
  (av-bench--emit "length" (length av-list) av-iterations
                  (av-bench--elapsed-ms av-start)
                  (strcat "dummy=" (itoa av-dummy))))

(defun av-bench--bench-read (av-vec av-list av-indices / av-start av-sum)
  (setq av-sum 0)
  (setq av-start (av-bench--now-ms))
  (foreach av-index av-indices
    (setq av-sum (+ av-sum (av-aref av-vec av-index))))
  (av-bench--emit "av-aref" (av-length av-vec) (length av-indices)
                  (av-bench--elapsed-ms av-start)
                  (strcat "sum=" (itoa av-sum)))
  (setq av-sum 0)
  (setq av-start (av-bench--now-ms))
  (foreach av-index av-indices
    (setq av-sum (+ av-sum (nth av-index av-list))))
  (av-bench--emit "nth" (length av-list) (length av-indices)
                  (av-bench--elapsed-ms av-start)
                  (strcat "sum=" (itoa av-sum))))

(defun av-bench--bench-write (av-vec av-list av-indices
                               / av-values av-start av-index-rest av-value-rest)
  (setq av-values (av-bench--range-list (length av-indices)))
  (setq av-vec (av-bench--vector-clone av-vec))
  (setq av-start (av-bench--now-ms))
  (setq av-index-rest av-indices)
  (setq av-value-rest av-values)
  (while av-index-rest
    (av-set-aref av-vec (car av-index-rest) (car av-value-rest))
    (setq av-index-rest (cdr av-index-rest))
    (setq av-value-rest (cdr av-value-rest)))
  (av-bench--emit "av-set-aref" (av-length av-vec) (length av-indices)
                  (av-bench--elapsed-ms av-start) nil)
  (setq av-values (av-bench--range-list (length av-indices)))
  (setq av-list (av-bench--list-clone av-list))
  (setq av-start (av-bench--now-ms))
  (setq av-index-rest av-indices)
  (setq av-value-rest av-values)
  (while av-index-rest
    (setq av-list (av-bench--list-set-at av-list (car av-index-rest) (car av-value-rest)))
    (setq av-index-rest (cdr av-index-rest))
    (setq av-value-rest (cdr av-value-rest)))
  (av-bench--emit "list-set-at" (length av-list) (length av-indices)
                  (av-bench--elapsed-ms av-start) nil))

(defun av-bench--bench-stack (vv-vec vv-iterations / vv-size vv-list vv-start vv-index vv-result)
  (setq vv-size (av-length vv-vec))
  (setq vv-vec (av-bench--vector-clone vv-vec))
  (av--putprop vv-vec 0 'av-fill-pointer)
  (autolisp-log-out
    (strcat "BENCH stack-begin size=" (itoa vv-size)
            " iterations=" (itoa vv-iterations)))
  (setq vv-start (av-bench--now-ms))
  (setq vv-index 0)
  (while (< vv-index vv-iterations)
    (autolisp-log-out
      (strcat "BENCH stack-push index=" (itoa vv-index)
              " fill-pointer=" (vl-princ-to-string (av-fill-pointer vv-vec))))
    (setq vv-result
          (vl-catch-all-apply 'av-vector-push (list vv-index vv-vec)))
    (if (vl-catch-all-error-p vv-result)
      (progn
        (autolisp-log-err
          (strcat "ERROR stack push index="
                  (itoa vv-index)
                  " message="
                  (vl-princ-to-string
                    (vl-catch-all-error-message vv-result))))
        (error "stack push failed")))
    (setq vv-index (1+ vv-index)))
  (while (> vv-index 0)
    (autolisp-log-out
      (strcat "BENCH stack-pop index=" (itoa vv-index)
              " fill-pointer=" (vl-princ-to-string (av-fill-pointer vv-vec))))
    (setq vv-result
          (vl-catch-all-apply 'av-vector-pop (list vv-vec)))
    (if (vl-catch-all-error-p vv-result)
      (progn
        (autolisp-log-err
          (strcat "ERROR stack pop index="
                  (itoa vv-index)
                  " message="
                  (vl-princ-to-string
                    (vl-catch-all-error-message vv-result))))
        (error "stack pop failed")))
    (setq vv-index (1- vv-index)))
  (av-bench--emit "av-vector-push-pop" vv-size vv-iterations
                  (av-bench--elapsed-ms vv-start) nil)
  (setq vv-list nil)
  (setq vv-start (av-bench--now-ms))
  (setq vv-index 0)
  (while (< vv-index vv-iterations)
    (setq vv-list (cons vv-index vv-list))
    (setq vv-index (1+ vv-index)))
  (while vv-list
    (setq vv-list (cdr vv-list)))
  (av-bench--emit "cons-cdr" vv-size vv-iterations
                  (av-bench--elapsed-ms vv-start) nil))

(defun av-bench--bench-subseq (av-vec av-list av-start av-end av-iterations
                                / av-begin av-i)
  (setq av-begin (av-bench--now-ms))
  (setq av-i 0)
  (while (< av-i av-iterations)
    (av-subseq av-vec av-start av-end)
    (setq av-i (1+ av-i)))
  (av-bench--emit "av-subseq" (av-length av-vec) av-iterations
                  (av-bench--elapsed-ms av-begin)
                  (strcat "span=" (itoa (- av-end av-start))))
  (setq av-begin (av-bench--now-ms))
  (setq av-i 0)
  (while (< av-i av-iterations)
    (av-bench--list-subseq av-list av-start av-end)
    (setq av-i (1+ av-i)))
  (av-bench--emit "list-subseq" (length av-list) av-iterations
                  (av-bench--elapsed-ms av-begin)
                  (strcat "span=" (itoa (- av-end av-start)))))

(defun av-bench--bench-replace (av-vec av-list av-start av-end av-iterations
                                 / av-replacement av-begin av-i av-work-vec av-work-list)
  (setq av-replacement (av-bench--range-list (- av-end av-start)))
  (setq av-begin (av-bench--now-ms))
  (setq av-i 0)
  (while (< av-i av-iterations)
    (setq av-work-vec (av-bench--vector-clone av-vec))
    (av-replace av-work-vec av-replacement av-start av-end 0 nil)
    (setq av-i (1+ av-i)))
  (av-bench--emit "av-replace-mid" (av-length av-vec) av-iterations
                  (av-bench--elapsed-ms av-begin)
                  (strcat "span=" (itoa (- av-end av-start))))
  (setq av-begin (av-bench--now-ms))
  (setq av-i 0)
  (while (< av-i av-iterations)
    (setq av-work-list
          (av-bench--list-replace-range av-list av-start av-end av-replacement))
    (setq av-i (1+ av-i)))
  (av-bench--emit "list-replace-mid" (length av-list) av-iterations
                  (av-bench--elapsed-ms av-begin)
                  (strcat "span=" (itoa (- av-end av-start)))))

(defun av-bench--run-for-size (av-size av-samples / av-vec av-list av-indices
                                       av-middle-start av-middle-end
                                       av-mid-iters av-stack-iters)
  (setq av-list (av-bench--range-list av-size))
  (setq av-vec (av-make-array av-size nil av-list nil))
  (setq av-indices (av-bench--random-indices av-samples av-size))
  (setq av-middle-start (fix (/ av-size 4)))
  (setq av-middle-end (+ av-middle-start (av-bench--max2 1 (fix (/ av-size 2)))))
  (setq av-mid-iters
        (av-bench--max2 1
                        (av-bench--min2 100
                                        (fix (/ 50000 av-size)))))
  (setq av-stack-iters
        (av-bench--max2 1
                        (av-bench--min2 av-size 1000)))
  (autolisp-log-out
    (strcat "BENCH-SIZE size=" (itoa av-size)
            " samples=" (itoa av-samples)
            " slice-iterations=" (itoa av-mid-iters)
            " stack-iterations=" (itoa av-stack-iters)))
  (av-bench--call "length"
                  'av-bench--bench-length
                  (list av-vec av-list av-samples))
  (av-bench--call "read"
                  'av-bench--bench-read
                  (list av-vec av-list av-indices))
  (av-bench--call "write"
                  'av-bench--bench-write
                  (list av-vec av-list av-indices))
  (av-bench--call "stack"
                  'av-bench--bench-stack
                  (list av-vec av-stack-iters))
  (av-bench--call "subseq"
                  'av-bench--bench-subseq
                  (list av-vec av-list av-middle-start av-middle-end av-mid-iters))
  (av-bench--call "replace"
                  'av-bench--bench-replace
                  (list av-vec av-list av-middle-start av-middle-end av-mid-iters)))

(defun av-run-benchmarks (/ av-samples)
  (setq av-bench-results nil)
  (setq av-samples (av-bench--samples))
  (autolisp-log-out
    (strcat "BENCH-BEGIN samples=" (itoa av-samples)))
  (foreach av-size (av-bench--sizes)
    (av-bench--run-for-size av-size av-samples))
  (av-bench--print-table)
  (autolisp-log-out "BENCH-END")
  T)

(princ "")
