(in-package #:dwg-identifier)

;;;; Human-readable and JSON reporting, plus the command-line driver.

(defun report (classification &optional (stream *standard-output*))
  "Print a human-readable one-block report for CLASSIFICATION."
  (format stream "~&~A~%  application : ~A~%  format      : ~A~%  entities    : ~A~%  appids      : ~{~A~^ ~}~%"
          (classification-source classification)
          (classification-label classification)
          (or (classification-format classification) "?")
          (classification-entity-count classification)
          (classification-appids classification))
  (values))

(defun %json-string (s)
  "Quote and escape S as a JSON string."
  (with-output-to-string (o)
    (write-char #\" o)
    (loop for ch across (princ-to-string s)
          do (case ch
               (#\" (write-string "\\\"" o))
               (#\\ (write-string "\\\\" o))
               (#\Newline (write-string "\\n" o))
               (#\Return (write-string "\\r" o))
               (#\Tab (write-string "\\t" o))
               (t (write-char ch o))))
    (write-char #\" o)))

(defun report-json (classification &optional (stream *standard-output*))
  "Print CLASSIFICATION as a single-line JSON object."
  (format stream "~&{\"source\":~A,\"application\":~A,\"format\":~A,\"products\":[~{~A~^,~}],\"plus\":~A,\"epure\":~A,\"entities\":~A,\"appids\":[~{~A~^,~}]}~%"
          (%json-string (classification-source classification))
          (%json-string (classification-label classification))
          (%json-string (string-downcase (symbol-name
                                          (or (classification-format classification) :unknown))))
          (mapcar (lambda (k) (%json-string (string-downcase (symbol-name k))))
                  (classification-products classification))
          (if (classification-plus-p classification) "true" "false")
          (if (classification-epure-p classification) "true" "false")
          (classification-entity-count classification)
          (mapcar #'%json-string (classification-appids classification)))
  (values))

(defun print-usage (&optional (stream *error-output*))
  (format stream "~&usage: dwg-identifier [--json] FILE.dwg|FILE.dxf ...~%~
Identify the SNCF application (SCHMS / SCHME / SCHMIEUX / PV / EPURE)~%~
that produced each drawing, by its registered-application (APPID) table.~%"))

(defun main (&optional (args (uiop:command-line-arguments)))
  "CLI entry point. Returns a Unix exit status (0 ok, 1 a file failed,
2 usage error)."
  (let ((json nil) (paths '()) (status 0))
    (dolist (a args)
      (cond ((string= a "--json") (setf json t))
            ((or (string= a "-h") (string= a "--help"))
             (print-usage *standard-output*)
             (return-from main 0))
            ((and (> (length a) 0) (char= (char a 0) #\-))
             (format *error-output* "~&dwg-identifier: unknown option: ~A~%" a)
             (return-from main 2))
            (t (push a paths))))
    (setf paths (nreverse paths))
    (when (null paths)
      (print-usage)
      (return-from main 2))
    (dolist (p paths)
      (handler-case
          (let ((c (identify-file p)))
            (if json (report-json c) (report c)))
        (error (e)
          (setf status 1)
          (format *error-output* "~&~A: error: ~A~%" p e))))
    status))
