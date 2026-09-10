;;; map-tests.lsp --- Tests unitaires de autolisp-misc/src/map.lsp

;;; =map.lsp= doit être chargé par le harness avant ce script.

(setq *map-test-fails* 0)
(setq *map-test-log* nil)

(defun map-check (label expected actual)
  (if (equal expected actual)
    (progn (princ "PASS ") (princ label) (terpri))
    (progn
      (princ "FAIL ") (princ label) (terpri)
      (princ "  expected: ") (princ (vl-prin1-to-string expected)) (terpri)
      (princ "  actual:   ") (princ (vl-prin1-to-string actual)) (terpri)
      (setq *map-test-fails* (1+ *map-test-fails*)))))

(defun map-test-record (x)
  (setq *map-test-log* (cons x *map-test-log*))
  nil)

(defun map-test-record2 (a b)
  (setq *map-test-log* (cons (list a b) *map-test-log*))
  nil)

;;; --- mapc ---

(setq *map-test-log* nil)
(map-check "mapc-returns-list"
  '(1 2 3)
  (mapc 'map-test-record '(1 2 3)))

(map-check "mapc-calls-fn-per-element"
  '(3 2 1)
  *map-test-log*)

(map-check "mapc-empty-list"
  nil
  (mapc 'map-test-record '()))

;;; --- mapc* ---

(setq *map-test-log* nil)
(map-check "mapc*-returns-first-list"
  '(1 2 3)
  (mapc* 'map-test-record2 (list '(1 2 3) '(10 20 30))))

(map-check "mapc*-calls-fn-per-position"
  '((3 30) (2 20) (1 10))
  *map-test-log*)

(setq *map-test-log* nil)
(mapc* 'map-test-record2 (list '(1 2 3) '(10 20)))
(map-check "mapc*-stops-at-shortest-list"
  '((2 20) (1 10))
  *map-test-log*)

;;; --- mapl ---

(setq *map-test-log* nil)
(map-check "mapl-returns-list"
  '(1 2 3)
  (mapl 'map-test-record '(1 2 3)))

(map-check "mapl-receives-successive-tails"
  '((3) (2 3) (1 2 3))
  *map-test-log*)

;;; --- mapl* ---

(setq *map-test-log* nil)
(map-check "mapl*-returns-first-list"
  '(1 2)
  (mapl* 'map-test-record2 (list '(1 2) '(A B))))

(map-check "mapl*-receives-successive-tail-tuples"
  '(((2) (B)) ((1 2) (A B)))
  *map-test-log*)

;;; --- maplist ---

(map-check "maplist-basic"
  '((3 2 1) (3 2) (3))
  (maplist 'reverse '(1 2 3)))

(map-check "maplist-empty-list"
  nil
  (maplist 'reverse '()))

;;; --- maplist* ---

(map-check "maplist*-basic"
  '((0 1 2 A B C) (1 2 B C) (2 C))
  (maplist* 'append (list '(0 1 2) '(A B C))))

(map-check "maplist*-stops-at-shortest-list"
  '((1 2 A))
  (maplist* 'append (list '(1 2) '(A))))

;;; --- mapcan ---

(map-check "mapcan-basic"
  '(1 1 2 2 3 3)
  (mapcan (function (lambda (x) (list x x))) '(1 2 3)))

(map-check "mapcan-empty-list"
  nil
  (mapcan 'list '()))

;;; --- mapcan* ---

(map-check "mapcan*-basic"
  '(1 A 2 B 3 C)
  (mapcan* 'list (list '(1 2 3) '(A B C))))

(map-check "mapcan*-stops-at-shortest-list"
  '(1 A 2 B)
  (mapcan* 'list (list '(1 2 3) '(A B))))

;;; --- mapcon ---

(map-check "mapcon-basic"
  '(3 2 1 3 2 3)
  (mapcon 'reverse '(1 2 3)))

;;; --- mapcon* ---

(map-check "mapcon*-basic"
  '(0 1 2 A B C 1 2 B C 2 C)
  (mapcon* 'append (list '(0 1 2) '(A B C))))

(if (= *map-test-fails* 0)
  (princ "TESTS OK")
  (progn (princ "TESTS FAILED: ") (princ *map-test-fails*)))
(terpri)

(defun C:MAIN ()
  (if (= *map-test-fails* 0) "OK" "FAIL"))
