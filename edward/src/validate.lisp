(in-package #:edward)

;;;; The validation engine — a data-driven rule runner over the node model.
;;;;
;;;; A RULE is data: an id, the node LEVEL it runs over, a SEVERITY, a short
;;;; DESCRIPTION, and a PREDICATE (node -> NIL when ok, or a finding string).
;;;; Rules live in *RULES*; users add their own (SNCF business rules) without
;;;; touching the engine — the BricsCAD CAD-standards analogue. The starter
;;;; ruleset doubles as a libredwg-compatibility detector: grammar/handle/
;;;; schema divergences, out-of-range values, garbage doubles, round-trip
;;;; entity drift.

(defstruct (rule (:conc-name rule-))
  id level severity description predicate)

(defvar *rules* '()
  "The active validation rules, in registration order.")

(defmacro defrule (id (node-var level &key (severity :warning) description) &body body)
  "Register a rule: BODY over NODE-VAR returns NIL (ok) or a finding string."
  `(progn
     (setf *rules*
           (append (remove ,id *rules* :key #'rule-id)
                   (list (make-rule :id ,id :level ,level :severity ,severity
                                    :description ,description
                                    :predicate (lambda (,node-var)
                                                 (declare (ignorable ,node-var))
                                                 ,@body)))))
     ,id))

;;;; --- node enumeration per level (no double-counting) -----------------

(defun all-pairs (drawing)
  "Every (code . value) pair in the drawing as :pair nodes: entity structural
pairs, entity xdata pairs, object pairs, table-record pairs."
  (let ((owners (append (entities drawing) (objects drawing) (table-records drawing))))
    (append (by-level (children owners) :pair)
            (by-level (children (by-level (children (entities drawing)) :xdata-group))
                      :pair))))

(defun nodes-at (drawing level)
  "All explorer nodes of DRAWING at LEVEL (used by the rule runner)."
  (case level
    (:drawing      (list (drawing-node drawing)))
    (:entity       (entities drawing))
    (:object       (objects drawing))
    (:table-record (table-records drawing))
    (:header-var   (header-vars drawing))
    (:xdata-group  (by-level (children (entities drawing)) :xdata-group))
    (:instance     (append (by-level (children (objects drawing)) :instance)
                           (by-level (children (nodes-at drawing :xdata-group)) :instance)))
    (:field        (by-level (children (nodes-at drawing :instance)) :field))
    (:pair         (all-pairs drawing))
    (otherwise '())))

;;;; --- handle set (for the dangling-handle rule) -----------------------

(defvar *known-handles* nil
  "Bound by RUN-RULES to DRAWING's handle set for the pass.")

(defun %known-handles (drawing)
  "A hash-set (integer keys) of every handle DEFINED in DRAWING: entity and
object handles, every code-5 in any data list (entities, objects, table
records, the table objects themselves, block headers), and dictionary
handles. Used to tell a real dangling reference from a valid structural one."
  (let ((set (make-hash-table :test 'eql)))
    (flet ((add (h) (let ((n (ignore-errors (dwg:handle->integer h))))
                      (when n (setf (gethash n set) t))))
           (add5 (data) (let ((h (dxf-assoc 5 data)))
                          (when h (let ((n (ignore-errors (dwg:handle->integer h))))
                                    (when n (setf (gethash n set) t)))))))
      (dwg:map-entities (lambda (e) (add (dwg:entity-handle-string e)))
                        drawing :include-deleted t)
      (dwg:map-objects (lambda (h d) (add h) (add5 d)) drawing)
      (dolist (k *table-kinds*)
        (dwg:map-table-records
         (lambda (r) (add5 (dwg:symbol-table-record-data r))) drawing k))
      ;; the symbol-table objects themselves (LAYER/LTYPE/… owners of records)
      (maphash (lambda (k data) (declare (ignore k)) (add5 data))
               (dwg:drawing-table-headers drawing))
      ;; block headers (BLOCK records own the entities)
      (dwg:map-blocks (lambda (name header) (declare (ignore name)) (add5 header)) drawing)
      ;; sub-dictionary handles (DICTIONARY-HANDLE is not exported by clautolisp)
      (walk-dictionaries
       drawing
       (lambda (path key v) (declare (ignore path key))
         (when (and (dwg:dictionary-p v) (clautolisp.drawing::dictionary-handle v))
           (add (clautolisp.drawing::dictionary-handle v))))))
    set))

;;;; --- runner ----------------------------------------------------------

(defun run-rules (drawing &key (rules *rules*) schema-root)
  "Apply RULES to DRAWING. Returns a list of finding plists
(:rule :severity :where :message)."
  (let ((*schema-root* (or schema-root *schema-root*))
        (*known-handles* (%known-handles drawing))
        (findings '()))
    (dolist (rule rules)
      (dolist (node (nodes-at drawing (rule-level rule)))
        (let ((msg (funcall (rule-predicate rule) node)))
          (when msg
            (push (list :rule (rule-id rule) :severity (rule-severity rule)
                        :where (node-path-string node) :message msg)
                  findings)))))
    (nreverse findings)))

(defun %severity-counts (findings)
  (let ((e 0) (w 0) (i 0))
    (dolist (f findings)
      (case (getf f :severity) (:error (incf e)) (:warning (incf w)) (t (incf i))))
    (values e w i)))

(defun print-report (findings &optional (stream *standard-output*))
  "Render FINDINGS as a text report to STREAM."
  (if (null findings)
      (format stream "~&validation: no findings.~%")
      (multiple-value-bind (e w i) (%severity-counts findings)
        (dolist (f findings)
          (format stream "~&~7@A  ~(~A~)  ~A~%    ~A~%"
                  (string-upcase (symbol-name (getf f :severity)))
                  (getf f :rule) (getf f :where) (getf f :message)))
        (format stream "~&-- ~A finding(s): ~A error, ~A warning, ~A info~%"
                (length findings) e w i)))
  findings)

(defun report->json (findings &optional drawing)
  "A JSON value for FINDINGS (+ optional DRAWING provenance)."
  (multiple-value-bind (e w i) (%severity-counts findings)
    (jobj "edward" *edward-version*
          "source" (or (and drawing (dwg:drawing-path drawing)
                            (princ-to-string (dwg:drawing-path drawing)))
                       :null)
          "summary" (jobj "findings" (length findings) "error" e "warning" w "info" i)
          "findings"
          (jarr (mapcar (lambda (f)
                          (jobj "rule" (string-downcase (symbol-name (getf f :rule)))
                                "severity" (string-downcase (symbol-name (getf f :severity)))
                                "where" (getf f :where)
                                "message" (getf f :message)))
                        findings)))))

;;;; --- entry points ----------------------------------------------------

(defun validate (&optional (drawing *drawing*) &key schema-root (stream *standard-output*))
  "Run the rules on DRAWING (default the REPL's *drawing*), print a text
report, and return the findings."
  (print-report (run-rules drawing :schema-root schema-root) stream))

(defun validate-file (path &key json schema-root (stream *standard-output*))
  "Read the drawing at PATH, validate it, and emit a text or JSON report.
Returns T when there are no error-severity findings."
  (let* ((drawing (read-drawing path))
         (findings (run-rules drawing :schema-root schema-root)))
    (if json
        (progn (json-emit (report->json findings drawing) stream) (terpri stream))
        (progn (format stream "~&~A~%" path)
               (print-report findings stream)))
    (multiple-value-bind (e w i) (%severity-counts findings)
      (declare (ignore w i))
      (zerop e))))

;;;; --- helpers for the starter ruleset ---------------------------------

(defun %real-code-p (code)
  "True for DXF group codes that carry a double."
  (and (integerp code)
       (or (<= 10 code 59) (<= 110 code 149) (<= 210 code 239)
           (<= 1010 code 1042))))

(defun %bad-double-p (x)
  "True if X is a NaN, infinity, denormal, or a near-overflow value — the
shapes libredwg's decompression regression produces. Note: AutoCAD uses
±1d20 as an \"uninitialised extents\" sentinel, so the huge bound is set well
above it (1d300) to avoid false positives."
  (and (floatp x)
       (or #+sbcl (sb-ext:float-nan-p x)
           #+sbcl (sb-ext:float-infinity-p x)
           #-sbcl (/= x x)
           (and (/= x 0d0) (< (abs x) least-positive-normalized-double-float))
           (> (abs x) 1d300))))

(defun %values-of (v)
  "The numeric components of a DXF value (atom or coalesced point list)."
  (if (listp v) v (list v)))

(defun %ref-handle-code-p (code)
  "True for pointer/handle group codes that should resolve to an object."
  (and (integerp code)
       (or (= code 1005) (= code 320) (<= 330 code 369))))

;;;; --- starter ruleset -------------------------------------------------

(defrule :garbage-double (n :pair :severity :error
                            :description "double value is NaN/Inf/denormal/huge (decode corruption)")
  (let* ((pr (node-payload n)) (code (car pr)))
    (when (%real-code-p code)
      (let ((bad (remove-if-not #'%bad-double-p (%values-of (cdr pr)))))
        (when bad (format nil "code ~A: out-of-range double(s) ~{~A~^ ~}" code bad))))))

(defrule :value-range (n :pair :severity :warning
                         :description "boolean group code (290-299) not in {0,1}")
  (let* ((pr (node-payload n)) (code (car pr)) (v (cdr pr)))
    (when (and (integerp code) (<= 290 code 299) (integerp v) (not (<= 0 v 1)))
      (format nil "boolean code ~A has value ~A (expected 0 or 1)" code v))))

(defrule :xdata-grammar (n :xdata-group :severity :warning
                           :description "SCHMS xdata stream does not fit the instance grammar")
  (let ((pairs (cdr (node-payload n))))
    (when (%instance-start pairs *xdata-codec*)
      (multiple-value-bind (inst divs) (decode-instance-stream pairs *xdata-codec*)
        (declare (ignore inst))
        (when divs
          (format nil "~A divergence(s): ~{~A~^; ~}"
                  (length divs) (mapcar #'%divergence->string divs)))))))

(defrule :xrecord-grammar (n :object :severity :warning
                             :description "XRECORD SCHMS stream does not fit the instance grammar")
  (let ((stream (xrecord-instance-pairs (cdr (node-payload n)))))
    (when stream
      (multiple-value-bind (inst divs) (decode-instance-stream stream *xrecord-codec*)
        (declare (ignore inst))
        (when divs
          (format nil "~A divergence(s): ~{~A~^; ~}"
                  (length divs) (mapcar #'%divergence->string divs)))))))

(defrule :schema-divergence (n :instance :severity :warning
                               :description "decoded instance violates its *_ATTR.LSP schema")
  (when *schema-root*
    (let* ((inst (node-payload n))
           (divs (validate-instance (getf inst :class) (getf inst :version)
                                    (getf inst :fields))))
      (when divs (format nil "~{~A~^; ~}" (mapcar #'%divergence->string divs))))))

(defrule :dangling-handle (n :pair :severity :info
                             :description "pointer/handle code references a handle not modelled
(best-effort: clautolisp does not retain all control/owner objects, so on a clean file this is
mostly structural noise — the real signal is the DELTA vs a known-good reference drawing)")
  (let* ((pr (node-payload n)) (code (car pr)) (v (cdr pr)))
    (when (and (%ref-handle-code-p code) (stringp v))
      (let ((int (ignore-errors (dwg:handle->integer v))))
        (when (and int (plusp int)
                   *known-handles*
                   (not (gethash int *known-handles*)))
          (format nil "code ~A references missing handle ~A" code v))))))

(defrule :layer-color (n :table-record :severity :info
                         :description "LAYER colour (code 62) outside the ACI 1-255 range")
  (let ((p (node-payload n)))
    (when (eq (dwg:symbol-table-record-kind p) :layer)
      (let ((c (dxf-assoc 62 (dwg:symbol-table-record-data p))))
        (when (and (integerp c) (not (<= 1 (abs c) 255)))
          (format nil "layer ~A colour 62=~A out of ACI 1-255 (sign = on/off)"
                  (dwg:symbol-table-record-name p) c))))))

(defrule :entity-count-drift (n :drawing :severity :error
                                :description "entity count changes across a DXF round-trip")
  (let ((drawing (node-payload n)))
    (when (dwg:drawing-path drawing)
      (uiop:with-temporary-file (:pathname tmp :type "dxf" :keep nil)
        (dwg:dxf-write-drawing drawing tmp :external-format :utf-8)
        (let* ((re (dwg:dxf-read-drawing tmp :external-format :utf-8))
               (oc (dwg:drawing-entity-count drawing))
               (rc (dwg:drawing-entity-count re)))
          (unless (= oc rc)
            (format nil "entity count drifts ~A -> ~A on DXF round-trip" oc rc)))))))
