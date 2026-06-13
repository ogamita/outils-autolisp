(in-package #:edward)

;;;; Mapping of raw DXF entries to JSON values (the lossless "raw" layer).
;;;;
;;;; A DXF entry is (CODE . VALUE) for a scalar, or (CODE X Y Z) for a
;;;; coalesced point. Each entry is emitted as a two-element JSON array
;;;; [CODE, VALUE]; a point VALUE becomes a nested array [X, Y, Z]. No data
;;;; is dropped or reinterpreted here.

(defun dxf-value->json (value)
  "Convert a DXF entry's VALUE (an atom, or a proper list for a point) to
a JSON value."
  (cond
    ((stringp value) value)
    ((numberp value) value)
    ((null value)    "")            ; empty string value, keep as ""
    ((consp value)   (jarr (mapcar #'dxf-value->json value)))
    (t               (princ-to-string value))))

(defun dxf-pair->json (pair)
  "Convert a DXF entry (CODE . VALUE) to the JSON array [CODE, VALUE]."
  (jarr (list (dxf-pair-code pair)
              (dxf-value->json (dxf-pair-value pair)))))

(defun dxf-data->json (data)
  "Convert a list of DXF entries to a JSON array of [CODE, VALUE] arrays."
  (jarr (mapcar #'dxf-pair->json (remove-if-not #'consp data))))

(defun dxf-assoc (code data)
  "The VALUE of the first DXF entry with group CODE in DATA, or NIL."
  (let ((p (assoc code data :test #'eql)))
    (and p (dxf-pair-value p))))
