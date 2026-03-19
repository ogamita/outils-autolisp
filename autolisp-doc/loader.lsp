;;; loader.lsp --- Load autolisp-doc from an explicit root directory

(defun autolisp-doc-load-library (ad-root /)
  (clload-files ad-root
                '("src/autolisp-ref.lsp"
                  "src/autolisp-doc.lsp")
                nil)
  (princ))

(if (not (boundp '*autolisp-doc-path*))
  (setq *autolisp-doc-path* "."))

(load (strcat *autolisp-doc-path* "/../cl-loader.lsp"))

(autolisp-doc-load-library *autolisp-doc-path*)

(princ)

;;; loader.lsp ends here
