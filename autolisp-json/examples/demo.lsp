;;; demo.lsp --- Démonstration d'autolisp-json
;;;
;;; Utilisation (depuis autolisp-json/) :
;;;
;;;   ../autolisp-script/autolisp --bricscad \
;;;       src/autolisp-json.lsp \
;;;       examples/demo.lsp \
;;;       -x '(C:AJ-DEMO)'
;;;
;;; ou, en interactif dans BricsCAD/AutoCAD après avoir chargé
;;; src/autolisp-json.lsp :
;;;
;;;   (load "examples/demo.lsp") (C:AJ-DEMO)

(defun C:AJ-DEMO (/ data pretty back gares)

  ;; 1. Construire une sexp balisée à la main.
  (setq data
        (list 'aj-object
              (cons "nom" "Ligne 42")
              (cons "electrifiee" 'aj-true)
              (cons "longueur_km" 128.5)
              (cons "voies" 2)
              (cons "gares" (list 'aj-array "Nord" "Centre" "Sud"))
              (cons "exploitant" 'aj-null)))

  ;; 2. Sérialiser en JSON compact puis indenté.
  (princ "\n--- JSON compact ---\n")
  (princ (aj-encode data))

  (princ "\n\n--- JSON indenté ---\n")
  (setq pretty (aj-encode-pretty data))
  (princ pretty)

  ;; 3. Désérialiser la chaîne indentée et vérifier l'aller-retour.
  (setq back (aj-decode pretty))
  (princ "\n\n--- Aller-retour identique ? ---\n")
  (princ (if (equal data back) "oui" "non"))

  ;; 4. Accès aux champs.
  (princ "\n\n--- Accès aux champs ---\n")
  (princ (strcat "nom          = " (aj-object-get back "nom")))
  (princ (strcat "\nlongueur_km  = " (aj-encode (aj-object-get back "longueur_km"))))
  (setq gares (aj-array-items (aj-object-get back "gares")))
  (princ (strcat "\nnombre gares = " (itoa (length gares))))

  ;; 5. Lecture d'un fichier JSON (traitement en bloc).
  (if (findfile "examples/sample.json")
    (progn
      (princ "\n\n--- Lecture de examples/sample.json ---\n")
      (setq data (aj-read-file "examples/sample.json"))
      (princ (strcat "electrifiee = " (aj-encode (aj-object-get data "electrifiee"))))
      (princ (strcat "\ncoordonnees.debut = "
                     (aj-encode (aj-object-get (aj-object-get data "coordonnees") "debut"))))))

  (princ "\n")
  (princ))
