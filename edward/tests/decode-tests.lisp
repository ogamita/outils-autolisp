(in-package #:edward.tests)
(in-suite edward-suite)

;;; *_ATTR.LSP schema loading + validation (schema-attr.lisp), and PV.

(test class-file-resolution
  (let ((p (edward::%class-file "/es/schms/bd/voie" "/root/")))
    (is (string-equal "VOIE_ATTR" (pathname-name p)))
    (is (string-equal "LSP" (pathname-type p)))
    ;; the <dir> segment is upper-cased ("bd" -> "BD")
    (is (member "BD" (pathname-directory p) :test #'string=))))

(defun %write-cp1252 (path text)
  (ensure-directories-exist path)
  (with-open-file (s path :direction :output :if-exists :supersede
                          :if-does-not-exist :create :external-format :cp1252)
    (write-string text s)))

(test schema-load-inclure-and-validate
  (let* ((root (merge-pathnames "edward-schema-test/" (uiop:temporary-directory)))
         (edward::*schema-root* root)
         (edward::*class-cache* (make-hash-table :test #'equal)))
    (%write-cp1252
     (merge-pathnames "BD/VOIE_ATTR.LSP" root)
     "( (NOM_DAFFICHAGE . \"Voie\") (CATEGORIES \"Non graphique\")
        (SCHEMAS
          (2 \"v2\" (\"UUID\" chaine) (\"NOM_VOIE\" chaine)
                    (@inclure \"/es/schms/commun/etats\" 1))
          (1 \"v1\" (\"NOM_VOIE\" chaine))) )")
    (%write-cp1252                        ; accented text exercises cp1252
     (merge-pathnames "COMMUN/ETATS_ATTR.LSP" root)
     "( (NOM_DAFFICHAGE . \"États\") (SCHEMAS (1 \"x\" (\"FIXE\" booleen))) )")
    (let ((c (edward::load-class "/es/schms/bd/voie")))
      (is (not (null c)))
      (is (string= "Voie" (edward::sc-display-name c)))
      ;; @inclure spliced the etats FIXE field into v2 (not v1)
      (let ((v2 (edward::class-version-fields c 2))
            (v1 (edward::class-version-fields c 1)))
        (is (assoc "UUID" v2 :test #'string=))
        (is (assoc "FIXE" v2 :test #'string=))
        (is (null (assoc "FIXE" v1 :test #'string=))))
      ;; conformant instance: no divergences
      (is (null (edward::validate-instance
                 "/es/schms/bd/voie" 2
                 '(("UUID" . "u") ("NOM_VOIE" . "DEPOT") ("FIXE" . 1)))))
      ;; unknown field is flagged
      (is (find :unknown-field (edward::validate-instance
                                "/es/schms/bd/voie" 2 '(("ZZZ" . "x")))
                :key (lambda (d) (getf d :kind))))
      ;; unknown version is flagged
      (is (find :unknown-version (edward::validate-instance
                                  "/es/schms/bd/voie" 9 '())
                :key (lambda (d) (getf d :kind))))
      ;; cp1252 accented display name decoded correctly (É = U+00C9)
      (is (string= "États" (edward::sc-display-name
                            (edward::load-class "/es/schms/commun/etats")))))))

(test pv-decode-five-fields
  (let ((json (with-output-to-string (s)
                (edward:json-emit
                 (edward::pv-decoded->json
                  '((1002 . "{") (1000 . "DES") (1000 . "SYM") (1000 . "DOC")
                    (1000 . "C1") (1000 . "C2") (1002 . "}")))
                 s nil))))
    (is (search "\"designation\":\"DES\"" json))
    (is (search "\"document_reference\":\"DOC\"" json))
    (is (search "\"commentaire_2\":\"C2\"" json))
    (is (search "\"divergences\":[]" json))))

(test pv-decode-wrong-arity-flagged
  (let ((json (with-output-to-string (s)
                (edward:json-emit
                 (edward::pv-decoded->json '((1000 . "only-one"))) s nil))))
    (is (search "expected 5 fields, got 1" json))))
