;;; autolisp-hash-table.lsp --- Hash tables inspired by Common Lisp

(vl-load-com)

;;; Public API:
;;;   ah-make-hash-table
;;;   ah-hash-table-p
;;;   ah-hash-table-count
;;;   ah-hash-table-size
;;;   ah-hash-table-test
;;;   ah-hash-table-rehash-threshold
;;;   ah-gethash
;;;   ah-puthash
;;;   ah-remhash
;;;   ah-clrhash
;;;   ah-maphash
;;;   ah-sxhash

(setq ah-*gethash-found-p* nil)
(setq ah-*remhash-found-p* nil)

(defun ah--property-alist-p (ah-data / ah-rest ah-valid)
  (setq ah-rest ah-data)
  (setq ah-valid T)
  (while (and ah-valid
              ah-rest
              (= (type ah-rest) 'LIST))
    (if (/= (type (car ah-rest)) 'LIST)
      (setq ah-valid nil)
      (setq ah-rest (cdr ah-rest))))
  (and ah-valid (null ah-rest)))

(defun ah--symbol-data (ah-symbol / ah-data)
  (setq ah-data
        (if (boundp ah-symbol)
          (vl-symbol-value ah-symbol)
          nil))
  (if (ah--property-alist-p ah-data)
    ah-data
    nil))

(defun ah--getprop (ah-symbol ah-prop / ah-data)
  (setq ah-data (ah--symbol-data ah-symbol))
  (cdr (assoc ah-prop ah-data)))

(defun ah--putprop (ah-symbol ah-value ah-prop / ah-data ah-cell)
  (setq ah-data (ah--symbol-data ah-symbol))
  (setq ah-cell (assoc ah-prop ah-data))
  (if ah-cell
    (set ah-symbol
         (subst (cons ah-prop ah-value) ah-cell ah-data))
    (set ah-symbol
         (cons (cons ah-prop ah-value) ah-data)))
  ah-value)

(defun ah--error (ah-message)
  (error (strcat "ah-hash-table: " ah-message)))

(defun ah--integerp (ah-value)
  (and (numberp ah-value)
       (= ah-value (fix ah-value))))

(defun ah--ensure-integer (ah-value ah-label)
  (if (not (ah--integerp ah-value))
    (ah--error
      (strcat ah-label " must be an integer, got "
              (vl-princ-to-string ah-value))))
  ah-value)

(defun ah--ensure-positive-integer (ah-value ah-label)
  (ah--ensure-integer ah-value ah-label)
  (if (<= ah-value 0)
    (ah--error
      (strcat ah-label " must be > 0, got "
              (itoa ah-value))))
  ah-value)

(defun ah--ensure-real (ah-value ah-label)
  (if (not (numberp ah-value))
    (ah--error
      (strcat ah-label " must be numeric, got "
              (vl-princ-to-string ah-value))))
  ah-value)

(defun ah--next-id (/ ah-counter)
  (setq ah-counter
        (1+ (cond ((ah--getprop 'ah-state 'ah-counter))
                  (t 0))))
  (ah--putprop 'ah-state ah-counter 'ah-counter)
  ah-counter)

(defun ah--make-symbol (ah-prefix / ah-name)
  (setq ah-name (strcat ah-prefix (itoa (ah--next-id))))
  (read ah-name))

(defun ah--make-table-symbol (/ ah-table)
  (setq ah-table (ah--make-symbol "ah-hash-table-"))
  (ah--putprop ah-table 'ah-hash-table 'ah-kind)
  ah-table)

(defun ah--modulus ()
  2147483647)

(defun ah--mix (ah-hash ah-value)
  (rem (+ (* ah-hash 65599) ah-value 17)
       (ah--modulus)))

(defun ah--type-tag (ah-value)
  (cond
    ((null ah-value) 11)
    ((= (type ah-value) 'INT) 23)
    ((= (type ah-value) 'REAL) 37)
    ((= (type ah-value) 'STR) 53)
    ((= (type ah-value) 'SYM) 71)
    ((listp ah-value) 89)
    (t 107)))

(defun ah--string-hash (ah-string / ah-index ah-length ah-hash)
  (setq ah-index 1)
  (setq ah-length (strlen ah-string))
  (setq ah-hash 216613)
  (while (<= ah-index ah-length)
    (setq ah-hash
          (ah--mix ah-hash
                   (ascii (substr ah-string ah-index 1))))
    (setq ah-index (1+ ah-index)))
  ah-hash)

(defun ah--symbol-name (ah-symbol)
  (if (= (type ah-symbol) 'SYM)
    (vl-symbol-name ah-symbol)
    (vl-princ-to-string ah-symbol)))

(defun ah--real-string (ah-value)
  (vl-princ-to-string ah-value))

(defun ah--cons-hash (ah-value ah-test / ah-hash)
  (setq ah-hash 131)
  (setq ah-hash (ah--mix ah-hash (ah--sxhash-internal (car ah-value) ah-test)))
  (setq ah-hash (ah--mix ah-hash 149))
  (setq ah-hash (ah--mix ah-hash (ah--sxhash-internal (cdr ah-value) ah-test)))
  ah-hash)

(defun ah--sxhash-internal (ah-value ah-test / ah-hash)
  (setq ah-hash (ah--type-tag ah-value))
  (cond
    ((null ah-value)
     ah-hash)
    ((= (type ah-value) 'INT)
     (ah--mix ah-hash (abs ah-value)))
    ((= (type ah-value) 'REAL)
     (ah--mix ah-hash (ah--string-hash (ah--real-string ah-value))))
    ((= (type ah-value) 'STR)
     (ah--mix ah-hash (ah--string-hash ah-value)))
    ((= (type ah-value) 'SYM)
     (ah--mix ah-hash (ah--string-hash (ah--symbol-name ah-value))))
    ((listp ah-value)
     (ah--mix ah-hash (ah--cons-hash ah-value ah-test)))
    (t
     (ah--mix ah-hash (ah--string-hash (vl-princ-to-string ah-value))))))

(defun ah-sxhash (ah-value ah-test)
  (setq ah-test (if ah-test ah-test 'equal))
  (abs (ah--sxhash-internal ah-value ah-test)))

(defun ah--equal-by-test (ah-left ah-right ah-test)
  (cond
    ((eq ah-test 'eq)
     (eq ah-left ah-right))
    ((eq ah-test 'equal)
     (equal ah-left ah-right))
    (t
     (ah--error
       (strcat "unsupported hash-table test "
               (vl-princ-to-string ah-test))))))

(defun ah--prime-table ()
  '(5 11 23 47 97 197 397 797 1597 3203 6421 12853 25717 51437 102877 205759))

(defun ah--prime-count (ah-primes / ah-count)
  (setq ah-count 0)
  (while ah-primes
    (setq ah-count (1+ ah-count))
    (setq ah-primes (cdr ah-primes)))
  ah-count)

(defun ah--prime-nth (ah-primes ah-index)
  (while (> ah-index 0)
    (setq ah-primes (cdr ah-primes))
    (setq ah-index (1- ah-index)))
  (car ah-primes))

(defun ah--next-prime (ah-size / ah-primes ah-low ah-high ah-mid ah-candidate)
  (setq ah-primes (ah--prime-table))
  (setq ah-low 0)
  (setq ah-high (1- (ah--prime-count ah-primes)))
  (while (<= ah-low ah-high)
    (setq ah-mid (fix (/ (+ ah-low ah-high) 2)))
    (setq ah-candidate (ah--prime-nth ah-primes ah-mid))
    (if (< ah-candidate ah-size)
      (setq ah-low (1+ ah-mid))
      (setq ah-high (1- ah-mid))))
  (if (< ah-low (ah--prime-count ah-primes))
    (ah--prime-nth ah-primes ah-low)
    (ah--error "prime table exhausted")))

(defun ah--make-slot-vector (ah-size ah-empty-marker)
  (av-make-array ah-size ah-empty-marker nil nil))

(defun ah--make-entry (ah-hash ah-key ah-value)
  (list 'ah-entry ah-hash ah-key ah-value))

(defun ah--entry-p (ah-slot)
  (and (listp ah-slot)
       ah-slot
       (eq (car ah-slot) 'ah-entry)))

(defun ah--entry-hash (ah-entry)
  (cadr ah-entry))

(defun ah--entry-key (ah-entry)
  (caddr ah-entry))

(defun ah--entry-value (ah-entry)
  (cadddr ah-entry))

(defun ah--require-hash-table (ah-table)
  (if (not (ah-hash-table-p ah-table))
    (ah--error
      (strcat "expected ah-hash-table, got "
              (vl-princ-to-string ah-table))))
  ah-table)

(defun ah-hash-table-p (ah-object)
  (and (= (type ah-object) 'SYM)
       (eq (ah--getprop ah-object 'ah-kind) 'ah-hash-table)))

(defun ah-hash-table-count (ah-table)
  (ah--require-hash-table ah-table)
  (ah--getprop ah-table 'ah-count))

(defun ah-hash-table-size (ah-table)
  (ah--require-hash-table ah-table)
  (ah--getprop ah-table 'ah-size))

(defun ah-hash-table-test (ah-table)
  (ah--require-hash-table ah-table)
  (ah--getprop ah-table 'ah-test))

(defun ah-hash-table-rehash-threshold (ah-table)
  (ah--require-hash-table ah-table)
  (ah--getprop ah-table 'ah-rehash-threshold))

(defun ah--deleted-count (ah-table)
  (ah--getprop ah-table 'ah-deleted-count))

(defun ah--set-deleted-count (ah-table ah-count)
  (ah--putprop ah-table ah-count 'ah-deleted-count))

(defun ah--load-threshold-count (ah-size ah-threshold)
  (fix (* ah-size ah-threshold)))

(defun ah--should-grow-p (ah-table / ah-size ah-threshold ah-active ah-deleted ah-load)
  (setq ah-size (ah-hash-table-size ah-table))
  (setq ah-threshold (ah-hash-table-rehash-threshold ah-table))
  (setq ah-active (ah-hash-table-count ah-table))
  (setq ah-deleted (ah--deleted-count ah-table))
  (setq ah-load (+ ah-active ah-deleted))
  (>= ah-load (ah--load-threshold-count ah-size ah-threshold)))

(defun ah--slot-vector (ah-table)
  (ah--getprop ah-table 'ah-slots))

(defun ah--empty-marker (ah-table)
  (ah--getprop ah-table 'ah-empty-marker))

(defun ah--deleted-marker (ah-table)
  (ah--getprop ah-table 'ah-deleted-marker))

(defun ah--find-slot (ah-table ah-key ah-hash / ah-size ah-slots ah-empty ah-deleted ah-index ah-step ah-slot ah-first-deleted)
  (setq ah-size (ah-hash-table-size ah-table))
  (setq ah-slots (ah--slot-vector ah-table))
  (setq ah-empty (ah--empty-marker ah-table))
  (setq ah-deleted (ah--deleted-marker ah-table))
  (setq ah-index (rem ah-hash ah-size))
  (setq ah-step 0)
  (setq ah-first-deleted nil)
  (while (< ah-step ah-size)
    (setq ah-slot (av-aref ah-slots ah-index))
    (cond
      ((eq ah-slot ah-empty)
       (if ah-first-deleted
         (setq ah-index ah-first-deleted))
       (setq ah-step ah-size))
      ((eq ah-slot ah-deleted)
       (if (null ah-first-deleted)
         (setq ah-first-deleted ah-index)))
      ((and (ah--entry-p ah-slot)
            (= (ah--entry-hash ah-slot) ah-hash)
            (ah--equal-by-test (ah--entry-key ah-slot)
                               ah-key
                               (ah-hash-table-test ah-table)))
       (setq ah-step ah-size))
      (T
       nil))
    (if (< ah-step ah-size)
      (progn
        (setq ah-index (rem (1+ ah-index) ah-size))
        (setq ah-step (1+ ah-step)))))
  ah-index)

(defun ah--rehash-min-size (ah-table / ah-current ah-factor)
  (setq ah-current (ah-hash-table-size ah-table))
  (setq ah-factor (ah--getprop ah-table 'ah-rehash-size))
  (fix (+ 1 (* ah-current ah-factor))))

(defun ah--all-entries (ah-table / ah-slots ah-size ah-index ah-out ah-slot)
  (setq ah-slots (ah--slot-vector ah-table))
  (setq ah-size (ah-hash-table-size ah-table))
  (setq ah-index 0)
  (setq ah-out nil)
  (while (< ah-index ah-size)
    (setq ah-slot (av-aref ah-slots ah-index))
    (if (ah--entry-p ah-slot)
      (setq ah-out (cons ah-slot ah-out)))
    (setq ah-index (1+ ah-index)))
  (reverse ah-out))

(defun ah--insert-entry-no-grow (ah-table ah-entry / ah-index ah-slots ah-slot)
  (setq ah-slots (ah--slot-vector ah-table))
  (setq ah-index (ah--find-slot ah-table
                                (ah--entry-key ah-entry)
                                (ah--entry-hash ah-entry)))
  (setq ah-slot (av-aref ah-slots ah-index))
  (cond
    ((eq ah-slot (ah--deleted-marker ah-table))
     (ah--set-deleted-count ah-table (1- (ah--deleted-count ah-table)))
     (av-set-aref ah-slots ah-index ah-entry)
     (ah--putprop ah-table (1+ (ah-hash-table-count ah-table)) 'ah-count))
    ((ah--entry-p ah-slot)
     (av-set-aref ah-slots ah-index ah-entry))
    (T
     (av-set-aref ah-slots ah-index ah-entry)
     (ah--putprop ah-table (1+ (ah-hash-table-count ah-table)) 'ah-count)))
  ah-entry)

(defun ah--rehash (ah-table ah-new-min-size / ah-entries ah-size ah-slots)
  (setq ah-entries (ah--all-entries ah-table))
  (setq ah-size (ah--next-prime ah-new-min-size))
  (setq ah-slots (ah--make-slot-vector ah-size (ah--empty-marker ah-table)))
  (ah--putprop ah-table ah-size 'ah-size)
  (ah--putprop ah-table ah-slots 'ah-slots)
  (ah--putprop ah-table 0 'ah-count)
  (ah--set-deleted-count ah-table 0)
  (foreach ah-entry ah-entries
    (ah--insert-entry-no-grow ah-table ah-entry))
  ah-table)

(defun ah-make-hash-table (ah-test ah-size ah-rehash-size ah-rehash-threshold
                            / ah-table ah-empty ah-deleted ah-capacity ah-slots)
  (setq ah-test (if ah-test ah-test 'equal))
  (if (and (not (eq ah-test 'eq))
           (not (eq ah-test 'equal)))
    (ah--error "supported tests are eq and equal"))
  (setq ah-size (if ah-size ah-size 5))
  (setq ah-rehash-size (if ah-rehash-size ah-rehash-size 2.0))
  (setq ah-rehash-threshold (if ah-rehash-threshold ah-rehash-threshold 0.5))
  (ah--ensure-positive-integer ah-size "size")
  (ah--ensure-real ah-rehash-size "rehash-size")
  (ah--ensure-real ah-rehash-threshold "rehash-threshold")
  (if (or (<= ah-rehash-threshold 0.0)
          (>= ah-rehash-threshold 1.0))
    (ah--error "rehash-threshold must be > 0 and < 1"))
  (setq ah-table (ah--make-table-symbol))
  (setq ah-empty (ah--make-symbol "ah-empty-"))
  (setq ah-deleted (ah--make-symbol "ah-deleted-"))
  (setq ah-capacity (ah--next-prime ah-size))
  (setq ah-slots (ah--make-slot-vector ah-capacity ah-empty))
  (ah--putprop ah-table ah-test 'ah-test)
  (ah--putprop ah-table 0 'ah-count)
  (ah--putprop ah-table 0 'ah-deleted-count)
  (ah--putprop ah-table ah-capacity 'ah-size)
  (ah--putprop ah-table ah-rehash-size 'ah-rehash-size)
  (ah--putprop ah-table ah-rehash-threshold 'ah-rehash-threshold)
  (ah--putprop ah-table ah-slots 'ah-slots)
  (ah--putprop ah-table ah-empty 'ah-empty-marker)
  (ah--putprop ah-table ah-deleted 'ah-deleted-marker)
  ah-table)

(defun ah-gethash (ah-table ah-key ah-default / ah-hash ah-index ah-slot)
  (ah--require-hash-table ah-table)
  (setq ah-hash (ah-sxhash ah-key (ah-hash-table-test ah-table)))
  (setq ah-index (ah--find-slot ah-table ah-key ah-hash))
  (setq ah-slot (av-aref (ah--slot-vector ah-table) ah-index))
  (if (ah--entry-p ah-slot)
    (progn
      (setq ah-*gethash-found-p* T)
      (ah--entry-value ah-slot))
    (progn
      (setq ah-*gethash-found-p* nil)
      ah-default)))

(defun ah-puthash (ah-table ah-key ah-value / ah-hash ah-entry)
  (ah--require-hash-table ah-table)
  (if (ah--should-grow-p ah-table)
    (ah--rehash ah-table (ah--rehash-min-size ah-table)))
  (setq ah-hash (ah-sxhash ah-key (ah-hash-table-test ah-table)))
  (setq ah-entry (ah--make-entry ah-hash ah-key ah-value))
  (ah--insert-entry-no-grow ah-table ah-entry)
  ah-value)

(defun ah-remhash (ah-table ah-key / ah-hash ah-index ah-slots ah-slot)
  (ah--require-hash-table ah-table)
  (setq ah-hash (ah-sxhash ah-key (ah-hash-table-test ah-table)))
  (setq ah-index (ah--find-slot ah-table ah-key ah-hash))
  (setq ah-slots (ah--slot-vector ah-table))
  (setq ah-slot (av-aref ah-slots ah-index))
  (if (ah--entry-p ah-slot)
    (progn
      (setq ah-*remhash-found-p* T)
      (av-set-aref ah-slots ah-index (ah--deleted-marker ah-table))
      (ah--putprop ah-table (1- (ah-hash-table-count ah-table)) 'ah-count)
      (ah--set-deleted-count ah-table (1+ (ah--deleted-count ah-table)))
      (ah--entry-value ah-slot))
    (progn
      (setq ah-*remhash-found-p* nil)
      nil)))

(defun ah-clrhash (ah-table / ah-size ah-slots ah-index)
  (ah--require-hash-table ah-table)
  (setq ah-size (ah-hash-table-size ah-table))
  (setq ah-slots (ah--make-slot-vector ah-size (ah--empty-marker ah-table)))
  (ah--putprop ah-table ah-slots 'ah-slots)
  (ah--putprop ah-table 0 'ah-count)
  (ah--set-deleted-count ah-table 0)
  ah-table)

(defun ah-maphash (ah-function ah-table / ah-slots ah-size ah-index ah-slot)
  (ah--require-hash-table ah-table)
  (setq ah-slots (ah--slot-vector ah-table))
  (setq ah-size (ah-hash-table-size ah-table))
  (setq ah-index 0)
  (while (< ah-index ah-size)
    (setq ah-slot (av-aref ah-slots ah-index))
    (if (ah--entry-p ah-slot)
      (apply ah-function (list (ah--entry-key ah-slot) (ah--entry-value ah-slot))))
    (setq ah-index (1+ ah-index)))
  ah-table)

(princ "")
