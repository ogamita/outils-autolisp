;;; vector-tests.lsp --- Tests for autolisp-vector

(defsuite "autolisp-vector")
(in-suite "autolisp-vector")

(deftest
  "make-array allocates all slots"
  (function
    (lambda (/ av-vector)
      (setq av-vector (av-make-array 4 0 nil 0))
      (is (av-vector-p av-vector))
      (is (av-vectorp av-vector))
      (is (av-arrayp av-vector))
      (is-equal 4 (av-length av-vector))
      (is-equal 4 (av-vector-length av-vector))
      (is-equal 4 (av-array-total-size av-vector))
      (is-equal 0 (av-fill-pointer av-vector))
      (is-not (av-adjustable-array-p av-vector))
      (is-equal '(0 0 0 0) (av-to-list av-vector)))))

(deftest
  "initial-contents populate the vector"
  (function
    (lambda (/ av-vector)
      (setq av-vector (av-make-array 4 nil '(1 2 3 4) nil))
      (is-equal '(1 2 3 4) (av-to-list av-vector))
      (is-equal 3 (av-aref av-vector 2)))))

(deftest
  "metadata are readable from internal symbol storage"
  (function
    (lambda (/ av-vector av-same-depth av-root av-path-table)
      (setq av-vector (av-make-array 4 nil '(1 2 3 4) 0))
      (setq av-same-depth (av-make-array 3 nil '(7 8 9) nil))
      (setq av-root (av--getprop av-vector 'av-root))
      (setq av-path-table (av--getprop av-vector 'av-path-table))
      (is-equal 'av-vector (av--getprop av-vector 'av-kind))
      (is-equal 4 (av--getprop av-vector 'av-length))
      (is-equal 2 (av--getprop av-vector 'av-height))
      (is-equal 0 (av--getprop av-vector 'av-fill-pointer))
      (is av-root)
      (is av-path-table)
      (is-equal 8 (strlen av-path-table))
      (is-equal av-path-table (av--getprop av-same-depth 'av-path-table))
      (is-equal 1 (av-aref av-vector 0))
      (is-equal 4 (av-aref av-vector 3)))))

(deftest
  "internal metadata helpers ignore malformed symbol values"
  (function
    (lambda (/ av-bad-symbol)
      (setq av-bad-symbol (read "av-bad-metadata-symbol"))
      (set av-bad-symbol (cons 0 0))
      (is-equal nil (av--getprop av-bad-symbol 'av-kind))
      (is-equal 7 (av--putprop av-bad-symbol 7 'av-length))
      (is-equal 7 (av--getprop av-bad-symbol 'av-length)))))

(deftest
  "set-aref mutates one slot"
  (function
    (lambda (/ av-vector)
      (setq av-vector (av-make-array 3 nil '(10 20 30) nil))
      (av-set-aref av-vector 1 99)
      (is-equal '(10 99 30) (av-to-list av-vector)))))

(deftest
  "replace accepts list and vector sources"
  (function
    (lambda (/ av-vector av-source)
      (setq av-vector (av-make-array 5 0 nil nil))
      (av-replace av-vector '(1 2 3) 1 4 0 3)
      (is-equal '(0 1 2 3 0) (av-to-list av-vector))
      (setq av-source (av-make-array 2 nil '(8 9) nil))
      (av-replace av-vector av-source 3 5 0 2)
      (is-equal '(0 1 2 8 9) (av-to-list av-vector)))))

(deftest
  "subseq returns a new vector"
  (function
    (lambda (/ av-vector av-slice)
      (setq av-vector (av-make-array 5 nil '(5 6 7 8 9) nil))
      (setq av-slice (av-subseq av-vector 1 4))
      (is (av-vector-p av-slice))
      (is-equal '(6 7 8) (av-to-list av-slice))
      (av-set-aref av-slice 0 42)
      (is-equal '(5 6 7 8 9) (av-to-list av-vector)))))

(deftest
  "vector push and pop use the fill-pointer"
  (function
    (lambda (/ av-vector)
      (setq av-vector (av-make-array 3 nil nil 0))
      (is-equal 0 (av-vector-push 'a av-vector))
      (is-equal 1 (av-vector-push 'b av-vector))
      (is-equal 2 (av-fill-pointer av-vector))
      (is-equal 'b (av-vector-pop av-vector))
      (is-equal 1 (av-fill-pointer av-vector)))))

(deftest
  "printer uses Common Lisp vector syntax"
  (function
    (lambda (/ av-vector)
      (setq av-vector (av-make-array 4 nil '(1 2 3 4) nil))
      (is-equal "#(1 2 3 4)" (av-vector-string av-vector))
      (is-equal av-vector (av-print-vector av-vector)))))

(deftest
  "replace defaults copy the full sequence"
  (function
    (lambda (/ av-vector)
      (setq av-vector (av-make-array 3 0 nil nil))
      (is-equal av-vector (av-replace av-vector '(7 8 9) nil nil nil nil))
      (is-equal '(7 8 9) (av-to-list av-vector)))))

(deftest
  "subseq default end goes to vector length"
  (function
    (lambda (/ av-vector av-slice)
      (setq av-vector (av-make-array 4 nil '(3 4 5 6) nil))
      (setq av-slice (av-subseq av-vector 2 nil))
      (is-equal '(5 6) (av-to-list av-slice)))))

(deftest
  "copy-vector duplicates the full vector"
  (function
    (lambda (/ av-vector av-copy)
      (setq av-vector (av-make-array 4 nil '(9 8 7 6) nil))
      (setq av-copy (av-copy-vector av-vector))
      (is (av-vector-p av-copy))
      (is-equal '(9 8 7 6) (av-to-list av-copy))
      (av-set-aref av-copy 0 42)
      (is-equal '(9 8 7 6) (av-to-list av-vector)))))

(deftest
  "copy-vector preserves fill-pointer"
  (function
    (lambda (/ av-vector av-copy)
      (setq av-vector (av-make-array 4 nil '(1 2 3 4) 2))
      (setq av-copy (av-copy-vector av-vector))
      (is-equal 2 (av-fill-pointer av-copy))
      (is-equal '(1 2 3 4) (av-to-list av-copy)))))

(deftest
  "bounds are checked"
  (function
    (lambda (/ av-vector)
      (setq av-vector (av-make-array 2 nil '(1 2) nil))
      (signals-error (function (lambda () (av-aref av-vector 2))))
      (signals-error (function (lambda () (av-set-aref av-vector -1 0)))))))
