;;; autolisp-json.lsp --- JSON reader/writer for AutoLISP (bulk, one file / one sexp)

(vl-load-com)

;;; ------------------------------------------------------------------
;;; Représentation (sexp balisée, aller-retour sûr)
;;; ------------------------------------------------------------------
;;;
;;;   JSON object  -> (aj-object ("cle" . valeur) ...)
;;;   JSON array   -> (aj-array  valeur ...)
;;;   JSON string  -> chaine AutoLISP (STR)
;;;   JSON number  -> INT si entier, REAL sinon
;;;   JSON true    -> symbole aj-true
;;;   JSON false   -> symbole aj-false
;;;   JSON null    -> symbole aj-null
;;;
;;; Les trois singletons aj-true / aj-false / aj-null sont liés à
;;; eux-mêmes (voir plus bas), ce qui permet de les écrire sans quote.
;;;
;;; À l'encodage, par tolérance, T est accepté comme true et nil
;;; comme null ; l'encodage canonique reste néanmoins aj-true /
;;; aj-false / aj-null.
;;;
;;; API publique:
;;;   aj-decode              (chaine  -> sexp)
;;;   aj-encode              (sexp    -> chaine JSON compacte)
;;;   aj-encode-pretty       (sexp    -> chaine JSON indentée)
;;;   aj-read-file           (chemin  -> sexp)
;;;   aj-write-file          (chemin sexp -> chemin)   ; compact
;;;   aj-write-file-pretty   (chemin sexp -> chemin)   ; indenté
;;;
;;;   Constructeurs / accesseurs:
;;;     aj-make-object aj-make-array
;;;     aj-object-p aj-array-p aj-null-p aj-true-p aj-false-p
;;;     aj-object-alist aj-array-items aj-object-keys
;;;     aj-object-get aj-object-has-p aj-object-put
;;;     aj-boolean
;;;
;;;   Variables de configuration:
;;;     *aj-escape-non-ascii*  (nil)  ; T => échappe tout > 126 en \uXXXX
;;;     *aj-real-precision*    (12)   ; décimales conservées pour les REAL
;;;     *aj-indent*            (2)    ; espaces par niveau (mode indenté)

;;; ------------------------------------------------------------------
;;; Singletons et configuration
;;; ------------------------------------------------------------------

(setq aj-null  'aj-null)
(setq aj-true  'aj-true)
(setq aj-false 'aj-false)

(if (not (boundp '*aj-escape-non-ascii*)) (setq *aj-escape-non-ascii* nil))
(if (not (boundp '*aj-real-precision*))   (setq *aj-real-precision* 12))
(if (not (boundp '*aj-indent*))           (setq *aj-indent* 2))

;;; ------------------------------------------------------------------
;;; Prédicats, constructeurs et accesseurs
;;; ------------------------------------------------------------------

(defun aj-null-p  (v) (eq v 'aj-null))
(defun aj-true-p  (v) (eq v 'aj-true))
(defun aj-false-p (v) (eq v 'aj-false))

(defun aj-object-p (v)
  (and (= (type v) 'LIST) (eq (car v) 'aj-object)))

(defun aj-array-p (v)
  (and (= (type v) 'LIST) (eq (car v) 'aj-array)))

(defun aj-boolean (x)
  (if x 'aj-true 'aj-false))

(defun aj-make-object (alist)
  (cons 'aj-object alist))

(defun aj-make-array (items)
  (cons 'aj-array items))

(defun aj-object-alist (obj)
  (cdr obj))

(defun aj-array-items (arr)
  (cdr arr))

(defun aj-object-keys (obj / ks e)
  (setq ks nil)
  (foreach e (cdr obj)
    (setq ks (cons (car e) ks)))
  (reverse ks))

(defun aj-object-get (obj key / cell)
  (setq cell (assoc key (cdr obj)))
  (if cell (cdr cell) nil))

(defun aj-object-has-p (obj key)
  (if (assoc key (cdr obj)) T nil))

(defun aj-object-put (obj key val / alist cell)
  (setq alist (cdr obj))
  (setq cell (assoc key alist))
  (if cell
    (cons 'aj-object (subst (cons key val) cell alist))
    (cons 'aj-object (append alist (list (cons key val))))))

;;; ------------------------------------------------------------------
;;; Petits utilitaires de chaîne
;;; ------------------------------------------------------------------

(defun aj--join (lst sep / result first x)
  (setq result "" first T)
  (foreach x lst
    (if first
      (progn (setq result x) (setq first nil))
      (setq result (strcat result sep x))))
  result)

(defun aj--string-contains (s sub)
  (if (vl-string-search sub s) T nil))

(defun aj--spaces (n / s)
  (setq s "")
  (repeat n (setq s (strcat s " ")))
  s)

(defun aj--digit-p (c / a)
  (and (= (strlen c) 1)
       (setq a (ascii c))
       (>= a 48)
       (<= a 57)))

(defun aj--int->hex4 (n / digits s d)
  (setq digits "0123456789abcdef")
  (setq s "")
  (repeat 4
    (setq d (rem n 16))
    (setq s (strcat (substr digits (1+ d) 1) s))
    (setq n (/ n 16)))
  s)

(defun aj--hex-digit (ch / c)
  (setq c (ascii (strcase ch)))
  (cond
    ((and (>= c 48) (<= c 57)) (- c 48))          ; 0-9
    ((and (>= c 65) (<= c 70)) (+ 10 (- c 65)))   ; A-F
    (t (aj--error (strcat "invalid hex digit '" ch "'")))))

(defun aj--hex4->int (hex / n i)
  (setq n 0 i 1)
  (repeat 4
    (setq n (+ (* n 16) (aj--hex-digit (substr hex i 1))))
    (setq i (1+ i)))
  n)

;;; ------------------------------------------------------------------
;;; Décodage : JSON (chaîne) -> sexp
;;;
;;; L'état d'analyse (aj--src aj--pos aj--len) est déclaré local à
;;; aj-decode ; grâce à la portée dynamique d'AutoLISP, toutes les
;;; fonctions aj--parse-* y accèdent sans variable globale.
;;; ------------------------------------------------------------------

(defun aj--error (msg)
  (error (strcat "aj-json: " msg
                 " (à la position " (itoa aj--pos) ")")))

(defun aj--cur ()
  (if (<= aj--pos aj--len) (substr aj--src aj--pos 1) ""))

(defun aj--advance ()
  (setq aj--pos (1+ aj--pos)))

(defun aj--skip-ws (/ c)
  (while (and (<= aj--pos aj--len)
              (or (= (setq c (substr aj--src aj--pos 1)) " ")
                  (= c "\t")
                  (= c "\n")
                  (= c "\r")))
    (setq aj--pos (1+ aj--pos))))

(defun aj--parse-value (/ c)
  (aj--skip-ws)
  (if (> aj--pos aj--len)
    (aj--error "fin d'entrée inattendue"))
  (setq c (substr aj--src aj--pos 1))
  (cond
    ((= c "{")  (aj--parse-object))
    ((= c "[")  (aj--parse-array))
    ((= c "\"") (aj--parse-string))
    ((= c "t")  (aj--parse-lit "true"  'aj-true))
    ((= c "f")  (aj--parse-lit "false" 'aj-false))
    ((= c "n")  (aj--parse-lit "null"  'aj-null))
    ((or (= c "-") (aj--digit-p c)) (aj--parse-number))
    (t (aj--error (strcat "caractère inattendu '" c "'")))))

(defun aj--parse-lit (word val / got)
  (setq got (substr aj--src aj--pos (strlen word)))
  (if (= got word)
    (progn (setq aj--pos (+ aj--pos (strlen word))) val)
    (aj--error (strcat "littéral invalide, attendu " word))))

(defun aj--parse-number (/ start is-real c token)
  (setq start aj--pos)
  (setq is-real nil)
  (if (= (aj--cur) "-") (aj--advance))
  (while (aj--digit-p (aj--cur)) (aj--advance))
  (if (= (aj--cur) ".")
    (progn
      (setq is-real T)
      (aj--advance)
      (while (aj--digit-p (aj--cur)) (aj--advance))))
  (setq c (aj--cur))
  (if (or (= c "e") (= c "E"))
    (progn
      (setq is-real T)
      (aj--advance)
      (setq c (aj--cur))
      (if (or (= c "+") (= c "-")) (aj--advance))
      (while (aj--digit-p (aj--cur)) (aj--advance))))
  (setq token (substr aj--src start (- aj--pos start)))
  (if is-real (atof token) (atoi token)))

(defun aj--parse-string (/ result c)
  (setq result "")
  (aj--advance)                         ; guillemet ouvrant
  (while
    (progn
      (if (> aj--pos aj--len)
        (aj--error "chaîne non terminée"))
      (setq c (substr aj--src aj--pos 1))
      (/= c "\""))
    (if (= c "\\")
      (setq result (strcat result (aj--parse-escape)))
      (progn
        (setq result (strcat result c))
        (setq aj--pos (1+ aj--pos)))))
  (aj--advance)                         ; guillemet fermant
  result)

(defun aj--parse-escape (/ c)
  (aj--advance)                         ; l'antislash
  (if (> aj--pos aj--len)
    (aj--error "échappement non terminé"))
  (setq c (substr aj--src aj--pos 1))
  (aj--advance)
  (cond
    ((= c "\"") "\"")
    ((= c "\\") "\\")
    ((= c "/")  "/")
    ((= c "b")  (chr 8))
    ((= c "f")  (chr 12))
    ((= c "n")  (chr 10))
    ((= c "r")  (chr 13))
    ((= c "t")  (chr 9))
    ((= c "u")  (aj--parse-unicode))
    (t (aj--error (strcat "échappement inconnu '\\" c "'")))))

(defun aj--parse-unicode (/ code lo)
  (if (< (strlen (substr aj--src aj--pos 4)) 4)
    (aj--error "échappement \\u incomplet"))
  (setq code (aj--hex4->int (substr aj--src aj--pos 4)))
  (setq aj--pos (+ aj--pos 4))
  ;; paire de substitution (surrogate pair) pour le plan astral
  (if (and (>= code 55296) (<= code 56319))
    (if (and (= (substr aj--src aj--pos 1) "\\")
             (= (substr aj--src (1+ aj--pos) 1) "u"))
      (progn
        (setq aj--pos (+ aj--pos 2))
        (setq lo (aj--hex4->int (substr aj--src aj--pos 4)))
        (setq aj--pos (+ aj--pos 4))
        (setq code (+ 65536 (* 1024 (- code 55296)) (- lo 56320))))
      (aj--error "paire de substitution \\u invalide")))
  (chr code))

(defun aj--parse-object (/ pairs key c)
  (setq pairs nil)
  (aj--advance)                         ; {
  (aj--skip-ws)
  (if (= (aj--cur) "}")
    (progn (aj--advance) (cons 'aj-object nil))
    (progn
      (while
        (progn
          (aj--skip-ws)
          (if (/= (aj--cur) "\"")
            (aj--error "clé de chaîne attendue dans l'objet"))
          (setq key (aj--parse-string))
          (aj--skip-ws)
          (if (/= (aj--cur) ":")
            (aj--error "':' attendu dans l'objet"))
          (aj--advance)
          (setq pairs (cons (cons key (aj--parse-value)) pairs))
          (aj--skip-ws)
          (setq c (aj--cur))
          (cond
            ((= c ",") (aj--advance) T)
            ((= c "}") (aj--advance) nil)
            (t (aj--error "',' ou '}' attendu dans l'objet")))))
      (cons 'aj-object (reverse pairs)))))

(defun aj--parse-array (/ items c)
  (setq items nil)
  (aj--advance)                         ; [
  (aj--skip-ws)
  (if (= (aj--cur) "]")
    (progn (aj--advance) (cons 'aj-array nil))
    (progn
      (while
        (progn
          (setq items (cons (aj--parse-value) items))
          (aj--skip-ws)
          (setq c (aj--cur))
          (cond
            ((= c ",") (aj--advance) T)
            ((= c "]") (aj--advance) nil)
            (t (aj--error "',' ou ']' attendu dans le tableau")))))
      (cons 'aj-array (reverse items)))))

(defun aj-decode (string / aj--src aj--pos aj--len result)
  (setq aj--src string)
  (setq aj--len (strlen string))
  (setq aj--pos 1)
  (setq result (aj--parse-value))
  (aj--skip-ws)
  (if (<= aj--pos aj--len)
    (aj--error "caractères superflus après la valeur JSON"))
  result)

;;; ------------------------------------------------------------------
;;; Encodage : sexp -> JSON (chaîne)
;;; ------------------------------------------------------------------

(defun aj--null-value-p  (v) (or (eq v 'aj-null) (null v)))
(defun aj--true-value-p  (v) (or (eq v 'aj-true) (eq v T)))
(defun aj--false-value-p (v) (eq v 'aj-false))

(defun aj--encode-error (v)
  (error (strcat "aj-json: valeur non encodable : "
                 (vl-princ-to-string v))))

(defun aj--encode-string (s / out i n c code frag)
  (setq out "\"" n (strlen s) i 1)
  (while (<= i n)
    (setq c (substr s i 1))
    (setq code (ascii c))
    (setq frag
      (cond
        ((= c "\"") "\\\"")
        ((= c "\\") "\\\\")
        ((= code 8)  "\\b")
        ((= code 9)  "\\t")
        ((= code 10) "\\n")
        ((= code 12) "\\f")
        ((= code 13) "\\r")
        ((< code 32) (strcat "\\u" (aj--int->hex4 code)))
        ((and *aj-escape-non-ascii* (> code 126))
         (strcat "\\u" (aj--int->hex4 code)))
        (t c)))
    (setq out (strcat out frag))
    (setq i (1+ i)))
  (strcat out "\""))

(defun aj--trim-real (s)
  (if (aj--string-contains s ".")
    (progn
      (while (and (> (strlen s) 1)
                  (= (substr s (strlen s) 1) "0"))
        (setq s (substr s 1 (1- (strlen s)))))
      (if (= (substr s (strlen s) 1) ".")
        (setq s (strcat s "0")))
      s)
    (strcat s ".0")))

(defun aj--encode-real (r / s)
  (setq s (rtos r 2 *aj-real-precision*))
  ;; neutralise un éventuel séparateur décimal localisé
  (if (vl-string-search "," s)
    (setq s (vl-string-subst "." "," s)))
  (aj--trim-real s))

(defun aj--encode-scalar (v)
  (cond
    ((aj--null-value-p v)  "null")
    ((aj--true-value-p v)  "true")
    ((aj--false-value-p v) "false")
    ((= (type v) 'STR)  (aj--encode-string v))
    ((= (type v) 'INT)  (itoa v))
    ((= (type v) 'REAL) (aj--encode-real v))
    (t nil)))

;; --- compact -------------------------------------------------------

(defun aj--encode-compact (v / scalar parts e)
  (setq scalar (aj--encode-scalar v))
  (cond
    (scalar scalar)
    ((aj-object-p v)
     (setq parts nil)
     (foreach e (cdr v)
       (if (/= (type (car e)) 'STR)
         (error "aj-json: clé d'objet non chaîne"))
       (setq parts
         (cons (strcat (aj--encode-string (car e)) ":"
                       (aj--encode-compact (cdr e)))
               parts)))
     (strcat "{" (aj--join (reverse parts) ",") "}"))
    ((aj-array-p v)
     (setq parts nil)
     (foreach e (cdr v)
       (setq parts (cons (aj--encode-compact e) parts)))
     (strcat "[" (aj--join (reverse parts) ",") "]"))
    (t (aj--encode-error v))))

(defun aj-encode (value)
  (aj--encode-compact value))

;; --- indenté -------------------------------------------------------

(defun aj--pp-indent (depth)
  (aj--spaces (* depth *aj-indent*)))

(defun aj--encode-pp (v depth / scalar pad parts e)
  (setq scalar (aj--encode-scalar v))
  (cond
    (scalar scalar)
    ((aj-object-p v)
     (if (null (cdr v))
       "{}"
       (progn
         (setq pad (aj--pp-indent (1+ depth)))
         (setq parts nil)
         (foreach e (cdr v)
           (if (/= (type (car e)) 'STR)
             (error "aj-json: clé d'objet non chaîne"))
           (setq parts
             (cons (strcat pad (aj--encode-string (car e)) ": "
                           (aj--encode-pp (cdr e) (1+ depth)))
                   parts)))
         (strcat "{\n"
                 (aj--join (reverse parts) ",\n")
                 "\n" (aj--pp-indent depth) "}"))))
    ((aj-array-p v)
     (if (null (cdr v))
       "[]"
       (progn
         (setq pad (aj--pp-indent (1+ depth)))
         (setq parts nil)
         (foreach e (cdr v)
           (setq parts (cons (strcat pad (aj--encode-pp e (1+ depth))) parts)))
         (strcat "[\n"
                 (aj--join (reverse parts) ",\n")
                 "\n" (aj--pp-indent depth) "]"))))
    (t (aj--encode-error v))))

(defun aj-encode-pretty (value)
  (aj--encode-pp value 0))

;;; ------------------------------------------------------------------
;;; Entrées/sorties fichier (traitement en bloc : un fichier, une sexp)
;;; ------------------------------------------------------------------

(defun aj-read-file (path / f line content)
  (setq f (open path "r"))
  (if (null f)
    (error (strcat "aj-json: ouverture impossible en lecture : " path)))
  (setq content "")
  (while (setq line (read-line f))
    (setq content (strcat content line "\n")))
  (close f)
  (aj-decode content))

(defun aj-write-file (path value / f)
  (setq f (open path "w"))
  (if (null f)
    (error (strcat "aj-json: ouverture impossible en écriture : " path)))
  (write-line (aj-encode value) f)
  (close f)
  path)

(defun aj-write-file-pretty (path value / f)
  (setq f (open path "w"))
  (if (null f)
    (error (strcat "aj-json: ouverture impossible en écriture : " path)))
  (write-line (aj-encode-pretty value) f)
  (close f)
  path)

(princ)
