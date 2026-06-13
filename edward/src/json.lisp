(in-package #:edward)

;;;; A small, dependency-free JSON emitter.
;;;;
;;;; JSON values are built from a tiny Lisp DSL:
;;;;   (:object (KEY . VALUE) ...)   an object; KEY a string, VALUE a value
;;;;   (:array VALUE ...)            an array
;;;;   a string                      a JSON string
;;;;   an integer / float            a JSON number
;;;;   :true / :false / :null        the JSON literals
;;;; Build them with JOBJ (alternating key/value) and JARR (a list of values).

(defun jobj (&rest key-value-plist)
  "Build a JSON object value from alternating KEY VALUE arguments."
  (let ((pairs '()))
    (loop for (k v) on key-value-plist by #'cddr
          do (push (cons k v) pairs))
    (cons :object (nreverse pairs))))

(defun jarr (values)
  "Build a JSON array value from the list VALUES (already JSON values)."
  (cons :array values))

(defun %json-string (s stream)
  "Write S as a quoted, escaped JSON string."
  (write-char #\" stream)
  (loop for ch across (princ-to-string s)
        do (case ch
             (#\" (write-string "\\\"" stream))
             (#\\ (write-string "\\\\" stream))
             (#\Newline (write-string "\\n" stream))
             (#\Return (write-string "\\r" stream))
             (#\Tab (write-string "\\t" stream))
             (t (if (< (char-code ch) #x20)
                    (format stream "\\u~4,'0X" (char-code ch))
                    (write-char ch stream)))))
  (write-char #\" stream))

(defun %json-number (x stream)
  "Write the number X as a JSON number (no Lisp float exponent markers)."
  (cond
    ((integerp x) (princ x stream))
    ((floatp x)
     (let ((s (let ((*read-default-float-format* (type-of x)))
                (prin1-to-string x))))
       ;; Normalise any exponent marker (d/D/f/F/s/S/l/L) to JSON 'e'.
       (write-string (map 'string
                          (lambda (c)
                            (if (member c '(#\d #\D #\f #\F #\s #\S #\l #\L))
                                #\e c))
                          s)
                     stream)))
    (t (princ x stream))))

(defun json-emit (value &optional (stream *standard-output*) (pretty t) (level 0))
  "Write the JSON VALUE (DSL above) to STREAM. PRETTY indents with two
spaces per level."
  (labels ((nl (n) (when pretty (terpri stream) (dotimes (_ (* 2 n)) (write-char #\Space stream)))))
    (cond
      ((or (eq value :true)  (eq value t))   (write-string "true" stream))
      ((eq value :false)                     (write-string "false" stream))
      ((or (eq value :null)  (null value))   (write-string "null" stream))
      ((stringp value)                       (%json-string value stream))
      ((numberp value)                       (%json-number value stream))
      ((and (consp value) (eq (car value) :object))
       (let ((pairs (cdr value)))
         (if (null pairs)
             (write-string "{}" stream)
             (progn
               (write-char #\{ stream)
               (loop for (pair . more) on pairs
                     do (nl (1+ level))
                        (%json-string (car pair) stream)
                        (write-string (if pretty ": " ":") stream)
                        (json-emit (cdr pair) stream pretty (1+ level))
                        (when more (write-char #\, stream)))
               (nl level)
               (write-char #\} stream)))))
      ((and (consp value) (eq (car value) :array))
       (let ((items (cdr value)))
         (if (null items)
             (write-string "[]" stream)
             (progn
               (write-char #\[ stream)
               (loop for (item . more) on items
                     do (nl (1+ level))
                        (json-emit item stream pretty (1+ level))
                        (when more (write-char #\, stream)))
               (nl level)
               (write-char #\] stream)))))
      ;; A bare keyword other than the literals: emit its name as a string.
      ((keywordp value) (%json-string (string-downcase (symbol-name value)) stream))
      (t (%json-string (princ-to-string value) stream))))
  value)
