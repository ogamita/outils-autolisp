(in-package #:edward)

;;;; Structural decoder for the SCHMS instance encoding.
;;;;
;;;; SCHMS serialises a class instance as a self-labelling stream of DXF
;;;; entries (see schms/src-vlx/xdata_codec.lsp). The same shape is used in
;;;; two "dialects" — different group codes carry the same roles:
;;;;
;;;;            string  int16  int32  real  handle  control
;;;;   xdata     1000    1070   1071   1040   1005    1002      (on entities)
;;;;   xrecord      1      60     90    210    320     102      (in NOD dicts)
;;;;
;;;; Stream shape (per instance, after the appid / xrecord header):
;;;;   (string . <class-name>)            ; e.g. "/es/schms/bd/voie"
;;;;   (int16  . <schema-version>)
;;;;   [ (string . <field-name>) <value> ]*   ; value: one scalar, or a
;;;;                                            ; control-{ … }-delimited block
;;;; Several instances may follow one another (multimeta: current + reference
;;;; states); a new instance is recognised by an int16 (version) appearing
;;;; where a field name (string) would otherwise begin.
;;;;
;;;; This decoder is *structural*: it needs no schema to recover
;;;; {class, version, fields}. Schema-informed typing/validation is layered on
;;;; top in decode-schms.lisp. The raw pairs are always kept by the caller, so
;;;; anything this cannot interpret is reported as a divergence, never dropped.

(defstruct (xcodec (:constructor make-xcodec (string int16 int32 real handle control)))
  string int16 int32 real handle control)

(defparameter *xdata-codec*   (make-xcodec 1000 1070 1071 1040 1005 1002)
  "Group codes for instance xdata attached to entities (appid SCHMSPLUS).")
(defparameter *xrecord-codec* (make-xcodec 1 60 90 210 320 102)
  "Group codes for instances stored as XRECORDs in NOD dictionaries.")

(defun %class-name-p (value)
  "True if VALUE looks like a SCHMS class name (an /es/schms/… path)."
  (and (stringp value) (> (length value) 0) (char= (char value 0) #\/)))

(defun %instance-start (pairs codec)
  "Index of the first pair that begins an instance stream (a string-code
pair whose value looks like a class name), or NIL."
  (position-if (lambda (p)
                 (and (consp p)
                      (eql (car p) (xcodec-string codec))
                      (%class-name-p (cdr p))))
               pairs))

(defun %read-value (vec i codec)
  "Read one field value from VEC starting at index I. Returns (values
value next-index divergence). A control-{ … } block is decoded into a
nested list of items (best effort); a scalar is its raw value."
  (let* ((p (aref vec i))
         (code (car p)))
    (if (and (eql code (xcodec-control codec))
             (equal (cdr p) "{"))
        ;; nested block: gather to matching "}"
        (let ((depth 1) (j (1+ i)) (inner '()))
          (loop while (and (< j (length vec)) (> depth 0))
                for q = (aref vec j)
                do (cond
                     ((and (eql (car q) (xcodec-control codec)) (equal (cdr q) "{"))
                      (incf depth) (push q inner) (incf j))
                     ((and (eql (car q) (xcodec-control codec)) (equal (cdr q) "}"))
                      (decf depth) (when (> depth 0) (push q inner)) (incf j))
                     (t (push q inner) (incf j))))
          (values (list :block (nreverse inner)) j nil))
        ;; scalar
        (values (cdr p) (1+ i) nil))))

(defun decode-instance-stream (pairs codec)
  "Decode the SCHMS instance stream PAIRS (a list of (code . value) entries,
with the appid / xrecord header already removed) using CODEC. Returns
(values instances divergences), where INSTANCES is a list of plists
(:class :version :fields), :fields an alist (name . value); DIVERGENCES is a
list of keyword/detail describing anything that did not fit the grammar."
  (let* ((start (%instance-start pairs codec))
         (divergences '()))
    (unless start
      (return-from decode-instance-stream
        (values '() (list (list :kind :no-instance)))))
    (let* ((vec (coerce pairs 'vector))
           (n (length vec))
           (i start)
           (instances '()))
      (flet ((scode (p) (eql (car p) (xcodec-string codec)))
             (icode (p) (eql (car p) (xcodec-int16 codec))))
        (loop while (< i n) do
          (let ((classp (aref vec i)))
            (unless (and (scode classp) (%class-name-p (cdr classp)))
              (push (list :kind :unexpected :at i :pair classp) divergences)
              (return))
            (let ((class (cdr classp)) (version nil) (fields '()))
              (incf i)
              ;; version
              (when (and (< i n) (icode (aref vec i)))
                (setf version (cdr (aref vec i)))
                (incf i))
              (unless version
                (push (list :kind :no-version :class class) divergences))
              ;; fields, until a new instance (int16 at field-start) or end
              (loop while (< i n) do
                (let ((fp (aref vec i)))
                  (cond
                    ((and (scode fp) (%class-name-p (cdr fp)))
                     ;; next instance's class name
                     (return))
                    ((icode fp)
                     ;; next instance's version marker
                     (return))
                    ((scode fp)
                     (let ((fname (cdr fp)))
                       (incf i)
                       (if (< i n)
                           (multiple-value-bind (val j d) (%read-value vec i codec)
                             (when d (push d divergences))
                             (push (cons fname val) fields)
                             (setf i j))
                           (progn
                             (push (list :kind :dangling-field :name fname) divergences)
                             (return)))))
                    (t
                     (push (list :kind :unexpected-code :pair fp :at i) divergences)
                     (incf i)))))
              (push (list :class class :version version :fields (nreverse fields))
                    instances)))))
      (values (nreverse instances) (nreverse divergences)))))

(defun xrecord-instance-pairs (object-data)
  "Strip the standard XRECORD object header from OBJECT-DATA, returning the
trailing pairs that hold the SCHMS instance stream (from the class-name
pair on). Returns NIL if no instance start is found."
  (let ((start (%instance-start object-data *xrecord-codec*)))
    (and start (nthcdr start object-data))))
