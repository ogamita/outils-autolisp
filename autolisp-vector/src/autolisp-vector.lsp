;;; autolisp-vector.lsp --- Tree-backed vector implementation for AutoLISP

(vl-load-com)

;;; Public API:
;;;   av-make-array
;;;   av-vector
;;;   av-vector-p
;;;   av-vectorp
;;;   av-arrayp
;;;   av-length
;;;   av-vector-length
;;;   av-array-total-size
;;;   av-adjustable-array-p
;;;   av-fill-pointer
;;;   av-set-fill-pointer
;;;   av-aref
;;;   av-svref
;;;   av-set-aref
;;;   av-replace
;;;   av-subseq
;;;   av-copy-vector
;;;   av-vector-push
;;;   av-vector-pop
;;;   av-to-list
;;;   av-vector-string
;;;   av-print-vector

(defun av--property-alist-p (av-data / av-rest av-valid)
  (setq av-rest av-data)
  (setq av-valid T)
  (while (and av-valid
              av-rest
              (= (type av-rest) 'LIST))
    (if (/= (type (car av-rest)) 'LIST)
      (setq av-valid nil)
      (setq av-rest (cdr av-rest))))
  (and av-valid (null av-rest)))

(defun av--symbol-data (av-symbol / av-data)
  (setq av-data
        (if (boundp av-symbol)
          (vl-symbol-value av-symbol)
          nil))
  (if (av--property-alist-p av-data)
    av-data
    nil))

(defun av--getprop (av-symbol av-prop / av-data)
  (setq av-data (av--symbol-data av-symbol))
  (cdr (assoc av-prop av-data)))

(defun av--putprop (av-symbol av-value av-prop / av-data av-cell)
  (setq av-data (av--symbol-data av-symbol))
  (setq av-cell (assoc av-prop av-data))
  (if av-cell
    (set av-symbol
         (subst (cons av-prop av-value) av-cell av-data))
    (set av-symbol
         (cons (cons av-prop av-value) av-data)))
  av-value)

(defun av--error (av-message)
  (error (strcat "av-vector: " av-message)))

(defun av--integerp (av-value)
  (and (numberp av-value)
       (= av-value (fix av-value))))

(defun av--ensure-integer (av-value av-label)
  (if (not (av--integerp av-value))
    (av--error
      (strcat av-label " must be an integer, got "
              (vl-princ-to-string av-value))))
  av-value)

(defun av--ensure-nonnegative-integer (av-value av-label)
  (av--ensure-integer av-value av-label)
  (if (< av-value 0)
    (av--error
      (strcat av-label " must be >= 0, got "
              (itoa av-value))))
  av-value)

(defun av--ensure-symbol (av-value av-label)
  (if (/= (type av-value) 'SYM)
    (av--error
      (strcat av-label " must be a symbol, got "
              (vl-princ-to-string av-value))))
  av-value)

(defun av--next-id (/ av-counter)
  (setq av-counter
        (1+ (cond ((av--getprop 'av-state 'av-counter))
                  (t 0))))
  (av--putprop 'av-state av-counter 'av-counter)
  av-counter)

(defun av--make-symbol (av-prefix / av-name)
  (setq av-name (strcat av-prefix (itoa (av--next-id))))
  (read av-name))

(defun av--power-of-two (av-depth / av-value)
  (setq av-value 1)
  (while (> av-depth 0)
    (setq av-value (* 2 av-value))
    (setq av-depth (1- av-depth)))
  av-value)

(defun av--path-entry-insert (av-entry av-entries / av-depth av-output av-inserted)
  (setq av-depth (car av-entry))
  (setq av-output nil)
  (setq av-inserted nil)
  (while av-entries
    (if (and (not av-inserted)
             (< av-depth (caar av-entries)))
      (progn
        (setq av-output (cons av-entry av-output))
        (setq av-inserted T)))
    (setq av-output (cons (car av-entries) av-output))
    (setq av-entries (cdr av-entries)))
  (if (not av-inserted)
    (setq av-output (cons av-entry av-output)))
  (reverse av-output))

(defun av--build-path-table (av-depth / av-index av-limit av-step av-table av-char)
  (setq av-index 0)
  (setq av-limit (av--power-of-two av-depth))
  (setq av-table "")
  (while (< av-index av-limit)
    (setq av-step av-depth)
    (while (> av-step 0)
      (setq av-char
            (if (= 0 (rem (fix (/ av-index (av--power-of-two (1- av-step)))) 2))
              "a"
              "d"))
      (setq av-table (strcat av-table av-char))
      (setq av-step (1- av-step)))
    (setq av-index (1+ av-index)))
  av-table)

(defun av--path-table-for-depth (av-depth / av-tables av-entry av-table)
  (setq av-tables (av--getprop 'av-state 'av-path-tables))
  (setq av-entry (assoc av-depth av-tables))
  (if av-entry
    (cdr av-entry)
    (progn
      (setq av-table (av--build-path-table av-depth))
      (av--putprop 'av-state
                   (av--path-entry-insert (cons av-depth av-table) av-tables)
                   'av-path-tables)
      av-table)))

(defun av--depth-for-length (av-length / av-depth av-capacity)
  (setq av-depth 0)
  (setq av-capacity 1)
  (while (< av-capacity av-length)
    (setq av-capacity (* 2 av-capacity))
    (setq av-depth (1+ av-depth)))
  av-depth)

(defun av--build-tree (av-depth av-value)
  (if (<= av-depth 0)
    av-value
    (cons (av--build-tree (1- av-depth) av-value)
          (av--build-tree (1- av-depth) av-value))))

(defun av--tree-ref (av-node av-index av-depth av-path-table / av-step av-offset)
  (setq av-step 0)
  (setq av-offset (* av-index av-depth))
  (while (< av-step av-depth)
    (if (= "a" (substr av-path-table (+ av-offset av-step 1) 1))
      (setq av-node (car av-node))
      (setq av-node (cdr av-node)))
    (setq av-step (1+ av-step)))
  av-node)

(defun av--tree-set (av-node av-index av-depth av-path-table av-value / av-offset)
  (setq av-offset (* av-index av-depth))
  (av--tree-set-at-path av-node av-path-table av-offset 0 av-depth av-value))

(defun av--tree-set-at-path (av-node av-path-table av-offset av-step av-depth av-value)
  (if (<= av-depth 0)
    av-value
    (progn
      (if (= "a" (substr av-path-table (+ av-offset av-step 1) 1))
        (cons (av--tree-set-at-path (car av-node)
                                    av-path-table
                                    av-offset
                                    (1+ av-step)
                                    (1- av-depth)
                                    av-value)
              (cdr av-node))
        (cons (car av-node)
              (av--tree-set-at-path (cdr av-node)
                                    av-path-table
                                    av-offset
                                    (1+ av-step)
                                    (1- av-depth)
                                    av-value))))))

(defun av--make-array-from-list (vv-values vv-fill-ptr / vv-size vv-vec vv-root vv-depth vv-index vv-path-table)
  (setq vv-size (length vv-values))
  (setq vv-vec (av--make-vector-symbol))
  (setq vv-depth (av--depth-for-length vv-size))
  (setq vv-path-table (av--path-table-for-depth vv-depth))
  (setq vv-root
        (if (> vv-size 0)
          (av--build-tree vv-depth nil)
          nil))
  (setq vv-index 0)
  (foreach vv-value vv-values
    (setq vv-root (av--tree-set vv-root vv-index vv-depth vv-path-table vv-value))
    (setq vv-index (1+ vv-index)))
  (av--putprop vv-vec vv-size 'av-length)
  (av--putprop vv-vec 2 'av-branching-factor)
  (av--putprop vv-vec vv-depth 'av-height)
  (av--putprop vv-vec vv-path-table 'av-path-table)
  (av--putprop vv-vec vv-root 'av-root)
  (if (not (null vv-fill-ptr))
    (av--putprop vv-vec vv-fill-ptr 'av-fill-pointer))
  vv-vec)

(defun av--list-nth (av-list av-index / av-rest)
  (setq av-rest av-list)
  (while (> av-index 0)
    (setq av-rest (cdr av-rest))
    (setq av-index (1- av-index)))
  (car av-rest))

(defun av--list-drop (vv-list vv-count)
  (while (and vv-list (> vv-count 0))
    (setq vv-list (cdr vv-list))
    (setq vv-count (1- vv-count)))
  vv-list)

(defun av--sequence-length (av-sequence)
  (cond
    ((av-vector-p av-sequence)
     (av-length av-sequence))
    ((listp av-sequence)
     (length av-sequence))
    (t
     (av--error
       (strcat "unsupported sequence "
               (vl-princ-to-string av-sequence))))))

(defun av--sequence-ref (av-sequence av-index)
  (cond
    ((av-vector-p av-sequence)
     (av-aref av-sequence av-index))
    ((listp av-sequence)
     (av--list-nth av-sequence av-index))
    (t
     (av--error
       (strcat "unsupported sequence "
               (vl-princ-to-string av-sequence))))))

(defun av--normalize-end (av-end av-limit)
  (if av-end
    av-end
    av-limit))

(defun av--check-range (av-start av-end av-limit av-label)
  (av--ensure-nonnegative-integer av-start (strcat av-label " start"))
  (av--ensure-nonnegative-integer av-end (strcat av-label " end"))
  (if (> av-start av-end)
    (av--error (strcat av-label " start must be <= end")))
  (if (> av-end av-limit)
    (av--error
      (strcat av-label " end out of range: "
              (itoa av-end)
              " > "
              (itoa av-limit))))
  t)

(defun av-vector-p (av-object)
  (and (= (type av-object) 'SYM)
       (eq (av--getprop av-object 'av-kind) 'av-vector)))

(defun av-vectorp (av-object)
  (av-vector-p av-object))

(defun av-arrayp (av-object)
  (av-vector-p av-object))

(defun av--require-vector (av-object)
  (if (not (av-vector-p av-object))
    (av--error
      (strcat "expected av-vector, got "
              (vl-princ-to-string av-object))))
  av-object)

(defun av-length (av-vec)
  (av--require-vector av-vec)
  (av--getprop av-vec 'av-length))

(defun av-vector-length (av-vec)
  (av-length av-vec))

(defun av-array-total-size (av-vec)
  (av-length av-vec))

(defun av-adjustable-array-p (av-vec)
  (av--require-vector av-vec)
  nil)

(defun av-fill-pointer (av-vec)
  (av--require-vector av-vec)
  (av--getprop av-vec 'av-fill-pointer))

(defun av--fill-pointer-present-p (vv-vec / vv-data)
  (setq vv-data (av--symbol-data vv-vec))
  (not (null (assoc 'av-fill-pointer vv-data))))

(defun av-set-fill-pointer (av-vec av-fill-ptr / av-vec-length)
  (av--require-vector av-vec)
  (setq av-vec-length (av-length av-vec))
  (av--ensure-nonnegative-integer av-fill-ptr "fill-pointer")
  (if (> av-fill-ptr av-vec-length)
    (av--error "fill-pointer out of range"))
  (av--putprop av-vec av-fill-ptr 'av-fill-pointer)
  av-fill-ptr)

(defun av--make-vector-symbol (/ av-vector)
  (setq av-vector (av--make-symbol "av-vector-"))
  (av--putprop av-vector 'av-vector 'av-kind)
  av-vector)

(defun av-make-array (av-size av-initial-element av-initial-contents av-fill-ptr
                       / av-vec av-root av-height av-initial-length av-path-table)
  (av--ensure-nonnegative-integer av-size "length")
  (if (and av-initial-element av-initial-contents)
    (av--error "initial-element and initial-contents are mutually exclusive"))
  (if (not (null av-fill-ptr))
    (progn
      (av--ensure-nonnegative-integer av-fill-ptr "fill-pointer")
      (if (> av-fill-ptr av-size)
        (av--error "fill-pointer out of range"))))
  (if av-initial-contents
    (progn
      (setq av-initial-length (av--sequence-length av-initial-contents))
      (if (/= av-initial-length av-size)
        (av--error "initial-contents length must equal array length"))))
  (if (listp av-initial-contents)
    (progn
      (setq av-vec (av--make-array-from-list av-initial-contents av-fill-ptr))
      (if (/= (av-length av-vec) av-size)
        (av--error "internal error: list initialization size mismatch"))
      av-vec)
    (progn
  (setq av-vec (av--make-vector-symbol))
  (setq av-height (av--depth-for-length av-size))
  (setq av-path-table (av--path-table-for-depth av-height))
  (setq av-root
        (if (> av-size 0)
          (av--build-tree av-height av-initial-element)
          nil))
  (av--putprop av-vec av-size 'av-length)
  (av--putprop av-vec 2 'av-branching-factor)
  (av--putprop av-vec av-height 'av-height)
  (av--putprop av-vec av-path-table 'av-path-table)
  (av--putprop av-vec av-root 'av-root)
  (if (not (null av-fill-ptr))
    (av--putprop av-vec av-fill-ptr 'av-fill-pointer))
  (if av-initial-contents
    (av-replace av-vec av-initial-contents 0 av-size 0 av-size))
  av-vec)))

(defun av-vector (av-elements)
  (av--make-array-from-list av-elements nil))

(defun av--check-index (av-vec av-index / av-vec-length)
  (av--require-vector av-vec)
  (av--ensure-nonnegative-integer av-index "index")
  (setq av-vec-length (av-length av-vec))
  (if (or (< av-index 0) (>= av-index av-vec-length))
    (av--error
      (strcat "index out of range: "
              (itoa av-index)
              " for length "
              (itoa av-vec-length))))
  t)

(defun av-aref (av-vec av-index)
  (av--check-index av-vec av-index)
  (av--tree-ref (av--getprop av-vec 'av-root)
                av-index
                (av--getprop av-vec 'av-height)
                (av--getprop av-vec 'av-path-table)))

(defun av-svref (av-vec av-index)
  (av-aref av-vec av-index))

(defun av-set-aref (av-vec av-index av-value)
  (av--check-index av-vec av-index)
  (av--putprop av-vec
               (av--tree-set (av--getprop av-vec 'av-root)
                             av-index
                             (av--getprop av-vec 'av-height)
                             (av--getprop av-vec 'av-path-table)
                             av-value)
               'av-root)
  av-value)

(defun av-replace (av-destination av-source av-start1 av-end1 av-start2 av-end2
                    / vv-destination-length vv-source-length vv-count vv-dst-index vv-src-index vv-src-list)
  (av--require-vector av-destination)
  (setq vv-destination-length (av-length av-destination))
  (setq vv-source-length (av--sequence-length av-source))
  (setq av-start1 (if av-start1 av-start1 0))
  (setq av-start2 (if av-start2 av-start2 0))
  (setq av-end1 (av--normalize-end av-end1 vv-destination-length))
  (setq av-end2 (av--normalize-end av-end2 vv-source-length))
  (av--check-range av-start1 av-end1 vv-destination-length "replace destination")
  (av--check-range av-start2 av-end2 vv-source-length "replace source")
  (setq vv-count (min (- av-end1 av-start1)
                      (- av-end2 av-start2)))
  (setq vv-dst-index av-start1)
  (cond
    ((av-vector-p av-source)
     (setq vv-src-index av-start2)
     (while (> vv-count 0)
       (av-set-aref av-destination vv-dst-index (av-aref av-source vv-src-index))
       (setq vv-dst-index (1+ vv-dst-index))
       (setq vv-src-index (1+ vv-src-index))
       (setq vv-count (1- vv-count))))
    ((listp av-source)
     (setq vv-src-list (av--list-drop av-source av-start2))
     (while (> vv-count 0)
       (av-set-aref av-destination vv-dst-index (car vv-src-list))
       (setq vv-dst-index (1+ vv-dst-index))
       (setq vv-src-list (cdr vv-src-list))
       (setq vv-count (1- vv-count))))
    (t
     (av--error "unsupported replace source")))
  av-destination)

(defun av-subseq (av-vec av-start av-end / av-vec-length vv-values vv-index)
  (av--require-vector av-vec)
  (setq av-vec-length (av-length av-vec))
  (setq av-start (if av-start av-start 0))
  (setq av-end (av--normalize-end av-end av-vec-length))
  (av--check-range av-start av-end av-vec-length "subseq")
  (setq vv-values nil)
  (setq vv-index av-end)
  (while (> vv-index av-start)
    (setq vv-index (1- vv-index))
    (setq vv-values (cons (av-aref av-vec vv-index) vv-values)))
  (av--make-array-from-list vv-values nil))

(defun av-copy-vector (av-vec / vv-copy)
  (av--require-vector av-vec)
  (setq vv-copy (av-subseq av-vec 0 (av-length av-vec)))
  (if (av--fill-pointer-present-p av-vec)
    (av--putprop vv-copy (av-fill-pointer av-vec) 'av-fill-pointer))
  vv-copy)

(defun av-vector-push (av-item av-vec / av-fill-ptr av-vec-length)
  (av--require-vector av-vec)
  (setq av-fill-ptr (av-fill-pointer av-vec))
  (if (not (av--fill-pointer-present-p av-vec))
    (av--error "vector-push requires a fill-pointer"))
  (setq av-vec-length (av-length av-vec))
  (if (>= av-fill-ptr av-vec-length)
    nil
    (progn
      (av-set-aref av-vec av-fill-ptr av-item)
      (av-set-fill-pointer av-vec (1+ av-fill-ptr))
      av-fill-ptr)))

(defun av-vector-pop (av-vec / av-fill-ptr av-index av-value)
  (av--require-vector av-vec)
  (setq av-fill-ptr (av-fill-pointer av-vec))
  (if (not (av--fill-pointer-present-p av-vec))
    (av--error "vector-pop requires a fill-pointer"))
  (if (<= av-fill-ptr 0)
    (av--error "vector-pop requires a positive fill-pointer"))
  (setq av-index (1- av-fill-ptr))
  (setq av-value (av-aref av-vec av-index))
  (av-set-fill-pointer av-vec av-index)
  av-value)

(defun av-to-list (av-vec / av-items av-index av-vec-length)
  (av--require-vector av-vec)
  (setq av-items nil)
  (setq av-index 0)
  (setq av-vec-length (av-length av-vec))
  (while (< av-index av-vec-length)
    (setq av-items (cons (av-aref av-vec av-index) av-items))
    (setq av-index (1+ av-index)))
  (reverse av-items))

(defun av--item-string (av-item)
  (if (av-vector-p av-item)
    (av--vector-string av-item)
    (vl-princ-to-string av-item)))

(defun av--join-strings (av-strings av-separator / av-result av-rest)
  (if (null av-strings)
    ""
    (progn
      (setq av-result (car av-strings))
      (setq av-rest (cdr av-strings))
      (while av-rest
        (setq av-result (strcat av-result av-separator (car av-rest)))
        (setq av-rest (cdr av-rest)))
      av-result)))

(defun av--list-to-string-list (av-list / av-out)
  (setq av-out nil)
  (foreach av-item av-list
    (setq av-out (cons (av--item-string av-item) av-out)))
  (reverse av-out))

(defun av--vector-string (av-vec)
  (strcat "#("
          (av--join-strings (av--list-to-string-list (av-to-list av-vec)) " ")
          ")"))

(defun av-vector-string (av-vec)
  (av--require-vector av-vec)
  (av--vector-string av-vec))

(defun av-print-vector (av-vec)
  (av--require-vector av-vec)
  (princ (av-vector-string av-vec))
  av-vec)

(princ "")
