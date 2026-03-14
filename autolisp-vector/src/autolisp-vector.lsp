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

(defun av--getprop (av-symbol av-prop / av-data)
  (cdr (assoc av-prop
              (cond
                ((vl-catch-all-error-p
                   (setq av-data
                         (vl-catch-all-apply 'eval (list av-symbol))))
                 nil)
                (t
                 av-data)))))

(defun av--putprop (av-symbol av-value av-prop / av-data av-current av-cell)
  (setq av-data
        (cond
          ((vl-catch-all-error-p
             (setq av-current
                   (vl-catch-all-apply 'eval (list av-symbol))))
           nil)
          (t
           av-current)))
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

(defun av--make-leaf (av-value / av-leaf)
  (setq av-leaf (av--make-symbol "av-leaf-"))
  (av--putprop av-leaf 'av-leaf 'av-kind)
  (av--putprop av-leaf av-value 'av-value)
  (av--putprop av-leaf 1 'av-count)
  (av--putprop av-leaf 0 'av-height)
  av-leaf)

(defun av--make-node (av-left av-right av-left-count / av-node av-height)
  (setq av-node (av--make-symbol "av-node-"))
  (setq av-height
        (1+ (max (av--getprop av-left 'av-height)
                 (av--getprop av-right 'av-height))))
  (av--putprop av-node 'av-node 'av-kind)
  (av--putprop av-node av-left 'av-left)
  (av--putprop av-node av-right 'av-right)
  (av--putprop av-node av-left-count 'av-split)
  (av--putprop av-node
               (+ av-left-count (av--getprop av-right 'av-count))
               'av-count)
  (av--putprop av-node av-height 'av-height)
  av-node)

(defun av--build-tree (av-count av-initial-value / av-left-count av-right-count)
  (cond
    ((<= av-count 0)
     nil)
    ((= av-count 1)
     (av--make-leaf av-initial-value))
    (t
     (setq av-left-count (fix (/ (+ av-count 1) 2)))
     (setq av-right-count (- av-count av-left-count))
     (av--make-node
       (av--build-tree av-left-count av-initial-value)
       (av--build-tree av-right-count av-initial-value)
       av-left-count))))

(defun av--build-tree-from-list (vv-count vv-values / vv-left-count vv-right-count vv-left-result vv-right-result)
  (cond
    ((<= vv-count 0)
     (cons nil vv-values))
    ((= vv-count 1)
     (cons (av--make-leaf (car vv-values))
           (cdr vv-values)))
    (t
     (setq vv-left-count (fix (/ (+ vv-count 1) 2)))
     (setq vv-right-count (- vv-count vv-left-count))
     (setq vv-left-result
           (av--build-tree-from-list vv-left-count vv-values))
     (setq vv-right-result
           (av--build-tree-from-list vv-right-count (cdr vv-left-result)))
     (cons (av--make-node (car vv-left-result)
                          (car vv-right-result)
                          vv-left-count)
           (cdr vv-right-result)))))

(defun av--make-array-from-list (vv-values vv-fill-ptr / vv-size vv-vec vv-root vv-height vv-result)
  (setq vv-size (length vv-values))
  (setq vv-vec (av--make-vector-symbol))
  (setq vv-result (av--build-tree-from-list vv-size vv-values))
  (setq vv-root (car vv-result))
  (setq vv-height
        (if vv-root
          (av--getprop vv-root 'av-height)
          0))
  (av--putprop vv-vec vv-size 'av-length)
  (av--putprop vv-vec 2 'av-branching-factor)
  (av--putprop vv-vec vv-height 'av-height)
  (av--putprop vv-vec vv-root 'av-root)
  (if (not (null vv-fill-ptr))
    (av--putprop vv-vec vv-fill-ptr 'av-fill-pointer))
  vv-vec)

(defun av--tree-ref (av-node av-index / av-split)
  (cond
    ((null av-node)
     (av--error "internal error: missing tree node"))
    ((eq (av--getprop av-node 'av-kind) 'av-leaf)
     (av--getprop av-node 'av-value))
    (t
     (setq av-split (av--getprop av-node 'av-split))
     (if (< av-index av-split)
       (av--tree-ref (av--getprop av-node 'av-left) av-index)
       (av--tree-ref (av--getprop av-node 'av-right) (- av-index av-split))))))

(defun av--tree-set (av-node av-index av-value / av-split)
  (cond
    ((null av-node)
     (av--error "internal error: missing tree node"))
    ((eq (av--getprop av-node 'av-kind) 'av-leaf)
     (av--putprop av-node av-value 'av-value)
     av-value)
    (t
     (setq av-split (av--getprop av-node 'av-split))
     (if (< av-index av-split)
       (av--tree-set (av--getprop av-node 'av-left) av-index av-value)
       (av--tree-set (av--getprop av-node 'av-right) (- av-index av-split) av-value)))))

(defun av--cursor-descend-leftmost (vv-node vv-path)
  (while (and vv-node
              (not (eq (av--getprop vv-node 'av-kind) 'av-leaf)))
    (setq vv-path (cons (list vv-node 'left) vv-path))
    (setq vv-node (av--getprop vv-node 'av-left)))
  (list vv-node vv-path))

(defun av--cursor-path-to-index (vv-node vv-index vv-path / vv-split)
  (while (and vv-node
              (not (eq (av--getprop vv-node 'av-kind) 'av-leaf)))
    (setq vv-split (av--getprop vv-node 'av-split))
    (if (< vv-index vv-split)
      (progn
        (setq vv-path (cons (list vv-node 'left) vv-path))
        (setq vv-node (av--getprop vv-node 'av-left)))
      (progn
        (setq vv-path (cons (list vv-node 'right) vv-path))
        (setq vv-index (- vv-index vv-split))
        (setq vv-node (av--getprop vv-node 'av-right)))))
  (list vv-node vv-path))

(defun av--cursor-make (vv-vec vv-start / vv-len vv-desc)
  (av--require-vector vv-vec)
  (setq vv-len (av-length vv-vec))
  (if (or (< vv-start 0) (> vv-start vv-len))
    (av--error "cursor start out of range"))
  (if (= vv-start vv-len)
    (list nil nil 0)
    (progn
      (setq vv-desc
            (av--cursor-path-to-index (av--getprop vv-vec 'av-root) vv-start nil))
      (list (car vv-desc)
            (cadr vv-desc)
            (- vv-len vv-start)))))

(defun av--cursor-empty-p (vv-cursor)
  (or (null vv-cursor)
      (<= (caddr vv-cursor) 0)
      (null (car vv-cursor))))

(defun av--cursor-value (vv-cursor)
  (if (av--cursor-empty-p vv-cursor)
    (av--error "cursor exhausted"))
  (av--getprop (car vv-cursor) 'av-value))

(defun av--cursor-set-value (vv-cursor vv-value)
  (if (av--cursor-empty-p vv-cursor)
    (av--error "cursor exhausted"))
  (av--putprop (car vv-cursor) vv-value 'av-value)
  vv-value)

(defun av--cursor-advance (vv-cursor / vv-node vv-path vv-rem vv-frame vv-parent vv-desc)
  (if (av--cursor-empty-p vv-cursor)
    vv-cursor
    (progn
      (setq vv-node (car vv-cursor))
      (setq vv-path (cadr vv-cursor))
      (setq vv-rem (1- (caddr vv-cursor)))
      (if (<= vv-rem 0)
        (list nil nil 0)
        (progn
          (while (and vv-path
                      (eq (cadr (car vv-path)) 'right))
            (setq vv-path (cdr vv-path)))
          (if (null vv-path)
            (list nil nil 0)
            (progn
              (setq vv-frame (car vv-path))
              (setq vv-parent (car vv-frame))
              (setq vv-desc
                    (av--cursor-descend-leftmost
                      (av--getprop vv-parent 'av-right)
                      (cons (list vv-parent 'right) (cdr vv-path))))
              (list (car vv-desc)
                    (cadr vv-desc)
                    vv-rem))))))))

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
  (setq vv-data (eval vv-vec))
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
                       / av-vec av-root av-height av-initial-length)
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
  (setq av-root (av--build-tree av-size av-initial-element))
  (setq av-height
        (if av-root
          (av--getprop av-root 'av-height)
          0))
  (av--putprop av-vec av-size 'av-length)
  (av--putprop av-vec 2 'av-branching-factor)
  (av--putprop av-vec av-height 'av-height)
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
  (av--tree-ref (av--getprop av-vec 'av-root) av-index))

(defun av-svref (av-vec av-index)
  (av-aref av-vec av-index))

(defun av-set-aref (av-vec av-index av-value)
  (av--check-index av-vec av-index)
  (av--tree-set (av--getprop av-vec 'av-root) av-index av-value)
  av-value)

(defun av-replace (av-destination av-source av-start1 av-end1 av-start2 av-end2
                    / vv-destination-length vv-source-length vv-count vv-dst-cursor vv-src-cursor vv-src-list)
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
  (setq vv-dst-cursor (av--cursor-make av-destination av-start1))
  (cond
    ((av-vector-p av-source)
     (setq vv-src-cursor (av--cursor-make av-source av-start2))
     (while (> vv-count 0)
       (av--cursor-set-value vv-dst-cursor (av--cursor-value vv-src-cursor))
       (setq vv-dst-cursor (av--cursor-advance vv-dst-cursor))
       (setq vv-src-cursor (av--cursor-advance vv-src-cursor))
       (setq vv-count (1- vv-count))))
    ((listp av-source)
     (setq vv-src-list (av--list-drop av-source av-start2))
     (while (> vv-count 0)
       (av--cursor-set-value vv-dst-cursor (car vv-src-list))
       (setq vv-dst-cursor (av--cursor-advance vv-dst-cursor))
       (setq vv-src-list (cdr vv-src-list))
       (setq vv-count (1- vv-count))))
    (t
     (av--error "unsupported replace source")))
  av-destination)

(defun av-subseq (av-vec av-start av-end / av-vec-length vv-cursor vv-values vv-count)
  (av--require-vector av-vec)
  (setq av-vec-length (av-length av-vec))
  (setq av-start (if av-start av-start 0))
  (setq av-end (av--normalize-end av-end av-vec-length))
  (av--check-range av-start av-end av-vec-length "subseq")
  (setq vv-cursor (av--cursor-make av-vec av-start))
  (setq vv-values nil)
  (setq vv-count (- av-end av-start))
  (while (> vv-count 0)
    (setq vv-values (cons (av--cursor-value vv-cursor) vv-values))
    (setq vv-cursor (av--cursor-advance vv-cursor))
    (setq vv-count (1- vv-count)))
  (av--make-array-from-list (reverse vv-values) nil))

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
