
(defun write-line-to (path s)
  (if (and path (/= path ""))
    (progn
      (setq f (open path "a"))
      (if f (progn (write-line s f) (close f))))))

(defun set-status (code)
  (write-line-to (getenv "STATUSFILE") (itoa code)))

(defun log-out (s) (write-line-to (getenv "OUTFILE") s))
(defun log-err (s) (write-line-to (getenv "ERRFILE") s))

(defun C:MAIN ( / )
  (setq *error*
    (lambda (msg)
      (log-err (strcat "ERROR: " msg))
      (set-status 1)
      (princ)))

  (log-out "Hello from AutoLISP.")
  ;; ... ton code ...
  (set-status 0)
  (princ))
