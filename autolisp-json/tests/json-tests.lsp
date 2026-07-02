;;; json-tests.lsp --- Tests pour autolisp-json

(defsuite "autolisp-json")
(in-suite "autolisp-json")

;;; ------------------------------------------------------------------
;;; Décodage des scalaires
;;; ------------------------------------------------------------------

(deftest
  "decode des littéraux true/false/null"
  (function
    (lambda ()
      (is (aj-true-p  (aj-decode "true"))  "true")
      (is (aj-false-p (aj-decode "false")) "false")
      (is (aj-null-p  (aj-decode "null"))  "null"))))

(deftest
  "decode des nombres entiers et réels"
  (function
    (lambda ()
      (is-equal 42 (aj-decode "42") "entier positif")
      (is-equal -7 (aj-decode "-7") "entier négatif")
      (is-equal 0 (aj-decode "0") "zéro")
      (is (= (type (aj-decode "1.5")) 'REAL) "1.5 est un REAL")
      (is-approx 1.5 (aj-decode "1.5") 1e-9 "valeur 1.5")
      (is (= (type (aj-decode "10")) 'INT) "10 est un INT")
      (is-approx 1000.0 (aj-decode "1e3") 1e-9 "notation exposant")
      (is-approx -0.25 (aj-decode "-2.5e-1") 1e-9 "exposant signé"))))

(deftest
  "decode des chaînes et des échappements"
  (function
    (lambda ()
      (is-equal "abc" (aj-decode "\"abc\"") "chaîne simple")
      (is-equal "" (aj-decode "\"\"") "chaîne vide")
      (is-equal "a\"b" (aj-decode "\"a\\\"b\"") "guillemet échappé")
      (is-equal "a\\b" (aj-decode "\"a\\\\b\"") "antislash échappé")
      (is-equal (chr 10) (aj-decode "\"\\n\"") "saut de ligne")
      (is-equal (chr 9)  (aj-decode "\"\\t\"") "tabulation")
      (is-equal "é" (aj-decode "\"\\u00e9\"") "échappement unicode BMP"))))

;;; ------------------------------------------------------------------
;;; Décodage des structures
;;; ------------------------------------------------------------------

(deftest
  "decode d'un objet"
  (function
    (lambda (/ obj)
      (setq obj (aj-decode "{\"a\":1,\"b\":2}"))
      (is (aj-object-p obj) "est un objet")
      (is-equal 1 (aj-object-get obj "a") "clé a")
      (is-equal 2 (aj-object-get obj "b") "clé b")
      (is-equal '("a" "b") (aj-object-keys obj) "ordre des clés préservé"))))

(deftest
  "decode d'un tableau"
  (function
    (lambda (/ arr)
      (setq arr (aj-decode "[1,2,3]"))
      (is (aj-array-p arr) "est un tableau")
      (is-equal '(1 2 3) (aj-array-items arr) "éléments"))))

(deftest
  "decode d'objets et tableaux vides"
  (function
    (lambda ()
      (is-equal '(aj-object) (aj-decode "{}") "objet vide")
      (is-equal '(aj-array)  (aj-decode "[]") "tableau vide")
      (is (aj-object-p (aj-decode "{}")) "objet vide reconnu")
      (is (aj-array-p  (aj-decode "[]")) "tableau vide reconnu"))))

(deftest
  "decode d'une structure imbriquée"
  (function
    (lambda (/ v inner)
      (setq v (aj-decode "{\"a\":1,\"b\":[true,null,\"x\"]}"))
      (is-equal 1 (aj-object-get v "a") "scalaire")
      (setq inner (aj-object-get v "b"))
      (is (aj-array-p inner) "b est un tableau")
      (is (aj-true-p (car (aj-array-items inner))) "premier élément true")
      (is (aj-null-p (cadr (aj-array-items inner))) "deuxième élément null")
      (is-equal "x" (caddr (aj-array-items inner)) "troisième élément"))))

(deftest
  "decode tolère les commentaires JSONC (// et /* */)"
  (function
    (lambda (/ v)
      ;; commentaire de ligne en tête, entre paires, et en fin
      (setq v (aj-decode "// entête\n{\n  \"a\": 1, // après une valeur\n  \"b\": 2\n} // fin\n"))
      (is-equal 1 (aj-object-get v "a") "valeur avant commentaire de ligne")
      (is-equal 2 (aj-object-get v "b") "valeur après commentaire de ligne")
      ;; commentaire de bloc, y compris à une frontière de jeton
      (setq v (aj-decode "{ /* bloc */ \"a\": /* inline */ 3, \"b\": [ 1, /* x */ 2 ] }"))
      (is-equal 3 (aj-object-get v "a") "valeur autour d'un commentaire de bloc")
      (is-equal 2 (cadr (aj-array-items (aj-object-get v "b"))) "commentaire dans un tableau")
      ;; une séquence ressemblant à un commentaire DANS une chaîne reste littérale
      (is-equal "http://x//y" (aj-object-get (aj-decode "{\"u\": \"http://x//y\"}") "u")
                "les // dans une chaîne ne sont pas des commentaires"))))

(deftest
  "decode strict rejette les commentaires quand *aj-allow-comments* est nil"
  (function
    (lambda (/ *aj-allow-comments*)
      (setq *aj-allow-comments* nil)
      (is (vl-catch-all-error-p
            (vl-catch-all-apply 'aj-decode (list "{ // x\n\"a\":1}")))
          "commentaire rejeté en mode strict")
      ;; un '/' isolé reste une erreur, quel que soit le mode
      (is (vl-catch-all-error-p
            (vl-catch-all-apply 'aj-decode (list "{\"a\": / }")))
          "slash isolé rejeté")
      ;; commentaire de bloc non terminé
      (is (vl-catch-all-error-p
            (vl-catch-all-apply 'aj-decode (list "[1 /* sans fin")))
          "commentaire de bloc non terminé rejeté"))))

(deftest
  "decode tolère les espaces significatifs"
  (function
    (lambda (/ v)
      (setq v (aj-decode "  {\n  \"a\" : 1 ,\n  \"b\" : [ 2 , 3 ]\n}  "))
      (is-equal 1 (aj-object-get v "a") "clé a")
      (is-equal '(2 3) (aj-array-items (aj-object-get v "b")) "tableau b"))))

;;; ------------------------------------------------------------------
;;; Encodage
;;; ------------------------------------------------------------------

(deftest
  "encode des scalaires"
  (function
    (lambda ()
      (is-equal "true"  (aj-encode 'aj-true)  "aj-true")
      (is-equal "false" (aj-encode 'aj-false) "aj-false")
      (is-equal "null"  (aj-encode 'aj-null)  "aj-null")
      (is-equal "true"  (aj-encode T)   "T -> true (tolérance)")
      (is-equal "null"  (aj-encode nil) "nil -> null (tolérance)")
      (is-equal "42"    (aj-encode 42)  "entier")
      (is-equal "-7"    (aj-encode -7)  "entier négatif")
      (is-equal "\"abc\"" (aj-encode "abc") "chaîne"))))

(deftest
  "encode des réels"
  (function
    (lambda ()
      (is-equal "1.5" (aj-encode 1.5) "1.5")
      (is-equal "2.0" (aj-encode 2.0) "réel entier -> 2.0")
      (is-equal "-0.25" (aj-encode -0.25) "réel négatif"))))

(deftest
  "encode échappe les caractères spéciaux"
  (function
    (lambda ()
      (is-equal "\"a\\\"b\"" (aj-encode "a\"b") "guillemet")
      (is-equal "\"a\\\\b\"" (aj-encode "a\\b") "antislash")
      (is-equal "\"\\n\"" (aj-encode (chr 10)) "saut de ligne")
      (is-equal "\"\\t\"" (aj-encode (chr 9)) "tabulation"))))

(deftest
  "encode d'un objet et d'un tableau"
  (function
    (lambda ()
      (is-equal "{\"a\":1,\"b\":2}"
                (aj-encode '(aj-object ("a" . 1) ("b" . 2)))
                "objet")
      (is-equal "[1,2,3]"
                (aj-encode '(aj-array 1 2 3))
                "tableau")
      (is-equal "{}" (aj-encode '(aj-object)) "objet vide")
      (is-equal "[]" (aj-encode '(aj-array)) "tableau vide"))))

(deftest
  "escape-non-ascii force les échappements \\u"
  (function
    (lambda (/ *aj-escape-non-ascii*)
      (setq *aj-escape-non-ascii* T)
      (is-equal "\"\\u00e9\"" (aj-encode "é") "é échappé")
      (setq *aj-escape-non-ascii* nil)
      (is-equal "\"é\"" (aj-encode "é") "é brut"))))

;;; ------------------------------------------------------------------
;;; Aller-retour (round-trip)
;;; ------------------------------------------------------------------

(deftest
  "round-trip decode->encode->decode conserve la sexp"
  (function
    (lambda (/ src sexp)
      (setq src "{\"n\":3,\"x\":1.5,\"flags\":[true,false,null],\"s\":\"hé\"}")
      (setq sexp (aj-decode src))
      (is-equal sexp (aj-decode (aj-encode sexp)) "sexp identique après aller-retour"))))

(deftest
  "round-trip du mode indenté"
  (function
    (lambda (/ sexp)
      (setq sexp (aj-decode "{\"a\":[1,2,{\"b\":true}],\"c\":null}"))
      (is-equal sexp (aj-decode (aj-encode-pretty sexp))
                "l'indentation ne change pas la valeur"))))

(deftest
  "le mode indenté produit des sauts de ligne"
  (function
    (lambda (/ out)
      (setq out (aj-encode-pretty '(aj-object ("a" . 1))))
      (is (aj--string-contains out "\n") "contient un saut de ligne")
      (is (aj--string-contains out "  \"a\": 1") "clé indentée"))))

;;; ------------------------------------------------------------------
;;; Constructeurs et accesseurs
;;; ------------------------------------------------------------------

(deftest
  "constructeurs et accesseurs d'objet"
  (function
    (lambda (/ o o2)
      (setq o (aj-make-object (list (cons "a" 1))))
      (is (aj-object-p o) "make-object")
      (is (aj-object-has-p o "a") "has a")
      (is-not (aj-object-has-p o "z") "pas de z")
      (setq o2 (aj-object-put o "b" 2))
      (is-equal 2 (aj-object-get o2 "b") "put ajoute b")
      (is-not (aj-object-has-p o "b") "l'original est inchangé")
      (setq o2 (aj-object-put o2 "a" 9))
      (is-equal 9 (aj-object-get o2 "a") "put remplace a"))))

(deftest
  "aj-boolean convertit un booléen AutoLISP"
  (function
    (lambda ()
      (is (aj-true-p (aj-boolean T)) "vrai -> aj-true")
      (is (aj-false-p (aj-boolean nil)) "faux -> aj-false"))))

;;; ------------------------------------------------------------------
;;; Erreurs
;;; ------------------------------------------------------------------

(deftest
  "decode signale les entrées malformées"
  (function
    (lambda ()
      (signals-error (function (lambda () (aj-decode "")))         "entrée vide")
      (signals-error (function (lambda () (aj-decode "{")))        "objet non fermé")
      (signals-error (function (lambda () (aj-decode "[1,2")))     "tableau non fermé")
      (signals-error (function (lambda () (aj-decode "{\"a\" 1}"))) "':' manquant")
      (signals-error (function (lambda () (aj-decode "nul")))      "littéral invalide")
      (signals-error (function (lambda () (aj-decode "1 2")))      "caractères superflus")
      (signals-error (function (lambda () (aj-decode "\"abc")))    "chaîne non terminée"))))

;;; ------------------------------------------------------------------
;;; Entrées/sorties fichier
;;; ------------------------------------------------------------------

(deftest
  "aj-write-file puis aj-read-file conservent la valeur"
  (function
    (lambda (/ path sexp)
      (setq path (vl-filename-mktemp "aj-test" nil ".json"))
      (setq sexp (aj-decode "{\"a\":1,\"list\":[true,null,\"x\"]}"))
      (aj-write-file path sexp)
      (is-equal sexp (aj-read-file path) "aller-retour fichier (compact)")
      (aj-write-file-pretty path sexp)
      (is-equal sexp (aj-read-file path) "aller-retour fichier (indenté)")
      (vl-file-delete path))))
