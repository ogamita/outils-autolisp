(in-package #:edward)

;;;; V1 — assemble a lossless JSON dump of a drawing's EPURE data, and the
;;;; round-trip fidelity check (§4.4 of the specifications).
;;;;
;;;; This is the generic *raw* layer: it groups entity xdata by appid and
;;;; walks the named-object dictionary, emitting every DXF entry verbatim.
;;;; Application-specific decoding (SCHMS schema, PV) is layered on top in M2.

(defparameter *edward-version* "0.1.0"
  "edward version, reported in the dump and by -V/--version.")

(defun %keyword-downcase (kw)
  (if kw (string-downcase (symbol-name kw)) "unknown"))

(defun %xdata->json (xdata-groups)
  "A JSON object {APPID: [raw entries...]} from ENTITY-XDATA groups, or
:NULL when there is no xdata."
  (if xdata-groups
      (cons :object
            (mapcar (lambda (g) (cons (car g) (dxf-data->json (cdr g))))
                    xdata-groups))
      :null))

(defun %entity->json (entity &key raw)
  "JSON for one entity: handle, type, layer, block, xdata (grouped by
appid). With RAW, also the full raw DXF data."
  (let* ((data  (dwg:entity-dxf entity))
         (xdata (entity-xdata entity))
         (block (dwg:entity-handle-block entity))
         (pairs (list (cons "handle" (dwg:entity-handle-string entity))
                      (cons "type"   (string-upcase (symbol-name (dwg:entity-kind entity))))
                      (cons "layer"  (or (dxf-assoc 8 data) :null))
                      (cons "block"  (or block :null))
                      (cons "xdata"  (%xdata->json xdata)))))
    (when raw
      (setf pairs (append pairs (list (cons "data" (dxf-data->json data))))))
    (cons :object pairs)))

(defun %dictionary-records (drawing)
  "Collect the leaf entries of the NOD (those pointing at an object or
entity), sorted by (path, key). Each record carries its dictionary path,
key, target handle, and — when it resolves to a stored object (e.g. an
XRECORD) — that object's raw DXF data."
  (let ((records '()))
    (walk-dictionaries
     drawing
     (lambda (path key value)
       (cond
         ((dwg:dictionary-p value) nil) ; structural node; recursed into
         ((stringp value)
          (let ((obj (dwg:find-object drawing value)))
            (push (list path key value obj) records)))
         ((dwg:entity-handle-p value)
          (push (list path key (dwg:entity-handle-string value) nil) records))
         (t (push (list path key (princ-to-string value) nil) records)))))
    (stable-sort (nreverse records)
                 (lambda (a b)
                   (let ((pa (format nil "~{~A/~}~A" (first a) (second a)))
                         (pb (format nil "~{~A/~}~A" (first b) (second b))))
                     (string< pa pb))))))

(defun %dictionaries->json (drawing)
  "A JSON array of dictionary leaf records (XRECORDs etc.) under the NOD."
  (jarr
   (mapcar
    (lambda (rec)
      (destructuring-bind (path key handle object) rec
        (let* ((stream (and object (xrecord-instance-pairs object)))
               (decoded (when stream
                          (multiple-value-bind (instances divergences)
                              (decode-instance-stream stream *xrecord-codec*)
                            (decoded->json instances divergences)))))
          (cons :object
                (list (cons "dictionary" (format nil "~{~A~^/~}" (or path '(""))))
                      (cons "path"    (jarr (mapcar (lambda (s) s) path)))
                      (cons "key"     key)
                      (cons "handle"  handle)
                      (cons "decoded" (or decoded :null))
                      (cons "object"  (if object (dxf-data->json object) :null)))))))
    (%dictionary-records drawing))))

(defun dump-drawing (drawing &key source raw (entities t) (dictionaries t))
  "Build the JSON dump value for DRAWING. SOURCE labels the report.
RAW adds each entity's full DXF data. ENTITIES / DICTIONARIES toggle the
respective sections."
  (let* ((appids (drawing-appids drawing))
         (class  (id:classify-drawing drawing source))
         (pairs  (list
                  (cons "edward" *edward-version*)
                  (cons "source" (or (and source (princ-to-string source)) :null))
                  (cons "format" (%keyword-downcase (dwg:drawing-format drawing)))
                  (cons "application" (id:classification-label class))
                  (cons "drawing"
                        (jobj "version"      (%keyword-downcase (dwg:drawing-version drawing))
                              "codepage"     (or (dwg:drawing-codepage drawing) :null)
                              "entity_count" (dwg:drawing-entity-count drawing)
                              "appids"       (jarr appids))))))
    (when dictionaries
      (setf pairs (append pairs (list (cons "dictionaries" (%dictionaries->json drawing))))))
    (when entities
      (let ((es '()))
        (dwg:map-entities (lambda (e) (push (%entity->json e :raw raw) es)) drawing)
        (setf pairs (append pairs (list (cons "entities" (jarr (nreverse es))))))))
    (cons :object pairs)))

(defun dump-file (path &key (stream *standard-output*) (pretty t) raw
                            (entities t) (dictionaries t))
  "Read the drawing at PATH and emit its JSON dump to STREAM."
  (let ((drawing (read-drawing path)))
    (json-emit (dump-drawing drawing :source path :raw raw
                             :entities entities :dictionaries dictionaries)
               stream pretty)
    (when pretty (terpri stream))
    (values)))

;;;; --- DXF export (hand a drawing to BricsCAD/AutoCAD) ------------------

(defun export-file (path out &key (encoding :utf-8))
  "Read the drawing at PATH and write it as ASCII DXF to OUT. ENCODING is
the character encoding of the DXF (:utf-8 by default — lossless; try
:iso-8859-1 if the target CAD expects a code-page DXF). Intended for the
mean-time workflow where edward emits DXF that BricsCAD/AutoCAD re-saves
as native (R2018) DWG, since libredwg cannot yet write R2018."
  (let ((drawing (read-drawing path)))
    (dwg:dxf-write-drawing drawing out :external-format encoding)
    out))

;;;; --- Round-trip fidelity (V1 acceptance, §4.4) ------------------------

(defun %canonical-dump (drawing)
  "A compact, source-independent dump string used to compare a drawing
with its round-tripped self (full raw data, all sections)."
  (with-output-to-string (s)
    (json-emit (dump-drawing drawing :source nil :raw t
                             :entities t :dictionaries t)
               s nil)))

(defun %format-type (fmt)
  "A filename type string for an intermediate drawing of format FMT."
  (case fmt
    ((:dxf-ascii :dxf-binary) "dxf")
    (:dwg "dwg")
    (t (string-downcase (symbol-name fmt)))))

(defun roundtrip-file (path &key (stream *standard-output*) via)
  "Read PATH, write it back out, read it again, and compare the two
canonical dumps. The intermediate write uses VIA (a format keyword, e.g.
:dxf-ascii) when supplied, else the drawing's own format. Reports the
outcome to STREAM. Returns T when the round-trip is lossless (for edward's
data model), NIL otherwise.

Note: native DWG write goes through libredwg, whose writer is not reliable
on real SNCF drawings (it mangles cp1252 text and can produce files that
crash the reader); use VIA :dxf-ascii to exercise clautolisp's own codec."
  (let* ((original (read-drawing path))
         (fmt      (or via (dwg:drawing-format original)))
         (type     (%format-type fmt)))
    (uiop:with-temporary-file (:pathname tmp :type type :keep nil)
      (dwg:write-drawing original tmp :format fmt)
      (let* ((reloaded (read-drawing tmp))
             (a (%canonical-dump original))
             (b (%canonical-dump reloaded))
             (ok (string= a b)))
        (format stream "~&~A~%  round-trip  : ~:[DIVERGENT~;lossless~]~%  format      : ~A~%  entities    : ~A -> ~A~%  appids      : ~A -> ~A~%"
                path ok (%keyword-downcase fmt)
                (dwg:drawing-entity-count original) (dwg:drawing-entity-count reloaded)
                (length (drawing-appids original)) (length (drawing-appids reloaded)))
        (unless ok
          (format stream "  (canonical dumps differ: ~A vs ~A chars)~%"
                  (length a) (length b)))
        ok))))
