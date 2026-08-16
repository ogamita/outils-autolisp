;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; corpus-tests.lsp --- Non-régression sur du code AutoLISP réel.
;;;;
;;;; Plutôt que des sorties de référence à maintenir à la main, on vérifie
;;;; sur de vrais fichiers du dépôt trois propriétés qui suffisent à garantir
;;;; qu'aucun code n'est corrompu :
;;;;
;;;;   1. fidélité   : la suite des tokens de code (parenthèses, atomes,
;;;;                   chaînes, quotes) est identique avant et après ;
;;;;   2. idempotence : formater deux fois donne le même texte ;
;;;;   3. validation : aucune fermeture empilée en sortie.
;;;;
;;;; Les fichiers absents sont ignorés : la suite reste exécutable dans un
;;;; dépôt partiel.

(defsuite "autolisp-formatter")
(in-suite "autolisp-formatter")

(defun ft-corpus-files ()
  ;; Corpus local : du vrai code AutoLISP écrit à la main, sans « .. » dans
  ;; les chemins (le dialecte strict signale « .. » comme non portable
  ;; entre POSIX et Windows). Pour passer le formateur sur un corpus
  ;; d'équipe plus large, utiliser scripts/autolisp-format --check.
  (list "src/fmt-util.lsp"
        "src/fmt-scanner.lsp"
        "src/fmt-parser.lsp"
        "src/fmt-options.lsp"
        "src/fmt-printer.lsp"
        "src/fmt-main.lsp"
        "tests/printer-tests.lsp"
        "tests/options-tests.lsp"))

;; Tokens de code seuls : les commentaires sont comparés à part, leur texte
;; pouvant perdre des blancs de fin.
(defun ft-code-tokens (text / out)
  (setq out nil)
  (foreach tk (fmt-scan text)
    (if (not (fmt-tok-comment-p tk))
      (setq out (cons (list (fmt-tok-type tk) (fmt-tok-text tk)) out))))
  (reverse out))

(defun ft-comment-count (text / n)
  (setq n 0)
  (foreach tk (fmt-scan text)
    (if (fmt-tok-comment-p tk)
      (setq n (1+ n))))
  n)

(defun ft-check-corpus-file (path style / text out out2)
  (setq text (fmt-read-file path))
  (setq out  (fmt-format text (list "--style" style)))
  (setq out2 (fmt-format out (list "--style" style)))
  (is-equal (ft-code-tokens text) (ft-code-tokens out)
            (strcat path " [" style "] : suite des tokens de code preservee"))
  (is-equal (ft-comment-count text) (ft-comment-count out)
            (strcat path " [" style "] : nombre de commentaires preserve"))
  (is-equal out out2
            (strcat path " [" style "] : idempotent"))
  (if (/= style "stacked-nail")
    (is-equal nil (fmt-stacked-closer-lines (fmt-scan out))
              (strcat path " [" style "] : aucune fermeture empilee"))))

(deftest
  "corpus: fidelite, idempotence et validation en style cl"
  (function
    (lambda ()
      (foreach path (ft-corpus-files)
        (if (findfile path)
          (ft-check-corpus-file path "cl"))))))

(deftest
  "corpus: fidelite, idempotence et validation en style nail"
  (function
    (lambda ()
      (foreach path (ft-corpus-files)
        (if (findfile path)
          (ft-check-corpus-file path "nail"))))))

(deftest
  "corpus: au moins un fichier reellement examine"
  (function
    (lambda ()
      (setq *ft-found* nil)
      (foreach path (ft-corpus-files)
        (if (findfile path) (setq *ft-found* t)))
      (is *ft-found* "le corpus n'est pas vide"))))

(deftest
  "corpus: la casse ne change que les symboles"
  (function
    (lambda ()
      (foreach path (ft-corpus-files)
        (if (findfile path)
          (progn
            (setq *ft-text* (fmt-read-file path))
            (setq *ft-out*  (fmt-format *ft-text*
                                        (list "--symbol-case" "downcase")))
            (is-equal (ft-comment-count *ft-text*) (ft-comment-count *ft-out*)
                      (strcat path " : commentaires intacts en downcase"))
            (is-equal (length (ft-code-tokens *ft-text*))
                      (length (ft-code-tokens *ft-out*))
                      (strcat path " : nombre de tokens inchange en downcase"))))))))

(princ)

;;; corpus-tests.lsp ends here
