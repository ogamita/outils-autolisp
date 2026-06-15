(in-package #:edward)

;;;; Inspection & visualisation for the explorer.
;;;;
;;;; SHOW / PRINT-TREE render a node (or selection) as an ASCII tree, recursing
;;;; through NODE-CHILDREN. EXAMINE is a full-depth view plus the mutation
;;;; target. EXPORT-SEL serialises any selection to JSON / sexp / a DXF
;;;; fragment, reusing the json.lisp DSL and the dump.lisp emitters.

(defun %short (v &optional (max 72))
  "A one-line, length-capped printed form of V."
  (let ((s (if (stringp v) v (prin1-to-string v))))
    (if (> (length s) max)
        (concatenate 'string (subseq s 0 (1- max)) "…")
        s)))

(defun %value-repr (v)
  "Render a DXF value V (atom, point list, or empty) for one-line display."
  (cond ((null v) "\"\"")
        ((stringp v) (prin1-to-string v))
        ((consp v) (format nil "(~{~A~^ ~})" v))
        (t (prin1-to-string v))))

(defun %dict-value-desc (v)
  (cond ((dwg:dictionary-p v) "{dictionary}")
        ((dwg:entity-handle-p v) (format nil "#~A (entity)" (dwg:entity-handle-string v)))
        ((stringp v) (format nil "#~A" v))
        (t (%short v))))

(defun %field-value-desc (v)
  (if (and (consp v) (eq (car v) :block)) "{block}" (%short (%value-repr v))))

(defun node-label (node)
  "A one-line header describing NODE."
  (let ((p (node-payload node)))
    (case (node-level node)
      (:drawing
       (format nil "DRAWING ~A  ~(~A~)/~(~A~)  entities=~A appids=~A"
               (or (dwg:drawing-name p) "?")
               (or (dwg:drawing-format p) :?) (or (dwg:drawing-version p) :?)
               (dwg:drawing-entity-count p) (length (drawing-appids p))))
      (:entity
       (let ((data (dwg:entity-dxf p)))
         (format nil "~A #~A~@[ layer=~A~]~@[ block=~A~]~@[ xdata=[~{~A~^ ~}]~]"
                 (string-upcase (symbol-name (dwg:entity-kind p)))
                 (dwg:entity-handle-string p)
                 (dxf-assoc 8 data) (dwg:entity-handle-block p)
                 (mapcar #'car (entity-xdata p)))))
      (:object (format nil "OBJECT ~A #~A" (or (dxf-assoc 0 (cdr p)) "?") (car p)))
      (:table-record
       (format nil "~A ~A"
               (string-upcase (symbol-name (dwg:symbol-table-record-kind p)))
               (dwg:symbol-table-record-name p)))
      (:dict (format nil "DICT ~A" (node-index node)))
      (:dict-entry (format nil "~A -> ~A" (car p) (%dict-value-desc (cdr p))))
      (:header-var (format nil "$~A = ~A" (dwg:sysvar-cell-name p)
                           (%short (%value-repr (dwg:sysvar-cell-value p)))))
      (:pair (format nil "[~A] ~A" (car p) (%short (%value-repr (cdr p)))))
      (:block "{ block }")
      (:xdata-group (format nil "xdata ~A (~A pairs)" (car p) (length (cdr p))))
      (:instance (format nil "~A v~A [~A fields]"
                         (or (getf p :class) "?") (getf p :version)
                         (length (getf p :fields))))
      (:field (format nil "~A = ~A" (car p) (%field-value-desc (cdr p))))
      (otherwise (format nil "~(~A~) ~A" (node-level node) (%short p))))))

(defun %print-node-tree (node guides depth stream)
  (when guides
    (dolist (g (butlast guides)) (write-string (if g "   " "│  ") stream))
    (write-string (if (car (last guides)) "└─ " "├─ ") stream))
  (write-string (node-label node) stream)
  (terpri stream)
  (when (plusp depth)
    (loop for (k . more) on (node-children node)
          do (%print-node-tree k (append guides (list (null more))) (1- depth) stream))))

(defun print-tree (selection &key (depth 2) (stream *standard-output*))
  "Render SELECTION (a node or selection) as an ASCII tree, DEPTH levels deep."
  (dolist (n (%as-selection selection))
    (%print-node-tree n '() depth stream))
  (values))

(defun show (selection &optional (depth 2))
  "Print SELECTION as a tree (default 2 levels). The REPL's default viewer."
  (print-tree selection :depth depth))

(defun examine (node)
  "Full-depth tree of NODE plus its mutation target (the unit a write touches)."
  (let ((n (if (node-p node) node (first-of node))))
    (print-tree n :depth most-positive-fixnum)
    (multiple-value-bind (level handle) (mutation-target n)
      (when level
        (format t "~&;; mutation target: ~(~A~)~@[ #~A~] (a write replaces the whole unit)~%"
                level handle)))
    (values)))

;;;; --- export ----------------------------------------------------------

(defun %hv->json (v)
  (cond ((stringp v) v) ((numberp v) v) ((null v) :null)
        ((consp v) (jarr (mapcar #'%hv->json v)))
        (t (princ-to-string v))))

(defun node->json (node)
  "A JSON value for NODE, reusing the dump.lisp emitters."
  (let ((p (node-payload node)))
    (case (node-level node)
      (:drawing (dump-drawing p))
      (:entity (%entity->json p :raw t))
      (:object (jobj "handle" (car p)
                     "decoded" (let ((s (xrecord-instance-pairs (cdr p))))
                                 (if s (schms-decoded->json s *xrecord-codec*) :null))
                     "object" (dxf-data->json (cdr p))))
      (:pair (dxf-pair->json p))
      (:block (jobj "block" (dxf-data->json (second p))))
      (:xdata-group (jobj "appid" (car p)
                          "decoded" (or (decode-xdata-group (car p) (cdr p)) :null)
                          "raw" (dxf-data->json (cdr p))))
      (:instance (%schms-instance->json p))
      (:field (jobj "name" (car p) "value" (decoded-value->json (cdr p))))
      (:dict-entry (jobj "key" (car p) "value" (%dict-value-desc (cdr p))))
      (:table-record (jobj "kind" (string-downcase (symbol-name (dwg:symbol-table-record-kind p)))
                           "name" (dwg:symbol-table-record-name p)
                           "data" (dxf-data->json (dwg:symbol-table-record-data p))))
      (:header-var (jobj "name" (dwg:sysvar-cell-name p)
                         "value" (%hv->json (dwg:sysvar-cell-value p))))
      (otherwise (jobj "level" (string-downcase (symbol-name (node-level node)))
                       "payload" (%short p))))))

(defun %node-pairs (node)
  "The (code . value) entries underlying NODE, for a DXF fragment."
  (let ((p (node-payload node)))
    (case (node-level node)
      (:entity (dwg:entity-dxf p))
      (:object (cdr p))
      (:xdata-group (cdr p))
      (:table-record (dwg:symbol-table-record-data p))
      (:block (second p))
      (:pair (list p))
      (otherwise nil))))

(defun %emit-dxf-fragment (node stream)
  (dolist (pr (%node-pairs node))
    (when (consp pr)
      (format stream "~A~%~A~%"
              (car pr)
              (let ((v (cdr pr))) (if (stringp v) v (%value-repr v)))))))

(defun export-sel (selection &key (format :json) (stream *standard-output*) (pretty t))
  "Serialise SELECTION. FORMAT is :json (default), :sexp (re-readable Lisp
payloads), or :dxf-fragment (best-effort code/value text)."
  (let ((sel (%as-selection selection)))
    (ecase format
      (:json (json-emit (jarr (mapcar #'node->json sel)) stream pretty)
             (when pretty (terpri stream)))
      (:sexp (dolist (n sel) (prin1 (node-payload n) stream) (terpri stream)))
      (:dxf-fragment (dolist (n sel) (%emit-dxf-fragment n stream)))))
  (values))
