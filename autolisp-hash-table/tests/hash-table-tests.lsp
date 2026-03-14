;;; hash-table-tests.lsp --- Tests for autolisp-hash-table

(defsuite "autolisp-hash-table")
(in-suite "autolisp-hash-table")

(deftest
  "make-hash-table creates an empty table"
  (function
    (lambda (/ ah-table)
      (setq ah-table (ah-make-hash-table 'equal 11 2.0 0.5))
      (is (ah-hash-table-p ah-table))
      (is-equal 0 (ah-hash-table-count ah-table))
      (is-equal 'equal (ah-hash-table-test ah-table))
      (is-equal 11 (ah-hash-table-size ah-table))
      (is-equal 0.5 (ah-hash-table-rehash-threshold ah-table)))))

(deftest
  "sxhash is stable for strings and symbols"
  (function
    (lambda ()
      (is-equal (ah-sxhash "abc" 'equal)
                (ah-sxhash "abc" 'equal))
      (is-equal (ah-sxhash 'foo 'equal)
                (ah-sxhash 'foo 'equal))
      (is (/= (ah-sxhash "abc" 'equal)
              (ah-sxhash "abd" 'equal))))))

(deftest
  "puthash inserts and gethash finds the value"
  (function
    (lambda (/ ah-table)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (is-equal 10 (ah-puthash ah-table "foo" 10))
      (is-equal 10 (ah-gethash ah-table "foo" nil))
      (is ah-*gethash-found-p*)
      (is-equal 1 (ah-hash-table-count ah-table)))))

(deftest
  "puthash replaces an existing binding"
  (function
    (lambda (/ ah-table)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (ah-puthash ah-table "foo" 10)
      (ah-puthash ah-table "foo" 20)
      (is-equal 20 (ah-gethash ah-table "foo" nil))
      (is ah-*gethash-found-p*)
      (is-equal 1 (ah-hash-table-count ah-table)))))

(deftest
  "gethash returns the provided default when absent"
  (function
    (lambda (/ ah-table)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (is-equal 'missing (ah-gethash ah-table "foo" 'missing))
      (is-not ah-*gethash-found-p*))))

(deftest
  "gethash distinguishes nil value from missing key"
  (function
    (lambda (/ ah-table)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (ah-puthash ah-table "foo" nil)
      (is-equal nil (ah-gethash ah-table "foo" 'missing))
      (is ah-*gethash-found-p*)
      (is-equal 'missing (ah-gethash ah-table "bar" 'missing))
      (is-not ah-*gethash-found-p*))))

(deftest
  "remhash removes an entry and returns the removed value"
  (function
    (lambda (/ ah-table)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (ah-puthash ah-table "foo" 10)
      (is-equal 10 (ah-remhash ah-table "foo"))
      (is ah-*remhash-found-p*)
      (is-equal nil (ah-gethash ah-table "foo" nil))
      (is-not ah-*gethash-found-p*)
      (is-equal 0 (ah-hash-table-count ah-table)))))

(deftest
  "remhash returns nil and clears found flag when absent"
  (function
    (lambda (/ ah-table)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (is-equal nil (ah-remhash ah-table "foo"))
      (is-not ah-*remhash-found-p*)
      (is-equal 0 (ah-hash-table-count ah-table)))))

(deftest
  "remhash distinguishes nil value from missing key"
  (function
    (lambda (/ ah-table)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (ah-puthash ah-table "foo" nil)
      (is-equal nil (ah-remhash ah-table "foo"))
      (is ah-*remhash-found-p*)
      (is-equal nil (ah-remhash ah-table "foo"))
      (is-not ah-*remhash-found-p*))))

(deftest
  "clrhash empties the table"
  (function
    (lambda (/ ah-table)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (ah-puthash ah-table "foo" 10)
      (ah-puthash ah-table "bar" 20)
      (is-equal ah-table (ah-clrhash ah-table))
      (is-equal 0 (ah-hash-table-count ah-table))
      (is-equal nil (ah-gethash ah-table "foo" nil))
      (is-not ah-*gethash-found-p*)
      (is-equal nil (ah-gethash ah-table "bar" nil))
      (is-not ah-*gethash-found-p*))))

(deftest
  "maphash visits all active entries"
  (function
    (lambda (/ ah-table ah-seen)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (setq ah-seen nil)
      (ah-puthash ah-table "foo" 10)
      (ah-puthash ah-table "bar" 20)
      (ah-maphash
        (function
          (lambda (k v)
            (setq ah-seen (cons (list k v) ah-seen))))
        ah-table)
      (is-equal 2 (length ah-seen))
      (is (member '("foo" 10) ah-seen))
      (is (member '("bar" 20) ah-seen)))))

(deftest
  "table grows when the load threshold is reached"
  (function
    (lambda (/ ah-table ah-size)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (setq ah-size (ah-hash-table-size ah-table))
      (ah-puthash ah-table "a" 1)
      (ah-puthash ah-table "b" 2)
      (ah-puthash ah-table "c" 3)
      (is (> (ah-hash-table-size ah-table) ah-size))
      (is-equal 1 (ah-gethash ah-table "a" nil))
      (is ah-*gethash-found-p*)
      (is-equal 2 (ah-gethash ah-table "b" nil))
      (is ah-*gethash-found-p*)
      (is-equal 3 (ah-gethash ah-table "c" nil))
      (is ah-*gethash-found-p*))))

(deftest
  "deleted slots are reused by later insertions"
  (function
    (lambda (/ ah-table ah-size)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.9))
      (setq ah-size (ah-hash-table-size ah-table))
      (ah-puthash ah-table "a" 1)
      (ah-puthash ah-table "b" 2)
      (ah-puthash ah-table "c" 3)
      (is-equal 2 (ah-remhash ah-table "b"))
      (is ah-*remhash-found-p*)
      (ah-puthash ah-table "d" 4)
      (is-equal ah-size (ah-hash-table-size ah-table))
      (is-equal 3 (ah-hash-table-count ah-table))
      (is-equal 4 (ah-gethash ah-table "d" nil))
      (is ah-*gethash-found-p*))))

(deftest
  "rehash preserves entries across prior deletions"
  (function
    (lambda (/ ah-table ah-size)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (setq ah-size (ah-hash-table-size ah-table))
      (ah-puthash ah-table "a" 1)
      (ah-puthash ah-table "b" 2)
      (ah-puthash ah-table "c" 3)
      (is-equal 2 (ah-remhash ah-table "b"))
      (is ah-*remhash-found-p*)
      (ah-puthash ah-table "d" 4)
      (ah-puthash ah-table "e" 5)
      (is (> (ah-hash-table-size ah-table) ah-size))
      (is-equal 1 (ah-gethash ah-table "a" nil))
      (is ah-*gethash-found-p*)
      (is-equal 3 (ah-gethash ah-table "c" nil))
      (is ah-*gethash-found-p*)
      (is-equal 4 (ah-gethash ah-table "d" nil))
      (is ah-*gethash-found-p*)
      (is-equal 5 (ah-gethash ah-table "e" nil))
      (is ah-*gethash-found-p*)
      (is-equal nil (ah-gethash ah-table "b" nil))
      (is-not ah-*gethash-found-p*))))

(deftest
  "larger rehash preserves all inserted entries"
  (function
    (lambda (/ ah-table ah-index ah-key)
      (setq ah-table (ah-make-hash-table 'equal 11 2.0 0.5))
      (setq ah-index 0)
      (while (< ah-index 20)
        (setq ah-key (strcat "k" (itoa ah-index)))
        (ah-puthash ah-table ah-key ah-index)
        (setq ah-index (1+ ah-index)))
      (setq ah-index 0)
      (while (< ah-index 20)
        (setq ah-key (strcat "k" (itoa ah-index)))
        (is-equal ah-index (ah-gethash ah-table ah-key nil))
        (is ah-*gethash-found-p*)
        (setq ah-index (1+ ah-index))))))

(deftest
  "equal test hashes structural keys compatibly"
  (function
    (lambda (/ ah-table ah-key)
      (setq ah-table (ah-make-hash-table 'equal 5 2.0 0.5))
      (setq ah-key '(1 2 (3 . 4)))
      (ah-puthash ah-table ah-key 'ok)
      (is-equal 'ok
                (ah-gethash ah-table '(1 2 (3 . 4)) nil))
      (is ah-*gethash-found-p*))))

(deftest
  "eq tables compare by eq semantics"
  (function
    (lambda (/ ah-table ah-key)
      (setq ah-table (ah-make-hash-table 'eq 5 2.0 0.5))
      (setq ah-key (list 'x 'y))
      (ah-puthash ah-table ah-key 'ok)
      (is-equal 'ok (ah-gethash ah-table ah-key nil))
      (is ah-*gethash-found-p*)
      (is-equal nil (ah-gethash ah-table (list 'x 'y) nil))
      (is-not ah-*gethash-found-p*))))
