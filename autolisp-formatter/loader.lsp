;;; loader.lsp --- Charge le module autolisp-formatter

(defun autolisp-formatter-loader-root (/ loader-path)
  (cond
    ((and (boundp '*autolisp-formatter-path*)
          *autolisp-formatter-path*)
     *autolisp-formatter-path*)
    ((setq loader-path (findfile "autolisp-formatter/loader.lsp"))
     (vl-filename-directory loader-path))
    ((setq loader-path (findfile "loader.lsp"))
     (vl-filename-directory loader-path))
    (t nil)))

(setq *autolisp-formatter-path* (autolisp-formatter-loader-root))

(if (null *autolisp-formatter-path*)
  (progn
    (prompt
      "\n[loader] Error: cannot resolve autolisp-formatter/loader.lsp. Set *autolisp-formatter-path* or load this file with an absolute path, then retry.")
    (exit)))

(load (strcat *autolisp-formatter-path* "/../cl-loader.lsp"))

(foreach module '("fmt-util" "fmt-scanner" "fmt-parser" "fmt-options"
                  "fmt-io" "fmt-case" "fmt-rules" "fmt-printer" "fmt-main")
  (clload (cl-path-join *autolisp-formatter-path*
                        (strcat "src/" module ".lsp"))
          nil))

(princ)

;;; loader.lsp ends here
