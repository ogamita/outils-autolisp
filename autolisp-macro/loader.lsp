
(setq loader-path (findfile "loader.lsp"))

(if (null loader-path)
  (progn
    (prompt
      "\n[loader] Error: cannot resolve loader.lsp via findfile. Add 'outils/autolisp-macro' to SRCHPATH (or load this file with an absolute path), then retry.")
    (exit))
  (setq dir (strcat (vl-filename-directory loader-path) "/../autolisp-test/")))

(load (strcat dir "mruntime.lsp"))

(foreach file '("quasiquote-dotted.lsp"
                "test-framework.lsp")
  (mload (strcat dir file)))

(foreach file '("draw-grid.lsp"
                "macro-demo.lsp"
                "quasiquote-demo.lsp"
                "test-example.lsp")
  (mload (strcat dir file)))
