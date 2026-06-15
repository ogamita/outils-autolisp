(in-package #:edward)

;;;; Command-line driver for edward (v1: dump / list / roundtrip).

(defparameter *program-name* "edward")

(defun print-usage (&optional (stream *error-output*))
  (format stream "~&usage: ~A [-h|--help] [-V|--version] <command> [options] FILE...~%~%"
          *program-name*)
  (dolist (line '("Dump and inspect the EPURE application data stored in DWG/DXF drawings."
                  ""
                  "Commands:"
                  "  dump        dump application data + entities as JSON"
                  "  list        one-line classification per drawing (reuses dwg-identifier)"
                  "  roundtrip   read -> rewrite -> reread and check for loss (V1 acceptance)"
                  "  export      write the drawing as ASCII DXF (for BricsCAD/AutoCAD -> DWG)"
                  "  validate    run the validation rules (libredwg-bug / CAD-standards checks)"
                  "  repl        interactive explorer REPL (Lisp): edward repl [FILE]"
                  "  eval        evaluate one explorer form: edward eval 'FORM' [FILE]"
                  "  script      evaluate explorer forms read from stdin: edward script [FILE]"
                  ""
                  "Global options:"
                  "  -h, --help        show this help and exit"
                  "  -V, --version     show the version and exit"
                  "  -v, --verbose     more detail"
                  "  -o, --output FILE write output to FILE instead of stdout"
                  ""
                  "dump options:"
                  "      --pretty      indent the JSON (default)"
                  "      --compact     single-line JSON"
                  "      --raw         include each entity's full raw DXF data"
                  "      --no-entities        omit the entities section"
                  "      --entities-only      omit the dictionaries section"
                  "      --no-dictionaries    omit the dictionaries section"
                  "      --schema-root DIR    SCHMS *_ATTR.LSP tree (enables validation)"
                  "      --no-schema          structural decode only (no validation)"
                  ""
                  "export options:"
                  "      --encoding E  DXF text encoding: utf-8 (default) | cp1252 | latin-1"
                  ""
                  "validate options:"
                  "      --json        emit the findings as JSON"
                  "      --schema-root DIR    enable schema-divergence checks"
                  ""
                  "list options:"
                  "      --json        one JSON object per file"))
    (write-string line stream)
    (terpri stream)))

(defun print-version (&optional (stream *standard-output*))
  (format stream "~&~A ~A~%" *program-name* *edward-version*))

(defun %with-output (output-path fn)
  "Call FN with an output stream: OUTPUT-PATH's file, or *standard-output*."
  (if output-path
      (with-open-file (s output-path :direction :output
                                     :if-exists :supersede :if-does-not-exist :create
                                     :external-format :utf-8)
        (funcall fn s))
      (funcall fn *standard-output*)))

(defun %cmd-dump (paths &key pretty raw entities dictionaries output schema-root)
  (let ((status 0)
        (*schema-root* schema-root))
    (%with-output output
      (lambda (stream)
        (dolist (p paths)
          (handler-case
              (dump-file p :stream stream :pretty pretty :raw raw
                           :entities entities :dictionaries dictionaries)
            (error (e)
              (setf status 1)
              (format *error-output* "~&~A: error: ~A~%" p e))))))
    status))

(defun %cmd-list (paths &key json verbose output)
  (let ((status 0))
    (%with-output output
      (lambda (stream)
        (dolist (p paths)
          (handler-case
              (let ((c (id:identify-file p)))
                (if json (id:report-json c stream) (id:report c stream verbose)))
            (error (e)
              (setf status 1)
              (format *error-output* "~&~A: error: ~A~%" p e))))))
    status))

(defun %cmd-export (paths &key output encoding)
  "Export drawing(s) to ASCII DXF. With one input and --output, write to
that path; otherwise write each input alongside it with a .dxf type."
  (let ((status 0)
        (enc (cond ((null encoding) :utf-8)
                   ((string-equal encoding "utf-8") :utf-8)
                   ((or (string-equal encoding "cp1252")
                        (string-equal encoding "ansi")
                        (string-equal encoding "windows-1252")) :cp1252)
                   ((or (string-equal encoding "latin-1")
                        (string-equal encoding "iso-8859-1")) :iso-8859-1)
                   (t :utf-8))))
    (dolist (p paths)
      (handler-case
          (let ((out (or (and output (= (length paths) 1) output)
                         (make-pathname :type "dxf" :defaults (pathname p)))))
            (export-file p out :encoding enc)
            (format *error-output* "~&wrote ~A~%" out))
        (error (e)
          (setf status 1)
          (format *error-output* "~&~A: error: ~A~%" p e))))
    status))

(defun %cmd-transfer (paths &key output)
  "edward transfer SOURCE DEST -o OUT: copy the SCHMS BD dictionaries
(LIGNES/VOIES/POSTES) from SOURCE into DEST and write the result to OUT
(DXF when OUT ends in .dxf, else native DWG)."
  (cond
    ((/= (length paths) 2)
     (format *error-output* "~&~A: transfer needs SOURCE and DEST drawings~%" *program-name*) 2)
    ((null output)
     (format *error-output* "~&~A: transfer needs -o OUTPUT~%" *program-name*) 2)
    (t
     (handler-case
         (let ((report (transfer-bd-file (first paths) (second paths) output)))
           (format *error-output* "~&transferred ~A + ~A -> ~A~%"
                   (first paths) (second paths) output)
           (if report
               (dolist (e report)
                 (format *error-output* "  ~A: ~A entries~%" (car e) (cdr e)))
               (format *error-output* "  (no BD dictionaries found in source)~%"))
           0)
       (error (e)
         (format *error-output* "~&~A: error: ~A~%" *program-name* e) 1)))))

(defun %cmd-validate (paths &key json schema-root output)
  "edward validate FILE...: run the validation rules and report findings.
Returns 1 if any file has an error-severity finding (or fails to read)."
  (let ((status 0))
    (%with-output output
      (lambda (stream)
        (dolist (p paths)
          (handler-case
              (unless (validate-file p :json json :schema-root schema-root :stream stream)
                (setf status 1))
            (error (e)
              (setf status 1)
              (format *error-output* "~&~A: error: ~A~%" p e))))))
    status))

(defun %cmd-repl (paths &key schema-root)
  "edward repl [FILE]: interactive explorer REPL."
  (run-repl (first paths) :schema-root schema-root))

(defun %cmd-eval (paths &key schema-root)
  "edward eval FORM [FILE]: evaluate one explorer form."
  (if (null paths)
      (progn (format *error-output* "~&~A: eval needs a FORM argument~%" *program-name*) 2)
      (run-eval (first paths) (second paths) :schema-root schema-root)))

(defun %cmd-script (paths &key schema-root)
  "edward script [FILE]: evaluate explorer forms read from stdin."
  (run-script (first paths) :schema-root schema-root))

(defun %cmd-roundtrip (paths &key output via)
  (let ((status 0))
    (%with-output output
      (lambda (stream)
        (dolist (p paths)
          (handler-case
              (unless (roundtrip-file p :stream stream :via via)
                (setf status 1))
            (error (e)
              (setf status 1)
              (format *error-output* "~&~A: error: ~A~%" p e))))))
    status))

(defun main (&optional (args (uiop:command-line-arguments)))
  "CLI entry point. Returns a Unix exit status (0 ok, 1 a file failed or a
round-trip diverged, 2 usage error)."
  (let ((command nil) (paths '()) (output nil)
        (verbose nil) (json nil) (pretty t) (raw nil)
        (entities t) (dictionaries t) (via nil) (encoding nil) (schema-root nil)
        (rest args))
    ;; Leading global flags that short-circuit.
    (loop while rest
          for a = (car rest)
          do (cond
               ((or (string= a "-h") (string= a "--help"))
                (print-usage *standard-output*) (return-from main 0))
               ((or (string= a "-V") (string= a "--version"))
                (print-version) (return-from main 0))
               (t (return))))
    (when (null rest)
      (print-usage) (return-from main 2))
    ;; Command.
    (setf command (pop rest))
    (unless (member command '("dump" "list" "roundtrip" "export" "transfer"
                              "validate" "repl" "eval" "script")
                    :test #'string=)
      (format *error-output* "~&~A: unknown command: ~A~%" *program-name* command)
      (print-usage) (return-from main 2))
    ;; Options + files.
    (loop while rest
          for a = (pop rest)
          do (cond
               ((or (string= a "-h") (string= a "--help"))
                (print-usage *standard-output*) (return-from main 0))
               ((or (string= a "-v") (string= a "--verbose")) (setf verbose t))
               ((or (string= a "-o") (string= a "--output"))
                (when (null rest)
                  (format *error-output* "~&~A: ~A requires an argument~%" *program-name* a)
                  (return-from main 2))
                (setf output (pop rest)))
               ((string= a "--via")
                (when (null rest)
                  (format *error-output* "~&~A: --via requires an argument~%" *program-name*)
                  (return-from main 2))
                (let ((v (pop rest)))
                  (setf via (cond ((string-equal v "dxf") :dxf-ascii)
                                  ((string-equal v "dxf-binary") :dxf-binary)
                                  ((string-equal v "dwg") :dwg)
                                  (t (format *error-output* "~&~A: unknown --via format: ~A~%" *program-name* v)
                                     (return-from main 2))))))
               ((string= a "--encoding")
                (when (null rest)
                  (format *error-output* "~&~A: --encoding requires an argument~%" *program-name*)
                  (return-from main 2))
                (setf encoding (pop rest)))
               ((string= a "--schema-root")
                (when (null rest)
                  (format *error-output* "~&~A: --schema-root requires an argument~%" *program-name*)
                  (return-from main 2))
                (setf schema-root (pop rest)))
               ((string= a "--no-schema") (setf schema-root nil))
               ((string= a "--json")    (setf json t))
               ((string= a "--pretty")  (setf pretty t))
               ((string= a "--compact") (setf pretty nil))
               ((string= a "--raw")     (setf raw t))
               ((string= a "--no-entities")     (setf entities nil))
               ((string= a "--entities-only")   (setf dictionaries nil))
               ((string= a "--no-dictionaries") (setf dictionaries nil))
               ((string= a "--") (setf paths (append paths rest) rest nil))
               ((and (> (length a) 0) (char= (char a 0) #\-))
                (format *error-output* "~&~A: unknown option: ~A~%" *program-name* a)
                (print-usage) (return-from main 2))
               (t (push a paths))))
    (setf paths (nreverse paths))
    (when (and (null paths)
               (not (member command '("repl" "script") :test #'string=)))
      (format *error-output* "~&~A: ~A: no input files~%" *program-name* command)
      (return-from main 2))
    (cond
      ((string= command "dump")
       (%cmd-dump paths :pretty pretty :raw raw :entities entities
                        :dictionaries dictionaries :output output
                        :schema-root schema-root))
      ((string= command "list")
       (%cmd-list paths :json json :verbose verbose :output output))
      ((string= command "roundtrip")
       (%cmd-roundtrip paths :output output :via via))
      ((string= command "transfer")
       (%cmd-transfer paths :output output))
      ((string= command "export")
       (%cmd-export paths :output output :encoding encoding))
      ((string= command "validate")
       (%cmd-validate paths :json json :schema-root schema-root :output output))
      ((string= command "repl")
       (%cmd-repl paths :schema-root schema-root))
      ((string= command "eval")
       (%cmd-eval paths :schema-root schema-root))
      ((string= command "script")
       (%cmd-script paths :schema-root schema-root)))))

(defun %toplevel ()
  "Entry point for the saved `edward' executable."
  (uiop:quit
   (handler-case (main (uiop:command-line-arguments))
     (error (e)
       (format *error-output* "~&~A: ~A~%" *program-name* e)
       70))))
