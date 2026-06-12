(in-package #:dwg-identifier)

;;;; Human-readable and JSON reporting, plus the command-line driver.

(defparameter *program-name* "dwg-identify"
  "Name used in usage/version/diagnostic messages and as the installed
executable name.")

(defparameter *version* "1.0.0"
  "dwg-identify version, reported by -V/--version.")

(defun report (classification &optional (stream *standard-output*) verbose)
  "Print a human-readable one-block report for CLASSIFICATION. When
VERBOSE, also print the products, the +/EPURE flags and schema versions."
  (format stream "~&~A~%  application : ~A~%  format      : ~A~%  entities    : ~A~%  appids      : ~{~A~^ ~}~%"
          (classification-source classification)
          (classification-label classification)
          (or (classification-format classification) "?")
          (classification-entity-count classification)
          (classification-appids classification))
  (when verbose
    (format stream "  products    : ~{~A~^ ~}~%  plus        : ~A~%  epure       : ~A~%"
            (mapcar (lambda (k) (string-downcase (symbol-name k)))
                    (classification-products classification))
            (if (classification-plus-p classification) "yes" "no")
            (if (classification-epure-p classification) "yes" "no")))
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
  ;; Line by line so the option indentation is preserved (format's
  ;; ~<newline> directive would otherwise trim the leading spaces).
  (format stream "~&usage: ~A [-h|--help] [-V|--version] [-v|--verbose] [--json] FILE.dwg|FILE.dxf ...~%"
          *program-name*)
  (dolist (line '("Identify the SNCF application (SCHMS / SCHME / SCHMIEUX / PV / EPURE)"
                  "that produced each drawing, by its registered-application (APPID) table."
                  ""
                  "  -h, --help     show this help and exit"
                  "  -V, --version  show the version and exit"
                  "  -v, --verbose  also report products and the +/EPURE flags"
                  "      --json     emit one JSON object per file instead of the text block"))
    (write-string line stream)
    (terpri stream)))

(defun print-version (&optional (stream *standard-output*))
  (format stream "~&~A ~A~%" *program-name* *version*))

(defun main (&optional (args (uiop:command-line-arguments)))
  "CLI entry point. Returns a Unix exit status (0 ok, 1 a file failed,
2 usage error). Recognises -h/--help, -V/--version, -v/--verbose, --json,
a -- end-of-options marker, then one or more drawing files."
  (let ((json nil) (verbose nil) (paths '()) (status 0) (opts-done nil))
    (dolist (a args)
      (cond
        (opts-done (push a paths))
        ((string= a "--") (setf opts-done t))
        ((or (string= a "-h") (string= a "--help"))
         (print-usage *standard-output*)
         (return-from main 0))
        ((or (string= a "-V") (string= a "--version"))
         (print-version)
         (return-from main 0))
        ((or (string= a "-v") (string= a "--verbose")) (setf verbose t))
        ((string= a "--json") (setf json t))
        ((and (> (length a) 0) (char= (char a 0) #\-))
         (format *error-output* "~&~A: unknown option: ~A~%" *program-name* a)
         (print-usage)
         (return-from main 2))
        (t (push a paths))))
    (setf paths (nreverse paths))
    (when (null paths)
      (print-usage)
      (return-from main 2))
    (dolist (p paths)
      (handler-case
          (let ((c (identify-file p)))
            (if json (report-json c) (report c *standard-output* verbose)))
        (error (e)
          (setf status 1)
          (format *error-output* "~&~A: error: ~A~%" p e))))
    status))

(defun %toplevel ()
  "Entry point for the saved `dwg-identify' executable: run MAIN on the
command-line arguments and exit with its status."
  (uiop:quit
   (handler-case (main (uiop:command-line-arguments))
     (error (e)
       (format *error-output* "~&~A: ~A~%" *program-name* e)
       70))))
