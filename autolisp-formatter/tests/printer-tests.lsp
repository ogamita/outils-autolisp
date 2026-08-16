;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; printer-tests.lsp --- Golden tests de l'imprimeur, idempotence, casse,
;;;; commentaires et styles de parenthèses.

(defsuite "autolisp-formatter")
(in-suite "autolisp-formatter")

(defun ft-fmt (text items)
  (fmt-format text items))

;; Le source d'exemple de la specification, en style nail-clipping.
(defun ft-source-nail ()
  (strcat "(defun foo (x)\n"
          "  (if (> x 0)\n"
          "    (progn\n"
          "      (bar x)\n"
          "      (baz x)\n"
          "    )\n"
          "  )\n"
          ")\n"))

;; Le meme, en fermetures empilees.
(defun ft-source-stacked ()
  (strcat "(defun foo (x)\n"
          "  (if (> x 0)\n"
          "    (progn\n"
          "      (bar x)\n"
          "      (baz x)\n"
          ") ) )\n"))

(defun ft-golden-cl ()
  (strcat "(defun foo (x)\n"
          "  (if (> x 0)\n"
          "      (progn\n"
          "        (bar x)\n"
          "        (baz x))))\n"))

;;; ------------------------------------------------------------------
;;; Styles de parentheses
;;; ------------------------------------------------------------------

(deftest
  "style cl: rendu conforme a la specification"
  (function
    (lambda ()
      (is-equal (ft-golden-cl)
                (ft-fmt (ft-source-nail) (list "--style" "cl"))
                "nail -> cl"))))

(deftest
  "style nail: rendu conforme a la specification"
  (function
    (lambda ()
      (is-equal (ft-source-nail)
                (ft-fmt (ft-golden-cl) (list "--style" "nail"))
                "cl -> nail"))))

(deftest
  "conversion nail -> cl -> nail stable"
  (function
    (lambda ()
      (is-equal (ft-source-nail)
                (ft-fmt (ft-fmt (ft-source-nail) (list "--style" "cl"))
                        (list "--style" "nail"))
                "aller-retour entre styles"))))

(deftest
  "fermetures empilees normalisees par defaut"
  (function
    (lambda ()
      (is-equal (ft-golden-cl)
                (ft-fmt (ft-source-stacked) (list "--style" "cl"))
                "empilees -> cl")
      (is-equal (ft-source-nail)
                (ft-fmt (ft-source-stacked) (list "--style" "nail"))
                "empilees -> nail"))))

(deftest
  "regle de validation: aucune fermeture empilee en sortie"
  (function
    (lambda ()
      (is-equal nil
                (fmt-stacked-closer-lines
                  (fmt-scan (ft-fmt (ft-source-stacked) (list "--style" "cl"))))
                "sortie cl sans ') )'")
      (is-equal nil
                (fmt-stacked-closer-lines
                  (fmt-scan (ft-fmt (ft-source-stacked) (list "--style" "nail"))))
                "sortie nail sans ') )'"))))

(deftest
  "style stacked-nail: emis seulement s'il est demande"
  (function
    (lambda ()
      (is (fmt-stacked-closer-lines
            (fmt-scan (ft-fmt (ft-source-nail) (list "--style" "stacked-nail"))))
          "le mode de compatibilite empile bien les fermantes"))))

;;; ------------------------------------------------------------------
;;; Regles d'indentation par forme
;;; ------------------------------------------------------------------

(deftest
  "indentation: if aligne sous le premier argument"
  (function
    (lambda ()
      (is-equal "(if (> x 0)\n    \"pos\"\n    \"neg\")\n"
                (ft-fmt "(if (> x 0)\n\"pos\"\n\"neg\")\n" nil)
                "alignement fonctionnel de if"))))

(deftest
  "indentation: setq aligne les paires"
  (function
    (lambda ()
      (is-equal "(setq a 1\n      b 2)\n"
                (ft-fmt "(setq a 1\nb 2)\n" nil)
                "alignement fonctionnel de setq"))))

(deftest
  "indentation: cond, while, foreach, progn"
  (function
    (lambda ()
      (is-equal "(cond\n  ((= a 1) \"un\")\n  (t \"autre\"))\n"
                (ft-fmt "(cond\n((= a 1) \"un\")\n(t \"autre\"))\n" nil)
                "clauses de cond a +2")
      (is-equal "(while (< i 10)\n  (setq i (1+ i)))\n"
                (ft-fmt "(while (< i 10)\n(setq i (1+ i)))\n" nil)
                "corps de while a +2")
      (is-equal "(foreach x lst\n  (print x))\n"
                (ft-fmt "(foreach x lst\n(print x))\n" nil)
                "corps de foreach a +2")
      (is-equal "(progn\n  (a)\n  (b))\n"
                (ft-fmt "(progn\n(a)\n(b))\n" nil)
                "corps de progn a +2"))))

(deftest
  "indentation: liste d'arguments avec / pour les variables locales"
  (function
    (lambda ()
      (is-equal "(defun f (a b / tmp)\n  (setq tmp a)\n  tmp)\n"
                (ft-fmt "(defun f (a b / tmp)\n(setq tmp a)\ntmp)\n" nil)
                "le / reste dans la liste d'arguments"))))

(deftest
  "indentation: forme deja sur une ligne y reste"
  (function
    (lambda ()
      (is-equal "(setq a (+ 1 2))\n"
                (ft-fmt "(setq   a   (+ 1 2))\n" nil)
                "espaces internes normalises, pas de coupure"))))

;;; ------------------------------------------------------------------
;;; Casse des symboles
;;; ------------------------------------------------------------------

(deftest
  "casse: preserve, downcase, upcase"
  (function
    (lambda ()
      (is-equal "(SetQ Foo 1)\n"
                (ft-fmt "(SetQ Foo 1)\n" (list "--symbol-case" "preserve"))
                "preserve")
      (is-equal "(setq foo 1)\n"
                (ft-fmt "(SetQ Foo 1)\n" (list "--symbol-case" "downcase"))
                "downcase")
      (is-equal "(SETQ FOO 1)\n"
                (ft-fmt "(SetQ Foo 1)\n" (list "--symbol-case" "upcase"))
                "upcase"))))

(deftest
  "casse: chaines, commentaires et nombres intacts"
  (function
    (lambda ()
      (is-equal "(setq s \"Texte Mixte\") ; Commentaire Mixte\n"
                (ft-fmt "(SETQ S \"Texte Mixte\") ; Commentaire Mixte\n"
                        (list "--symbol-case" "downcase"))
                "seuls les symboles changent")
      (is-equal "(SETQ X 1e3)\n"
                (ft-fmt "(setq x 1e3)\n" (list "--symbol-case" "upcase"))
                "le litteral 1e3 n'est pas un symbole : casse inchangee")
      (is-equal "(setq x 1e3)\n"
                (ft-fmt "(SETQ X 1e3)\n" (list "--symbol-case" "downcase"))
                "le litteral numerique reste tel quel"))))

(deftest
  "casse: fichier d'exceptions prioritaire sur la politique generale"
  (function
    (lambda ()
      (is-equal "(setq p PATH)\n"
                (ft-fmt "(SETQ P path)\n"
                        (list "--symbol-case" "downcase"
                              "--case-exceptions" "tests/fixtures/capitalisation.txt"))
                "PATH restitue exactement")
      (is-equal "(SETQ P CreateFileW)\n"
                (ft-fmt "(setq p CREATEFILEW)\n"
                        (list "--symbol-case" "upcase"
                              "--case-exceptions" "tests/fixtures/capitalisation.txt"))
                "CreateFileW restitue exactement"))))

(deftest
  "casse: exceptions jamais rencontrees signalables"
  (function
    (lambda ()
      (fmt-format "(setq p path)\n"
                  (list "--symbol-case" "downcase"
                        "--case-exceptions" "tests/fixtures/capitalisation.txt"))
      (is (member "CreateFileW"
                  (fmt-unused-case-exceptions
                    (fmt-load-case-exceptions "tests/fixtures/capitalisation.txt")))
          "CreateFileW absent du source est signale")
      (is (not (member "PATH"
                       (fmt-unused-case-exceptions
                         (fmt-load-case-exceptions "tests/fixtures/capitalisation.txt"))))
          "PATH rencontre n'est pas signale"))))

;;; ------------------------------------------------------------------
;;; Commentaires
;;; ------------------------------------------------------------------

(deftest
  "commentaires: mode preserve"
  (function
    (lambda ()
      (is-equal ";; entete\n(defun f ()\n  ;;; interne\n  (g)) ;;;; fin\n"
                (ft-fmt ";; entete\n(defun f ()\n;;; interne\n(g)) ;;;; fin\n" nil)
                "prefixes inchanges, seule l'indentation bouge"))))

(deftest
  "commentaires: normalisation cl contextuelle"
  (function
    (lambda ()
      (is-equal ";;;; entete\n(defun f ()\n  ;; interne\n  (g)) ; fin\n"
                (ft-fmt "; entete\n(defun f ()\n; interne\n(g)) ; fin\n"
                        (list "--comment-style" "cl"
                              "--contextual-comments" "yes"))
                "banniere, interne et fin de ligne")
      (is-equal ";; entete\n(defun f ()\n  ;; interne\n  (g)) ; fin\n"
                (ft-fmt "; entete\n(defun f ()\n; interne\n(g)) ; fin\n"
                        (list "--comment-style" "cl"))
                "sans option contextuelle : ;; partout sauf fin de ligne"))))

(deftest
  "commentaires: alignement en fin de ligne"
  (function
    (lambda ()
      (is-equal "(setq a 1)          ; note\n"
                (ft-fmt "(setq a 1) ; note\n"
                        (list "--inline-comment-column" "20"))
                "aligne a la colonne 20")
      (is-equal "(setq abcdefghijklmnopqrstuvwxyz 1) ; note\n"
                (ft-fmt "(setq abcdefghijklmnopqrstuvwxyz 1) ; note\n"
                        (list "--inline-comment-column" "20"))
                "au moins un espace si la colonne est depassee"))))

(deftest
  "commentaires bloc: preserves par defaut"
  (function
    (lambda ()
      (is-equal ";| bloc\n   suite |;\n(a)\n"
                (ft-fmt ";| bloc\n   suite |;\n(a)\n" nil)
                "texte interne intact"))))

(deftest
  "commentaires bloc: conversion en points-virgules"
  (function
    (lambda ()
      (is-equal ";; bloc\n;; suite\n(a)\n"
                (ft-fmt ";| bloc\n   suite |;\n(a)\n"
                        (list "--block-comments" "to-semicolons"))
                "une ligne de commentaire par ligne du bloc"))))

;;; ------------------------------------------------------------------
;;; Lignes blanches
;;; ------------------------------------------------------------------

(deftest
  "lignes blanches: multiples reduites a une, bords supprimes"
  (function
    (lambda ()
      (is-equal "(a)\n\n(b)\n"
                (ft-fmt "\n\n(a)\n\n\n\n(b)\n\n\n" nil)
                "normalisation des lignes blanches"))))

;;; ------------------------------------------------------------------
;;; Idempotence et determinisme
;;; ------------------------------------------------------------------

(defun ft-sample ()
  (strcat ";; entete\n"
          "\n"
          "(defun traiter (lst / n)      ; compte\n"
          "  (setq n 0)\n"
          "  (foreach x lst\n"
          "    (if (> x 0)\n"
          "        (setq n (1+ n))))\n"
          "  ;; resultat\n"
          "  n)\n"))

(deftest
  "idempotence: format(format(x)) = format(x)"
  (function
    (lambda ()
      (foreach style (list "cl" "nail" "stacked-nail")
        (is-equal (ft-fmt (ft-sample) (list "--style" style))
                  (ft-fmt (ft-fmt (ft-sample) (list "--style" style))
                          (list "--style" style))
                  (strcat "idempotent en style " style))))))

(deftest
  "determinisme: deux passes identiques"
  (function
    (lambda ()
      (is-equal (ft-fmt (ft-sample) (list "--style" "cl"))
                (ft-fmt (ft-sample) (list "--style" "cl"))
                "meme entree, memes options, meme sortie"))))

(deftest
  "check: reconnait un fichier deja conforme"
  (function
    (lambda ()
      (is (fmt-check-string (ft-fmt (ft-sample) nil) (fmt-build-options nil))
          "la sortie du formateur est conforme")
      (is (not (fmt-check-string (ft-source-nail) (fmt-build-options nil)))
          "un source nail n'est pas conforme au style cl"))))

(princ)

;;; printer-tests.lsp ends here
