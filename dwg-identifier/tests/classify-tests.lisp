(in-package #:dwg-identifier.tests)

(in-suite dwg-identifier-suite)

(defun drawing-with-appids (appids &optional (entities 0))
  "A synthetic drawing whose APPID table holds APPIDS and that has
ENTITIES point entities. No file / libredwg needed."
  (let ((d (dwg:make-drawing)))
    (dolist (a appids)
      (dwg:add-table-record
       d (dwg:make-symbol-table-record :kind :appid :name a)))
    (dotimes (i entities) (dwg:add-entity d '((0 . "POINT"))))
    d))

;;; --- appid -> product mapping ------------------------------------

(test appid-product-mapping
  (is (eq :schms    (id:appid-product "SCHMS")))
  (is (eq :schms    (id:appid-product "SCHMSPLUS")))
  (is (eq :schms    (id:appid-product "SCHMS_POSTES")))
  (is (eq :schme    (id:appid-product "SCHME")))
  (is (eq :schme    (id:appid-product "SCHMEPLUS")))
  (is (eq :schmieux (id:appid-product "SCHMIEUX")))
  (is (eq :schmieux (id:appid-product "SCHMIEUX_93_brics")))
  (is (eq :pv       (id:appid-product "PV")))
  (is (eq :pv       (id:appid-product "PV2010")))
  (is (eq :pv       (id:appid-product "PVSX_VOIES_ET_GABARITS")))
  (is (eq :epure    (id:appid-product "EPURE")))
  (is (eq :epure    (id:appid-product "EPURELIB")))
  (is (eq :epure    (id:appid-product "SNCF-Com_Echelle")))
  (is (null (id:appid-product "ACAD")))
  (is (null (id:appid-product "ACAD_PSEXT"))))

;;; --- classification ----------------------------------------------

(test classify-schms-plus-with-epure
  (let ((c (id:classify-drawing
            (drawing-with-appids '("ACAD" "SCHMS" "SCHMSPLUS"
                                   "SNCF-Com_Echelle" "SNCF-Com_Vers-Dwg-Epure")
                                 42))))
    (is (equal '(:schms) (remove :epure (id:classification-products c))))
    (is (id:classification-plus-p c))
    (is (id:classification-epure-p c))
    (is (= 42 (id:classification-entity-count c)))
    (is (string= "SCHMS+ (EPURE)" (id:classification-label c)))))

(test classify-pv
  (let ((c (id:classify-drawing (drawing-with-appids '("ACAD" "PV" "PV2010")))))
    (is (equal '(:pv) (id:classification-products c)))
    (is (not (id:classification-plus-p c)))
    (is (not (id:classification-epure-p c)))
    (is (string= "PV" (id:classification-label c)))))

(test classify-schme-plus
  (let ((c (id:classify-drawing (drawing-with-appids '("SCHME" "SCHMEPLUS")))))
    (is (equal '(:schme) (id:classification-products c)))
    (is (id:classification-plus-p c))
    (is (string= "SCHME+" (id:classification-label c)))))

(test classify-unknown
  (let ((c (id:classify-drawing (drawing-with-appids '("ACAD" "ACAD_PSEXT")))))
    (is (null (id:classification-products c)))
    (is (string= "unknown" (id:classification-label c)))))

(test classify-epure-only
  (let ((c (id:classify-drawing (drawing-with-appids '("ACAD" "SNCF-Com_Echelle")))))
    (is (equal '(:epure) (id:classification-products c)))
    (is (string= "unknown (EPURE)" (id:classification-label c)))))

;;; --- JSON shape --------------------------------------------------

(test report-json-is-wellformed-ish
  (let* ((c (id:classify-drawing (drawing-with-appids '("PV")) "x.dwg"))
         (s (with-output-to-string (out) (id:report-json c out))))
    (is (search "\"application\":\"PV\"" s))
    (is (search "\"products\":[\"pv\"]" s))
    (is (search "\"source\":\"x.dwg\"" s))))
