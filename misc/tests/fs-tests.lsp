;;; fs-tests.lsp --- Tests unitaires de misc/src/fs.lsp
;;;
;;; Ce script exerce les helpers de fs.lsp (manipulation de chemins,
;;; cwd virtuel) et produit un rapport texte déterministe, indépendant
;;; de la machine et du système de fichiers réel.
;;;
;;; Les cas d'erreur qui passent par =prompt= (cd vers un répertoire
;;; inexistant, argument de mauvais type, etc.) ne sont pas exercés
;;; ici : la capture du flux =prompt= varie selon le runtime. On se
;;; contente de vérifier les chemins nominaux et les helpers purs.

(load "misc/src/fs.lsp")

(setq *fs-test-fails* 0)

(defun check (label pred)
  (if pred
    (progn (princ "PASS ") (princ label) (terpri))
    (progn (princ "FAIL ") (princ label) (terpri)
           (setq *fs-test-fails* (1+ *fs-test-fails*)))))

;; Normalisation de chemins
(check "normalize-dot"       (= (fs--normalize "/tmp/./foo") "/tmp/foo"))
(check "normalize-parent"    (= (fs--normalize "/tmp/foo/..") "/tmp"))
(check "normalize-double"    (= (fs--normalize "/tmp//foo") "/tmp/foo"))
(check "normalize-backslash" (= (fs--normalize "C:\\foo\\bar") "C:/foo/bar"))
(check "normalize-empty"     (= (fs--normalize "") "."))
(check "normalize-root"      (= (fs--normalize "/") "/"))

;; Détection absolu / relatif
(check "absolute-unix"    (if (fs--absolute-p "/etc") T nil))
(check "absolute-windows" (if (fs--absolute-p "C:/foo") T nil))
(check "relative"         (null (fs--absolute-p "foo/bar")))
(check "empty-relative"   (null (fs--absolute-p "")))

;; Jointure
(check "join-trailing"    (= (fs--join "/tmp/" "foo") "/tmp/foo"))
(check "join-no-trailing" (= (fs--join "/tmp" "foo") "/tmp/foo"))
(check "join-empty-base"  (= (fs--join "" "foo") "foo"))

;; Découpage
(check "split-basic" (equal (fs--split "a/b/c" "/") '("a" "b" "c")))
(check "split-one"   (equal (fs--split "foo" "/") '("foo")))

;; Résolution relative au cwd virtuel
(setq *misc-cwd* "/tmp")
(check "resolve-relative" (= (fs--resolve "foo") "/tmp/foo"))
(check "resolve-absolute" (= (fs--resolve "/etc") "/etc"))
(check "resolve-parent"   (= (fs--resolve "..") "/"))
(check "resolve-dot"      (= (fs--resolve ".") "/tmp"))

;; cd nominal : chemin absolu existant (on choisit la racine, qui
;; existe sur tout système Unix/macOS utilisé en CI ici).
(if (vl-file-directory-p "/")
  (progn
    (setq *misc-cwd* "/tmp")
    (cd "/")
    (check "cd-root-absolute" (= *misc-cwd* "/")))
  (check "cd-root-absolute-skipped" T))

;; Rapport final
(if (= *fs-test-fails* 0)
  (princ "TESTS OK")
  (progn (princ "TESTS FAILED: ") (princ *fs-test-fails*)))
(terpri)

(defun C:MAIN ()
  (if (= *fs-test-fails* 0) "OK" "FAIL"))
