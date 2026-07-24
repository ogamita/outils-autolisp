;;; introspection-tests.lsp --- Tests d'autolisp-introspection

(defsuite "autolisp-introspection")
(in-suite "autolisp-introspection")

(defun ei-test-rec (handle dxf xdata)
  (ei--make-rec handle nil (cdr (assoc 0 dxf)) dxf xdata))

(defun ei-test-ac (ediff code)
  (t:find-ac ediff code))

(defun schms-affecte-pk (ename pk / data)
  (regapp "SCHMS_PK")
  (setq data (entget ename))
  (setq data (subst '(8 . "PK") (assoc 8 data) data))
  (setq data (subst (cons 1 pk) (assoc 1 data) data))
  (setq data
    (append data
      (list (list -3 (list "SCHMS_PK" (cons 1000 pk))))))
  (entmod data)
  ename)

(deftest
  "diff vide"
  (function
    (lambda (/ diff)
      (setq diff (ei-diff nil nil))
      (attendu-egal nil (ei-added diff) nil)
      (attendu-egal nil (ei-deleted diff) nil)
      (attendu-egal nil (ei-modified diff) nil))))

(deftest
  "added and deleted records use handles"
  (function
    (lambda (/ first second diff)
      (setq first (ei-test-rec "A" '((0 . "LINE") (8 . "0")) nil))
      (setq second (ei-test-rec "B" '((0 . "TEXT") (1 . "x")) nil))
      (setq diff (ei-diff (list (cons "A" first))
                          (list (cons "B" second))))
      (attendu-creees diff 1 nil)
      (attendu-supprimees diff 1 nil)
      (attendu-egal "B" (ei-rec-handle (car (ei-added diff))) nil)
      (attendu-egal "A" (ei-rec-handle (car (ei-deleted diff))) nil))))

(deftest
  "single-valued attribute change"
  (function
    (lambda (/ before after ediff ac)
      (setq before (ei-test-rec "A" '((0 . "TEXT") (8 . "0") (1 . "ancien")) nil))
      (setq after  (ei-test-rec "A" '((0 . "TEXT") (8 . "PK") (1 . "nouveau")) nil))
      (setq ediff (ei-entity-diff before after))
      (setq ac (ei-test-ac ediff 8))
      (attendu-egal :changed (ei-ac-kind ac) nil)
      (attendu-egal "0" (ei-ac-old ac) nil)
      (attendu-egal "PK" (ei-ac-new ac) nil))))

(deftest
  "multi-valued attribute preserves order"
  (function
    (lambda (/ before after ediff ac)
      (setq before (ei-test-rec "A"
                     '((0 . "LWPOLYLINE") (10 0.0 0.0) (10 1.0 0.0)) nil))
      (setq after (ei-test-rec "A"
                    '((0 . "LWPOLYLINE") (10 0.0 0.0) (10 2.0 0.0)) nil))
      (setq ediff (ei-entity-diff before after))
      (setq ac (ei-test-ac ediff 10))
      (attendu-egal :multi (ei-ac-kind ac) nil)
      (attendu-egal '((0.0 0.0) (1.0 0.0)) (ei-ac-old ac) nil)
      (attendu-egal '((0.0 0.0) (2.0 0.0)) (ei-ac-new ac) nil))))

(deftest
  "real and point fuzz"
  (function
    (lambda (/ old-fuzz before near far)
      (setq old-fuzz ei-*fuzz*)
      (setq ei-*fuzz* 0.001)
      (setq before (ei-test-rec "A" '((10 1.0 2.0 0.0)) nil))
      (setq near   (ei-test-rec "A" '((10 1.0005 2.0 0.0)) nil))
      (setq far    (ei-test-rec "A" '((10 1.01 2.0 0.0)) nil))
      (attendu-egal nil
        (ei-attr-changes (ei-entity-diff before near)) nil)
      (attendu-egal 1
        (length (ei-attr-changes (ei-entity-diff before far))) nil)
      (setq ei-*fuzz* old-fuzz))))

(deftest
  "xdata added deleted and modified"
  (function
    (lambda (/ before after ediff)
      (setq before
        (ei-test-rec "A" nil
          '(((1001 . "DEL") (1000 . "a"))
            ((1001 . "MOD") (1070 . 1)))))
      (setq after
        (ei-test-rec "A" nil
          '(((1001 . "ADD") (1000 . "b"))
            ((1001 . "MOD") (1070 . 2)))))
      (setq ediff (ei-entity-diff before after))
      (attendu-egal "ADD" (ei-xd-app (car (ei-xdata-added ediff))) nil)
      (attendu-egal "DEL" (ei-xd-app (car (ei-xdata-deleted ediff))) nil)
      (attendu-egal "MOD" (ei-xd-app (car (ei-xdata-modified ediff))) nil)
      (attendu-xdata-ajoutee
        ediff "ADD" '((1001 . "ADD") (1000 . "b")) nil)
      (attendu-xdata-supprimee ediff "DEL" nil)
      (attendu-xdata-modifiee
        ediff "MOD"
        '((1001 . "MOD") (1070 . 1))
        '((1001 . "MOD") (1070 . 2)) nil))))

(deftest
  "DSL sur une modification unique"
  (function
    (lambda (/ before after diff ediff)
      (setq before (ei-test-rec "A" '((8 . "0") (1 . "ancien") (10 0.0 0.0)) nil))
      (setq after
        (ei-test-rec "A" '((8 . "PK") (1 . "12+345") (10 0.0 0.0))
          '(((1001 . "SCHMS_PK") (1000 . "12+345")))))
      (setq diff (ei-diff (list (cons "A" before))
                          (list (cons "A" after))))
      (attendu-aucune-creation diff nil)
      (attendu-aucune-suppression diff nil)
      (attendu-modifiees diff 1 nil)
      (setq ediff (modif-unique diff))
      (attendu-attribut-modifie ediff 8 "0" "PK" nil)
      (attendu-attribut-modifie ediff 1 "ancien" "12+345" nil)
      (attendu-attribut-inchange ediff 10 nil)
      (attendu-xdata-ajoutee
        ediff "SCHMS_PK"
        '((1001 . "SCHMS_PK") (1000 . "12+345")) nil))))

(if (= (getenv "EI_CAD_TESTS") "1")
  (progn
    (deftest
      "real drawing addition and deletion"
      (function
        (lambda (/ before entity after-created after-deleted diff)
          (setq before (ei-snapshot 'all))
          (setq entity
            (entmakex '((0 . "LINE") (8 . "0")
                        (10 0.0 0.0 0.0) (11 1.0 1.0 0.0))))
          (setq after-created (ei-snapshot 'all))
          (setq diff (ei-diff before after-created))
          (attendu-creees diff 1 nil)
          (entdel entity)
          (setq after-deleted (ei-snapshot 'all))
          (setq diff (ei-diff after-created after-deleted))
          (attendu-supprimees diff 1 nil))))

    (deftest
      "real drawing selection-set scope"
      (function
        (lambda (/ first second set snapshot)
          (setq first
            (entmakex '((0 . "LINE") (8 . "0")
                        (10 0.0 0.0 0.0) (11 1.0 0.0 0.0))))
          (setq second
            (entmakex '((0 . "CIRCLE") (8 . "0")
                        (10 2.0 2.0 0.0) (40 . 1.0))))
          (setq set (ssadd))
          (ssadd first set)
          (setq snapshot (ei-snapshot set))
          (attendu-egal 1 (length snapshot) nil)
          (attendu-egal "LINE" (ei-rec-type (cdar snapshot)) nil)
          (attendu-egal
            (cdr (assoc 5 (entget first)))
            (ei--normalize first)
            nil)
          (entdel first)
          (entdel second))))

    (deftest
      "schms-affecte-pk modifie attributs et xdata"
      (function
        (lambda (/ entity handle before after changed removed diff ediff data)
          (setq entity
            (entmakex '((0 . "TEXT") (8 . "0") (10 0.0 0.0 0.0)
                        (40 . 2.5) (1 . "ancien"))))
          (setq handle (cdr (assoc 5 (entget entity))))
          (setq before (ei-snapshot (list entity)))
          (schms-affecte-pk entity "12+345")
          (setq after (ei-snapshot (list entity)))
          (setq diff (ei-diff before after))
          (attendu-modifiees diff 1 nil)
          (setq ediff (modif-entite diff handle))
          (attendu-attribut-modifie ediff 8 "0" "PK" nil)
          (attendu-attribut-modifie ediff 1 "ancien" "12+345" nil)
          (attendu-attribut-inchange ediff 10 nil)
          (attendu-xdata-ajoutee
            ediff "SCHMS_PK"
            '((1001 . "SCHMS_PK") (1000 . "12+345")) nil)
          (setq data (entget entity '("*")))
          (setq data
            (subst '(-3 ("SCHMS_PK" (1000 . "99+999")))
                   (assoc -3 data)
                   data))
          (entmod data)
          (setq changed (ei-snapshot (list entity)))
          (setq ediff
            (modif-unique (ei-diff after changed)))
          (attendu-xdata-modifiee
            ediff "SCHMS_PK"
            '((1001 . "SCHMS_PK") (1000 . "12+345"))
            '((1001 . "SCHMS_PK") (1000 . "99+999"))
            nil)
          (setq data (entget entity '("*")))
          (setq data
            (subst '(-3 ("SCHMS_PK"))
                   (assoc -3 data)
                   data))
          (entmod data)
          (setq removed (ei-snapshot (list entity)))
          (setq ediff
            (modif-unique (ei-diff changed removed)))
          (attendu-xdata-supprimee ediff "SCHMS_PK" nil)
          (entdel entity))))))
