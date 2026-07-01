;;; loader.lsp --- Charge le module autolisp-json

(defun autolisp-json-loader-root (/ loader-path)
  (cond
    ((and (boundp '*autolisp-json-path*)
          *autolisp-json-path*)
     *autolisp-json-path*)
    ((setq loader-path (findfile "autolisp-json/loader.lsp"))
     (vl-filename-directory loader-path))
    ((setq loader-path (findfile "loader.lsp"))
     (vl-filename-directory loader-path))
    (t nil)))

(setq *autolisp-json-path* (autolisp-json-loader-root))

(if (null *autolisp-json-path*)
  (progn
    (prompt
      "\n[loader] Error: cannot resolve autolisp-json/loader.lsp. Set *autolisp-json-path* or load this file with an absolute path, then retry.")
    (exit)))

(load (strcat *autolisp-json-path* "/../cl-loader.lsp"))

(clload (cl-path-join *autolisp-json-path* "src/autolisp-json.lsp") nil)

(princ)

;;; loader.lsp ends here
