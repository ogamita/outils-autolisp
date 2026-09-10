;;; aloop-tests.lsp --- Tests unitaires de autolisp-misc/src/aloop.lsp

;;; =aloop.lsp= doit être chargé par le harness avant ce script.

(setq *aloop-test-fails* 0)
(setq *aloop-test-log* nil)

(defun aloop-check (label expected actual)
  (if (equal expected actual)
    (progn (princ "PASS ") (princ label) (terpri))
    (progn
      (princ "FAIL ") (princ label) (terpri)
      (princ "  expected: ") (princ (vl-prin1-to-string expected)) (terpri)
      (princ "  actual:   ") (princ (vl-prin1-to-string actual)) (terpri)
      (setq *aloop-test-fails* (1+ *aloop-test-fails*)))))

(defun aloop-test-record0 ()
  (setq *aloop-test-log* (cons 'called *aloop-test-log*))
  nil)

(defun aloop-test-record1 (a)
  (setq *aloop-test-log* (cons a *aloop-test-log*))
  nil)

(defun aloop-test-record2 (a b)
  (setq *aloop-test-log* (cons (list a b) *aloop-test-log*))
  nil)

(defun aloop-test-record3 (a b c)
  (setq *aloop-test-log* (cons (list a b c) *aloop-test-log*))
  nil)

;;; --- une seule clause ---

(setq *aloop-test-log* nil)
(aloop (list '(in (a b c))) 'aloop-test-record1)
(aloop-check "in-order"
  '(a b c)
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list '(below 3)) 'aloop-test-record1)
(aloop-check "below-default-start"
  '(0 1 2)
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list '(to 3)) 'aloop-test-record1)
(aloop-check "to-default-start"
  '(0 1 2 3)
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list '(upto 3)) 'aloop-test-record1)
(aloop-check "upto-is-synonym-of-to"
  '(0 1 2 3)
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list '(from 5 downto 2)) 'aloop-test-record1)
(aloop-check "from-downto-inclusive"
  '(5 4 3 2)
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list '(from 5 above 2)) 'aloop-test-record1)
(aloop-check "from-above-exclusive"
  '(5 4 3)
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list '(from 1 to 10)) 'aloop-test-record1)
(aloop-check "from-to-inclusive"
  '(1 2 3 4 5 6 7 8 9 10)
  (reverse *aloop-test-log*))

;;; --- by : pas explicite sur les clauses numériques ---

(setq *aloop-test-log* nil)
(aloop (list '(below 10 by 2)) 'aloop-test-record1)
(aloop-check "below-by-2"
  '(0 2 4 6 8)
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list '(from 10 downto 0 by 3)) 'aloop-test-record1)
(aloop-check "downto-by-3"
  '(10 7 4 1)
  (reverse *aloop-test-log*))

(aloop-check "by-must-be-strictly-positive"
  T
  (vl-catch-all-error-p (vl-catch-all-apply 'aloop (list (list '(below 10 by 0)) 'aloop-test-record1))))

;;; --- on : sous-listes successives ---

(setq *aloop-test-log* nil)
(aloop (list '(on (a b c))) 'aloop-test-record1)
(aloop-check "on-successive-tails"
  '((a b c) (b c) (c))
  (reverse *aloop-test-log*))

;;; --- in/on avec un by fonction de progression ---

(setq *aloop-test-log* nil)
(aloop (list '(in (a b c d) by cddr)) 'aloop-test-record1)
(aloop-check "in-by-cddr-skips-every-other"
  '(a c)
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list '(on (a b c d) by cddr)) 'aloop-test-record1)
(aloop-check "on-by-cddr-skips-every-other"
  '((a b c d) (c d))
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list '(in (a b c) by cadr)) 'aloop-test-record1)
(aloop-check "in-by-non-list-stepper-stops-gracefully"
  '(a)
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list (list 'in '(a marker b marker c)
                    'by (function (lambda (l) (cdr (member 'marker l))))))
       'aloop-test-record1)
(aloop-check "in-by-custom-member-stepper-skips-markers"
  '(a b c)
  (reverse *aloop-test-log*))

;;; --- then : pas calculé plutôt qu'arithmétique ---

(setq *aloop-test-log* nil)
(aloop (list (list 'from 1 'then (function (lambda (x) (* 2 x))) 'below 100)) 'aloop-test-record1)
(aloop-check "from-then-doubling-below-100"
  '(1 2 4 8 16 32 64)
  (reverse *aloop-test-log*))

(aloop-check "then-without-bound-fails"
  T
  (vl-catch-all-error-p
    (vl-catch-all-apply 'aloop
      (list (list (list 'from 1 'then (function (lambda (x) (* 2 x))))) 'aloop-test-record1))))

;;; --- clause construite dynamiquement (comme dans l'énoncé) ---

(setq *aloop-test-log* nil)
(setq aloop-test-my-list '("x" "y" "z"))
(aloop (list (list 'in aloop-test-my-list)) 'aloop-test-record1)
(aloop-check "in-dynamic-list"
  '("x" "y" "z")
  (reverse *aloop-test-log*))

;;; --- boucles imbriquées : ordre externe/interne ---

(setq *aloop-test-log* nil)
(aloop (list '(below 2) '(in (a b))) 'aloop-test-record2)
(aloop-check "nested-2-outer-slower-inner-faster"
  '((0 a) (0 b) (1 a) (1 b))
  (reverse *aloop-test-log*))

(setq *aloop-test-log* nil)
(aloop (list '(below 2) '(below 2) '(below 2)) 'aloop-test-record3)
(aloop-check "nested-3-full-cartesian-product"
  '((0 0 0) (0 0 1) (0 1 0) (0 1 1) (1 0 0) (1 0 1) (1 1 0) (1 1 1))
  (reverse *aloop-test-log*))

;;; --- cas limites ---

(setq *aloop-test-log* nil)
(aloop nil 'aloop-test-record0)
(aloop-check "zero-clauses-calls-fn-once"
  '(called)
  *aloop-test-log*)

(setq *aloop-test-log* nil)
(aloop (list '(below 0) '(in (a b))) 'aloop-test-record2)
(aloop-check "empty-range-calls-fn-zero-times"
  nil
  *aloop-test-log*)

(aloop-check "aloop-returns-nil"
  nil
  (aloop (list '(below 2)) 'aloop-test-record1))

(if (= *aloop-test-fails* 0)
  (princ "TESTS OK")
  (progn (princ "TESTS FAILED: ") (princ *aloop-test-fails*)))
(terpri)

(defun C:MAIN ()
  (if (= *aloop-test-fails* 0) "OK" "FAIL"))
