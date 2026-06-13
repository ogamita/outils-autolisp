(in-package #:edward.tests)
(in-suite edward-suite)

;;; Structural SCHMS instance decoder (codec-xdata.lisp).

(test decode-xrecord-voie
  ;; A /es/schms/bd/voie v2 instance as stored in an XRECORD (codes 1/60),
  ;; with the standard XRECORD header in front (must be skipped).
  (let* ((object '((0 . "XRECORD") (5 . "F00") (100 . "AcDbXrecord") (280 . 1)
                   (1 . "/es/schms/bd/voie") (60 . 2)
                   (1 . "UUID") (1 . "uuid-1")
                   (1 . "TAGVOIE") (1 . "VOIE100001")
                   (1 . "NOM_VOIE") (1 . "DEPOT")))
         (stream (edward::xrecord-instance-pairs object)))
    (is (not (null stream)))
    (multiple-value-bind (instances divergences)
        (edward::decode-instance-stream stream edward::*xrecord-codec*)
      (is (null divergences))
      (is (= 1 (length instances)))
      (let ((i (first instances)))
        (is (string= "/es/schms/bd/voie" (getf i :class)))
        (is (eql 2 (getf i :version)))
        (is (equal '(("UUID" . "uuid-1") ("TAGVOIE" . "VOIE100001")
                     ("NOM_VOIE" . "DEPOT"))
                   (getf i :fields)))))))

(test decode-xdata-entity-instance
  ;; The same shape in the entity-xdata dialect (codes 1000/1070).
  (let ((pairs '((1000 . "/es/schms/sx2/gare") (1070 . 3)
                 (1000 . "NOM") (1000 . "G1")
                 (1000 . "TAGSIGNAL") (1000 . "S12"))))
    (multiple-value-bind (instances divergences)
        (edward::decode-instance-stream pairs edward::*xdata-codec*)
      (is (null divergences))
      (is (= 1 (length instances)))
      (let ((i (first instances)))
        (is (string= "/es/schms/sx2/gare" (getf i :class)))
        (is (eql 3 (getf i :version)))
        (is (equal "G1" (cdr (assoc "NOM" (getf i :fields) :test #'string=))))))))

(test decode-multiple-instances
  ;; multimeta: two instances of the same class back to back.
  (let ((pairs '((1000 . "/es/schms/bd/ligne") (1070 . 4)
                 (1000 . "TAGLIGNE") (1000 . "L1")
                 (1000 . "/es/schms/bd/ligne") (1070 . 4)
                 (1000 . "TAGLIGNE") (1000 . "L2"))))
    (multiple-value-bind (instances divergences)
        (edward::decode-instance-stream pairs edward::*xdata-codec*)
      (declare (ignore divergences))
      (is (= 2 (length instances)))
      (is (string= "L1" (cdr (assoc "TAGLIGNE" (getf (first instances) :fields) :test #'string=))))
      (is (string= "L2" (cdr (assoc "TAGLIGNE" (getf (second instances) :fields) :test #'string=)))))))

(test decode-non-instance-xdata
  ;; xdata with no class-name start (e.g. a bare marker) -> no instance,
  ;; flagged as a divergence (raw is preserved by the caller).
  (let ((pairs '((1070 . 1))))
    (multiple-value-bind (instances divergences)
        (edward::decode-instance-stream pairs edward::*xdata-codec*)
      (is (null instances))
      (is (= 1 (length divergences)))
      (is (eq :no-instance (getf (first divergences) :kind))))))
