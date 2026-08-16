;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; parser-tests.lsp --- Tests unitaires du parseur / CST.

(defsuite "autolisp-formatter")
(in-suite "autolisp-formatter")

(defun ft-parse (text)
  (fmt-parse (fmt-scan text)))

(defun ft-kinds (text)
  (mapcar (function fmt-node-kind) (ft-parse text)))

(deftest
  "parseur: liste simple"
  (function
    (lambda ()
      (is-equal (list 'LIST) (ft-kinds "(foo bar)") "un seul noeud")
      (is-equal 2 (length (fmt-node-children (car (ft-parse "(foo bar)"))))
                "deux enfants")
      (is-equal "foo"
                (fmt-node-text (car (fmt-node-children (car (ft-parse "(foo bar)")))))
                "texte de l'en-tete"))))

(deftest
  "parseur: listes imbriquees"
  (function
    (lambda ()
      (is-equal 'LIST
                (fmt-node-kind
                  (cadr (fmt-node-children (car (ft-parse "(foo (bar baz))")))))
                "l'enfant imbrique est une liste")
      (is-equal (list 'LIST) (ft-kinds "(a (b (c)))") "imbrication profonde"))))

(deftest
  "parseur: liste vide"
  (function
    (lambda ()
      (is-equal (list 'LIST) (ft-kinds "()") "liste vide reconnue")
      (is-equal nil (fmt-node-children (car (ft-parse "()"))) "sans enfant"))))

(deftest
  "parseur: formes top-level successives"
  (function
    (lambda ()
      (is-equal (list 'LIST 'LIST) (ft-kinds "(a)\n(b)") "deux formes")
      (is-equal (list 'LIST 'BLANK 'LIST)
                (ft-kinds "(a)\n\n(b)")
                "ligne blanche entre les formes"))))

(deftest
  "parseur: quote simple et quote de liste"
  (function
    (lambda ()
      (is-equal (list 'QUOTE) (ft-kinds "'a") "quote d'atome")
      (is-equal 'ATOM
                (fmt-node-kind (fmt-node-child (car (ft-parse "'a"))))
                "enfant du quote")
      (is-equal 'LIST
                (fmt-node-kind (fmt-node-child (car (ft-parse "'(a b)"))))
                "quote d'une liste"))))

(deftest
  "parseur: commentaires entre les formes"
  (function
    (lambda ()
      (is-equal (list 'LCOMMENT 'LIST)
                (ft-kinds "; entete\n(a)")
                "commentaire avant la forme")
      (is-equal (list 'LIST 'LCOMMENT)
                (ft-kinds "(a) ; apres")
                "commentaire de fin de ligne")
      (is-equal (list 'ATOM 'LCOMMENT 'ATOM)
                (mapcar (function fmt-node-kind)
                        (fmt-node-children (car (ft-parse "(a ; ici\n b)"))))
                "commentaire interne a une forme"))))

(deftest
  "parseur: dernieres lignes de contenu"
  (function
    (lambda ()
      (is-equal 1 (fmt-content-end (car (ft-parse "(a b)")))
                "forme sur une ligne")
      ;; la ligne de la parenthese fermante ne compte pas comme contenu :
      ;; c'est ce qui permet de reconnaitre le style nail
      (is-equal 1 (fmt-content-end (car (ft-parse "(a b\n)")))
                "fermante isolee ignoree")
      (is-equal 2 (fmt-content-end (car (ft-parse "(a\n b)")))
                "contenu sur deux lignes"))))

(deftest
  "parseur: erreurs de structure"
  (function
    (lambda ()
      (signals-error (function (lambda () (ft-parse "(a")))
                     "parenthese ouvrante non fermee")
      (signals-error (function (lambda () (ft-parse "(a))")))
                     "parenthese fermante en trop")
      (signals-error (function (lambda () (ft-parse "(a '")))
                     "quote orpheline"))))

(deftest
  "parseur: detection des fermetures empilees"
  (function
    (lambda ()
      (is-equal (list 3)
                (fmt-stacked-closer-lines
                  (fmt-scan "(a\n (b\n) )"))
                "ligne ') )' signalee")
      (is-equal nil
                (fmt-stacked-closer-lines (fmt-scan "(a\n (b)\n )"))
                "une seule fermante par ligne : rien a signaler")
      (is-equal nil
                (fmt-stacked-closer-lines (fmt-scan "(a\n (b))"))
                "fermantes accolees : style cl, rien a signaler"))))

(princ)

;;; parser-tests.lsp ends here
