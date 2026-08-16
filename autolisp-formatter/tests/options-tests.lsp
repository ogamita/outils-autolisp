;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; options-tests.lsp --- Tests du module d'options (ligne de commande,
;;;; fichier de configuration, appel programmatique).

(defsuite "autolisp-formatter")
(in-suite "autolisp-formatter")

(defun ft-opt (items key)
  (fmt-option (fmt-build-options items) key))

(deftest
  "options: valeurs par defaut"
  (function
    (lambda ()
      (is-equal 'CL       (ft-opt nil "paren-style")   "style cl par defaut")
      (is-equal 'PRESERVE (ft-opt nil "symbol-case")   "casse preservee")
      (is-equal 'PRESERVE (ft-opt nil "comment-style") "commentaires preserves")
      (is-equal nil (ft-opt nil "inline-comment-column") "pas d'alignement")
      (is-equal nil (ft-opt nil "files") "aucun fichier"))))

(deftest
  "options: ligne de commande"
  (function
    (lambda ()
      (is-equal 'NAIL
                (ft-opt (list "--style" "nail") "paren-style")
                "--style nail")
      (is-equal 'DOWNCASE
                (ft-opt (list "--symbol-case" "downcase") "symbol-case")
                "--symbol-case downcase")
      (is-equal 40
                (ft-opt (list "--inline-comment-column" "40")
                        "inline-comment-column")
                "--inline-comment-column 40")
      (is-equal t (ft-opt (list "--check") "check") "--check est booleen")
      (is-equal t (ft-opt (list "--in-place") "in-place") "--in-place")
      (is-equal (list "a.lsp" "b.lsp")
                (ft-opt (list "--check" "a.lsp" "b.lsp") "files")
                "arguments positionnels dans l'ordre"))))

(deftest
  "options: noms francais du fichier de configuration"
  (function
    (lambda ()
      (is-equal 'CL
                (ft-opt (list ':style-parentheses ':cl) "paren-style")
                ":style-parentheses :cl")
      (is-equal 'DOWNCASE
                (ft-opt (list ':casse-symboles ':minuscules) "symbol-case")
                ":casse-symboles :minuscules")
      (is-equal 'UPCASE
                (ft-opt (list ':casse-symboles ':majuscules) "symbol-case")
                ":casse-symboles :majuscules")
      (is-equal 40
                (ft-opt (list ':colonne-commentaires-en-ligne 40)
                        "inline-comment-column")
                ":colonne-commentaires-en-ligne 40"))))

(deftest
  "options: valeurs booleennes explicites"
  (function
    (lambda ()
      (is-equal t   (ft-opt (list "--contextual-comments" "yes")
                            "contextual-comments")
                "yes")
      (is-equal nil (ft-opt (list "--contextual-comments" "no")
                            "contextual-comments")
                "no")
      (is-equal nil (ft-opt (list ':commentaires-contextuels ':non)
                            "contextual-comments")
                ":non"))))

(deftest
  "options: erreurs"
  (function
    (lambda ()
      (signals-error (function (lambda () (fmt-build-options (list "--inconnue"))))
                     "option inconnue")
      (signals-error (function (lambda ()
                                 (fmt-build-options (list "--style" "grec"))))
                     "valeur d'enumeration invalide")
      (signals-error (function (lambda () (fmt-build-options (list "--style"))))
                     "valeur manquante"))))

(deftest
  "options: fichier de configuration, forme s-expression englobante"
  (function
    (lambda ()
      (is-equal 'CL
                (ft-opt (list "--config" "tests/fixtures/config-liste.lsp")
                        "paren-style")
                "style lu dans la liste")
      (is-equal 'DOWNCASE
                (ft-opt (list "--config" "tests/fixtures/config-liste.lsp")
                        "symbol-case")
                "casse lue dans la liste")
      (is-equal 40
                (ft-opt (list "--config" "tests/fixtures/config-liste.lsp")
                        "inline-comment-column")
                "colonne lue dans la liste")
      (is-equal (list "entree.lsp")
                (ft-opt (list "--config" "tests/fixtures/config-liste.lsp") "files")
                "fichiers lus dans la liste"))))

(deftest
  "options: fichier de configuration, forme sans liste englobante"
  (function
    (lambda ()
      (is-equal 'NAIL
                (ft-opt (list "--config" "tests/fixtures/config-plat.lsp")
                        "paren-style")
                "style lu a plat")
      (is-equal 'UPCASE
                (ft-opt (list "--config" "tests/fixtures/config-plat.lsp")
                        "symbol-case")
                "casse lue a plat"))))

(deftest
  "options: l'appel courant est prioritaire sur le fichier de configuration"
  (function
    (lambda ()
      (is-equal 'NAIL
                (ft-opt (list "--config" "tests/fixtures/config-liste.lsp"
                              "--style" "nail")
                        "paren-style")
                "--style nail l'emporte sur :style-parentheses :cl")
      (is-equal 'DOWNCASE
                (ft-opt (list "--config" "tests/fixtures/config-liste.lsp"
                              "--style" "nail")
                        "symbol-case")
                "les autres options du fichier restent actives"))))

(deftest
  "options: formatage pilote par un fichier de configuration"
  (function
    (lambda ()
      (is-equal "(setq a 1)\n"
                (fmt-format-string
                  "(SETQ A 1)\n"
                  (fmt-build-options
                    (list "--config" "tests/fixtures/config-liste.lsp")))
                "la casse du fichier de configuration s'applique"))))

(princ)

;;; options-tests.lsp ends here
