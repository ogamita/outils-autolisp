;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; scanner-tests.lsp --- Tests unitaires de l'analyseur lexical.

(defsuite "autolisp-formatter")
(in-suite "autolisp-formatter")

(defun ft-types (text)
  (mapcar (function fmt-tok-type) (fmt-scan text)))

(defun ft-texts (text)
  (mapcar (function fmt-tok-text) (fmt-scan text)))

(deftest
  "scanner: parentheses et atomes simples"
  (function
    (lambda ()
      (is-equal (list 'LPAREN 'ATOM 'ATOM 'RPAREN)
                (ft-types "(foo bar)")
                "types de (foo bar)")
      (is-equal (list "(" "foo" "bar" ")")
                (ft-texts "(foo bar)")
                "textes de (foo bar)"))))

(deftest
  "scanner: positions ligne et colonne"
  (function
    (lambda ()
      (is-equal 1 (fmt-tok-line (car (fmt-scan "(foo\n  bar)")))
                "ligne du premier token")
      (is-equal 2 (fmt-tok-line (nth 2 (fmt-scan "(foo\n  bar)")))
                "ligne de bar")
      (is-equal 3 (fmt-tok-col (nth 2 (fmt-scan "(foo\n  bar)")))
                "colonne de bar"))))

(deftest
  "scanner: commentaire de ligne"
  (function
    (lambda ()
      (is-equal (list 'ATOM 'LCOMMENT)
                (ft-types "foo ; commentaire")
                "atome puis commentaire")
      (is-equal "; commentaire"
                (fmt-tok-text (cadr (fmt-scan "foo ; commentaire")))
                "texte du commentaire")
      (is (fmt-tok-inline (cadr (fmt-scan "foo ; commentaire")))
          "commentaire de fin de ligne")
      (is (not (fmt-tok-inline (car (fmt-scan "; seul"))))
          "commentaire sur ligne dediee"))))

(deftest
  "scanner: commentaire bloc multi-lignes"
  (function
    (lambda ()
      (is-equal (list 'BCOMMENT)
                (ft-types ";| bloc\n   suite |;")
                "un seul token bloc")
      (is-equal ";| bloc\n   suite |;"
                (car (ft-texts ";| bloc\n   suite |;"))
                "texte complet du bloc")
      (is-equal 2
                (fmt-tok-endline (car (fmt-scan ";| bloc\n   suite |;")))
                "ligne de fin du bloc"))))

(deftest
  "scanner: parentheses dans commentaire bloc sans effet structurel"
  (function
    (lambda ()
      (is-equal (list 'LPAREN 'ATOM 'BCOMMENT 'RPAREN)
                (ft-types "(foo ;| ) ) ) |; )")
                "les fermantes du bloc sont inertes"))))

(deftest
  "scanner: chaines contenant parentheses et points-virgules"
  (function
    (lambda ()
      (is-equal (list 'LPAREN 'ATOM 'STR 'RPAREN)
                (ft-types "(foo \"a ) ; b\")")
                "la chaine est un seul token")
      (is-equal "\"a ) ; b\""
                (nth 2 (ft-texts "(foo \"a ) ; b\")"))
                "texte de la chaine, guillemets inclus"))))

(deftest
  "scanner: echappements dans les chaines"
  (function
    (lambda ()
      (is-equal (list 'STR)
                (ft-types "\"a \\\" b\"")
                "le guillemet echappe ne termine pas la chaine")
      (is-equal "\"a \\\" b\""
                (car (ft-texts "\"a \\\" b\""))
                "texte preserve tel quel"))))

(deftest
  "scanner: symboles a caracteres speciaux"
  (function
    (lambda ()
      (is-equal (list "pk!" "vl-catch-all-apply" "*debug*" ":foo" "/")
                (ft-texts "pk! vl-catch-all-apply *debug* :foo /")
                "symboles AutoLISP legitimes"))))

(deftest
  "scanner: paire pointee"
  (function
    (lambda ()
      (is-equal (list 'LPAREN 'ATOM 'ATOM 'ATOM 'RPAREN)
                (ft-types "(a . b)")
                "le point est un atome ordinaire")
      (is-equal "."
                (nth 2 (ft-texts "(a . b)"))
                "texte du point"))))

(deftest
  "scanner: quote"
  (function
    (lambda ()
      (is-equal (list 'QUOTE 'LPAREN 'ATOM 'RPAREN)
                (ft-types "'(a)")
                "quote puis liste"))))

(deftest
  "scanner: erreurs lexicales"
  (function
    (lambda ()
      (signals-error (function (lambda () (fmt-scan "\"pas de fin")))
                     "chaine non terminee")
      (signals-error (function (lambda () (fmt-scan ";| pas de fin")))
                     "commentaire bloc non termine"))))

(princ)

;;; scanner-tests.lsp ends here
