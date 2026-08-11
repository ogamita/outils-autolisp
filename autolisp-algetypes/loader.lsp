;;; loader.lsp --- Charge le module autolisp-algetypes

(defun autolisp-algetypes-loader-root (/ loader-path)
  (cond
    ((and (boundp '*autolisp-algetypes-path*) *autolisp-algetypes-path*)
     *autolisp-algetypes-path*)
    ((setq loader-path (findfile "autolisp-algetypes/loader.lsp"))
     (vl-filename-directory loader-path))
    ((setq loader-path (findfile "loader.lsp"))
     (vl-filename-directory loader-path))
    (t nil)))

(setq *autolisp-algetypes-path* (autolisp-algetypes-loader-root))

(if (null *autolisp-algetypes-path*)
  (progn
    (prompt "\n[loader] Erreur : chemin de autolisp-algetypes introuvable.")
    (exit)))

(load (strcat *autolisp-algetypes-path* "/../cl-loader.lsp"))
(clload (cl-path-join *autolisp-algetypes-path*
                      "src/autolisp-algetypes.lsp") nil)

(princ)
