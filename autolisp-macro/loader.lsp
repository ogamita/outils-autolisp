(defun autolisp-macro-loader-root (/ loader-path)
  (cond
    ((and (boundp '*autolisp-macro-path*)
          *autolisp-macro-path*)
     *autolisp-macro-path*)
    ((setq loader-path (findfile "autolisp-macro/loader.lsp"))
     (vl-filename-directory loader-path))
    ((setq loader-path (findfile "loader.lsp"))
     (vl-filename-directory loader-path))
    (t nil)))

(setq *autolisp-macro-path* (autolisp-macro-loader-root))

(if (null *autolisp-macro-path*)
  (progn
    (prompt
      "\n[loader] Error: cannot resolve autolisp-macro/loader.lsp. Set *autolisp-macro-path* or load this file with an absolute path, then retry.")
    (exit)))

(load (strcat *autolisp-macro-path* "/../cl-loader.lsp"))

(clload (cl-path-join *autolisp-macro-path* "mruntime.lsp") nil)

(clload-files *autolisp-macro-path*
              '("quasiquote-dotted.lsp"
                "macro-demo.lsp"
                "quasiquote-demo.lsp"
                "draw-grid.lsp")
              '((loader . mload)))

(clload-files (cl-path-join *autolisp-macro-path* "../autolisp-test")
              '("test-framework.lsp"
                "test-example.lsp")
              '((loader . mload)))
