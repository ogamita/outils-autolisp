(in-package #:edward.tests)

(def-suite edward-suite :description "edward v1 — raw dump layer.")
(in-suite edward-suite)

(defun make-sample-drawing ()
  "A small synthetic drawing (no file / libredwg needed): two appids, one
INSERT carrying SCHMSPLUS + ACAD xdata, and a SCHMS_VOIES dictionary whose
single entry points at an XRECORD encoding a /es/schms/bd/voie instance."
  (let ((d (dwg:make-drawing :name "sample.dxf" :format :dxf-ascii :version :ac1027)))
    (dwg:add-table-record
     d (dwg:make-symbol-table-record :kind :appid :name "SCHMSPLUS"
                                     :data '((0 . "APPID") (2 . "SCHMSPLUS"))))
    (dwg:add-table-record
     d (dwg:make-symbol-table-record :kind :appid :name "ACAD"
                                     :data '((0 . "APPID") (2 . "ACAD"))))
    (dwg:add-entity
     d '((0 . "INSERT") (8 . "SIGNAUX") (2 . "GARE")
         (1001 . "SCHMSPLUS") (1000 . "/es/schms/sx2/gare")
         (1070 . 1) (1000 . "NOM") (1000 . "G1")
         (1001 . "ACAD") (1000 . "marker")))
    (let ((voies (dwg:make-dictionary)))
      (dwg:dictionary-put (dwg:drawing-dictionary d) "SCHMS_VOIES" voies)
      (dwg:add-object
       d "F00" '((0 . "XRECORD") (100 . "AcDbXrecord")
                 (1 . "/es/schms/bd/voie") (60 . 2)
                 (1 . "UUID") (1 . "uuid-1")
                 (1 . "NOM_VOIE") (1 . "DEPOT")))
      (dwg:dictionary-put voies "VOIE1" "F00"))
    d))

(defun first-entity (drawing)
  (let ((found nil))
    (dwg:map-entities (lambda (e) (unless found (setf found e))) drawing)
    found))
