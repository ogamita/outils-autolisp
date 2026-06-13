(in-package #:edward.tests)
(in-suite edward-suite)

(test entity-xdata-grouping
  (let* ((d (make-sample-drawing))
         (e (first-entity d))
         (groups (edward:entity-xdata e)))
    (is (= 2 (length groups)))
    (is (string= "SCHMSPLUS" (car (first groups))))
    (is (string= "ACAD" (car (second groups))))
    ;; the SCHMSPLUS region is captured verbatim, marker excluded
    (is (equal '((1000 . "/es/schms/sx2/gare") (1070 . 1)
                 (1000 . "NOM") (1000 . "G1"))
               (cdr (first groups))))
    ;; the ACAD region too
    (is (equal '((1000 . "marker")) (cdr (second groups))))))

(test dump-contains-drawing-level-voie
  (let* ((d (make-sample-drawing))
         (json (with-output-to-string (s)
                 (edward:json-emit (edward:dump-drawing d :source "sample.dxf") s nil))))
    ;; the SCHMS_VOIES XRECORD (the labels) is dumped losslessly
    (is (search "SCHMS_VOIES" json))
    (is (search "VOIE1" json))
    (is (search "/es/schms/bd/voie" json))
    (is (search "NOM_VOIE" json))
    (is (search "DEPOT" json))
    ;; the appid table is reported
    (is (search "SCHMSPLUS" json))
    ;; entity xdata is grouped by appid
    (is (search "\"xdata\"" json))))

(test dump-raw-includes-full-entity-data
  (let* ((d (make-sample-drawing))
         (plain (with-output-to-string (s)
                  (edward:json-emit (edward:dump-drawing d :source "s") s nil)))
         (raw   (with-output-to-string (s)
                  (edward:json-emit (edward:dump-drawing d :source "s" :raw t) s nil))))
    ;; --raw adds the full DXF data array (e.g. the (2 . "GARE") block name)
    (is (search "\"data\"" raw))
    (is (not (search "\"data\"" plain)))))

(test dump-sections-toggle
  (let ((d (make-sample-drawing)))
    (let ((no-ent (with-output-to-string (s)
                    (edward:json-emit (edward:dump-drawing d :entities nil) s nil))))
      (is (not (search "\"entities\"" no-ent)))
      (is (search "\"dictionaries\"" no-ent)))
    (let ((no-dict (with-output-to-string (s)
                     (edward:json-emit (edward:dump-drawing d :dictionaries nil) s nil))))
      (is (not (search "\"dictionaries\"" no-dict)))
      (is (search "\"entities\"" no-dict)))))
