(in-package #:edward.tests)

(in-suite edward-suite)

;;;; Tests for the interactive explorer: node model, query language, inspect,
;;;; validation, and operations. All run on synthetic drawings (no libredwg).

(defun %bad-xdata-drawing ()
  "A drawing whose one entity carries a SCHMS xdata stream that breaks the
instance grammar (a class name, no version, then an unexpected real code)."
  (let ((d (dwg:make-drawing :name "bad.dxf" :format :dxf-ascii :version :ac1027)))
    (dwg:add-table-record
     d (dwg:make-symbol-table-record :kind :appid :name "SCHMSPLUS"
                                     :data '((0 . "APPID") (2 . "SCHMSPLUS"))))
    (dwg:add-entity
     d '((0 . "POINT") (8 . "0")
         (1001 . "SCHMSPLUS") (1000 . "/es/schms/bd/voie") (1040 . 1.5)))
    d))

;;; --- node model & query ----------------------------------------------

(test explorer-roots
  (let ((d (make-sample-drawing)))
    (is (= 1 (edward:count-of (edward:entities d))))
    (is (= 1 (edward:count-of (edward:objects d))))
    (is (edward:node-p (edward:first-of (edward:entities d))))
    (is (eq :entity (edward:node-level (edward:first-of (edward:entities d)))))))

(test explorer-filters
  (let ((d (make-sample-drawing)))
    (is (= 1 (edward:count-of (edward:by-layer (edward:entities d) "SIGNAUX"))))
    (is (= 0 (edward:count-of (edward:by-layer (edward:entities d) "NOPE"))))
    (is (= 1 (edward:count-of (edward:by-kind (edward:entities d) :insert))))
    (is (= 1 (edward:count-of (edward:by-appid (edward:entities d) "SCHMSPLUS"))))))

(test explorer-descend-to-instance
  (let* ((d (make-sample-drawing))
         (e (edward:first-of (edward:entities d)))
         (xg (edward:first-of (edward:by-appid (edward:children e) "SCHMSPLUS")))
         (inst (edward:first-of (edward:by-level (edward:children xg) :instance))))
    (is (eq :xdata-group (edward:node-level xg)))
    (is (eq :instance (edward:node-level inst)))
    (is (string= "/es/schms/sx2/gare" (getf (edward:node-payload inst) :class)))
    (is (<= 1 (edward:count-of (edward:children inst))))))   ; at least one field

(test explorer-mutation-target
  (let* ((d (make-sample-drawing))
         ;; field of the XRECORD instance -> climbs to the owning object F00
         (obj (edward:first-of (edward:objects d)))
         (inst (edward:first-of (edward:by-level (edward:children obj) :instance)))
         (fld (edward:first-of (edward:children inst))))
    (is (eq :field (edward:node-level fld)))
    (multiple-value-bind (kind handle) (edward:mutation-target fld)
      (is (eq :object kind))
      (is (string-equal "F00" handle)))))

;;; --- inspect & export ------------------------------------------------

(test explorer-inspect-and-export
  (let* ((d (make-sample-drawing))
         (e (edward:first-of (edward:entities d))))
    (is (search "INSERT" (edward:node-label e)))
    (let ((json (with-output-to-string (s)
                  (edward:export-sel e :stream s :pretty nil))))
      (is (search "\"INSERT\"" json))
      (is (search "SCHMSPLUS" json)))
    (let ((tree (with-output-to-string (s) (edward:print-tree e :stream s :depth 2))))
      (is (search "xdata" tree)))))

;;; --- validation ------------------------------------------------------

(test explorer-validate-clean
  ;; the sample drawing has no path and well-formed data -> no error findings
  (let* ((d (make-sample-drawing))
         (findings (edward:run-rules d)))
    (is (null (remove-if-not (lambda (f) (eq :error (getf f :severity))) findings)))))

(test explorer-validate-xdata-grammar
  (let* ((d (%bad-xdata-drawing))
         (findings (edward:run-rules d)))
    (is (find :xdata-grammar findings :key (lambda (f) (getf f :rule))))))

(test explorer-validate-garbage-double
  (let ((d (dwg:make-drawing :name "g.dxf" :format :dxf-ascii :version :ac1027)))
    (dwg:add-entity d (list '(0 . "POINT") '(8 . "0")
                            (cons 40 least-positive-double-float)))   ; a denormal
    (let ((findings (edward:run-rules d)))
      (is (find :garbage-double findings :key (lambda (f) (getf f :rule)))))))

;;; --- operations ------------------------------------------------------

(test explorer-duplicate
  (let* ((d (make-sample-drawing))
         (before (dwg:drawing-entity-count d))
         (new (edward:dup (edward:entities d))))
    (is (= 1 (length new)))
    (is (= (1+ before) (dwg:drawing-entity-count d)))
    ;; new handle differs from the original
    (is (not (string-equal (edward:node-handle (first new))
                           (edward:node-handle (edward:first-of (edward:entities d))))))))

(test explorer-delete
  (let* ((d (make-sample-drawing))
         (before (edward:count-of (edward:entities d))))
    (edward:del (edward:entities d))
    (is (= (1- before) (edward:count-of (edward:entities d))))))

(test explorer-edit-entity-pairs
  (let* ((d (make-sample-drawing))
         (e (edward:first-of (edward:entities d))))
    ;; move the entity to a new layer by rewriting its (8 . _) pair
    (edward:edit-entity-pairs
     e (lambda (pairs)
         (mapcar (lambda (p) (if (and (consp p) (eql (car p) 8)) (cons 8 "MOVED") p))
                 pairs)))
    (let ((e2 (edward:first-of (edward:entities d))))
      (is (string= "MOVED" (cdr (assoc 8 (dwg:entity-dxf (edward:node-payload e2)))))))))
