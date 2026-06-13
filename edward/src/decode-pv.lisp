(in-package #:edward)

;;;; PV decoder — the flat, legacy PV2010 model (pv/arx/PV2010/PvXDATA.lsp).
;;;;
;;;; PV xdata under appid "PV" is a single brace-delimited block of exactly
;;;; five string fields, with no class name and no schema version:
;;;;   (1002 . "{") (1000 . <v1>) … (1000 . <v5>) (1002 . "}")
;;;; The five fields, in order (pv2010.dcl):

(defparameter *pv-field-names*
  '("designation" "symbole" "document_reference" "commentaire_1" "commentaire_2")
  "The five PV attribute fields, in storage order.")

(defun pv-decoded->json (pairs)
  "Decode a PV xdata group (the pairs following the (1001 . \"PV\") marker)
into the five named string fields. Extra/missing values are reported as
divergences; the raw is kept by the caller."
  (let* ((values (loop for p in pairs
                       when (and (consp p) (eql (car p) 1000))
                         collect (cdr p)))
         (n (length values))
         (fields (loop for name in *pv-field-names*
                       for rest = values then (cdr rest)
                       collect (cons name (or (car rest) :null))))
         (divs (cond ((= n 5) '())
                     (t (list (format nil "expected 5 fields, got ~A" n))))))
    (jobj "fields" (cons :object fields)
          "divergences" (jarr divs))))
