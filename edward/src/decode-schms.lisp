(in-package #:edward)

;;;; SCHMS decoding = structural decode (codec-xdata.lisp) informed by the
;;;; *_ATTR.LSP schema (schema-attr.lisp), faithful to the raw data.
;;;;
;;;; Each instance is emitted with its class, version and named fields; per
;;;; instance, schema validation adds divergence annotations (unknown class /
;;;; version / field, type mismatch). With no --schema-root, validation is
;;;; skipped and only the structural form (+ structural divergences) is kept.
;;;; The caller always keeps the raw pairs too, so nothing is ever lost.

(defun %divergence->string (d)
  "Render a divergence plist as a short string for the JSON report."
  (format nil "~(~A~)~{ ~A~}"
          (getf d :kind)
          (loop for (k v) on d by #'cddr
                unless (eq k :kind)
                  collect (format nil "~(~A~)=~A" k v))))

(defun %schms-instance->json (instance)
  "JSON for one decoded instance, validated against its schema."
  (let* ((class   (getf instance :class))
         (version (getf instance :version))
         (fields  (getf instance :fields))
         (schema-divs (validate-instance class version fields)))
    (jobj "class"        (or class :null)
          "version"      (or version :null)
          "display_name" (let ((c (and class (load-class class))))
                           (or (and c (sc-display-name c)) :null))
          "fields"       (decoded-fields->json fields)
          "divergences"  (jarr (mapcar #'%divergence->string schema-divs)))))

(defun schms-decoded->json (stream codec)
  "Decode the SCHMS instance STREAM with CODEC, validate each instance
against its *_ATTR.LSP schema, and return a JSON object
{instances:[…], divergences:[…]}."
  (multiple-value-bind (instances structural-divs)
      (decode-instance-stream stream codec)
    (jobj "instances"   (jarr (mapcar #'%schms-instance->json instances))
          "divergences" (jarr (mapcar #'%divergence->string structural-divs)))))
