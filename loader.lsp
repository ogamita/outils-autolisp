;;; loader.lsp --- Load outils-autolisp modules from an explicit root directory

(defun outils-load-library (outils-root /)
  (clload-files
    outils-root
    '("autolisp-vector/src/autolisp-vector.lsp"
      "autolisp-hash-table/src/autolisp-hash-table.lsp"
      "autolisp-doc/src/autolisp-ref.lsp"
      "autolisp-doc/src/autolisp-doc.lsp")
    nil)
  (princ))

(if (not (boundp '*outils-autolisp-path*))
  (setq *outils-autolisp-path* "."))

(load (strcat *outils-autolisp-path* "/cl-loader.lsp"))

(outils-load-library *outils-autolisp-path*)

;; (progn
;;   (setq *outils-autolisp-path* "/Users/pjb/works/sncf-reseau/src/outils-autolisp")
;;   (setq *verbose* T)
;;   (load (strcat *outils-autolisp-path* "/loader.lsp")))

