;;; cl-loader.lsp --- Small Common Lisp inspired loader helpers

(if (not (boundp '*verbose*))
  (setq *verbose* nil))

(defun cl-loader-option (cl-key cl-options cl-default / cl-entry)
  (setq cl-entry (assoc cl-key cl-options))
  (if cl-entry
    (cdr cl-entry)
    cl-default))

(defun cl-loader-message (cl-action cl-path /)
  (princ "\n[clload] ")
  (princ cl-action)
  (princ " ")
  (princ cl-path))

(defun cl-path-join (cl-root cl-relative-path /)
  (strcat cl-root "/" cl-relative-path))

(defun clload (cl-path cl-options / cl-loader cl-verbose cl-result)
  (setq cl-loader (cl-loader-option 'loader cl-options 'load))
  (setq cl-verbose (cl-loader-option 'verbose cl-options *verbose*))
  (if (findfile cl-path)
    (progn
      (if cl-verbose
        (cl-loader-message "loading" cl-path))
      (setq cl-result (eval (list cl-loader cl-path)))
      (if cl-verbose
        (cl-loader-message "loaded " cl-path))
      cl-result)
    (error (strcat "clload: file not found: " cl-path))))

(defun clload-files (cl-root cl-relative-paths cl-options / cl-relative-path)
  (foreach cl-relative-path cl-relative-paths
    (clload (cl-path-join cl-root cl-relative-path) cl-options)))

(princ)

;;; cl-loader.lsp ends here
