;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; run-tests.lsp --- Point d'entrée des tests autolisp-formatter.
;;;;
;;;; Le classement des résultats est refait ici plutôt que d'appeler
;;;; run-suite : le framework partagé construit ses marqueurs avec des
;;;; littéraux :ok / :fail / :error, or « :foo » ne s'auto-évalue pas en
;;;; AutoLISP (ni sous BricsCAD ou AutoCAD, ni sous clautolisp) — ces
;;;; marqueurs valent tous nil, si bien que (eq (car res) :ok) est vrai pour
;;;; n'importe quel résultat et qu'un échec serait compté comme succès.
;;;; Les marqueurs sont donc cités ('OK, 'FAIL, 'ERROR) et la comparaison
;;;; porte sur des symboles réellement distincts.
;;;;
;;;; Les assertions (is, is-equal, signals-error) du framework partagé
;;;; restent utilisées telles quelles : elles signalent par (error …), ce
;;;; qui fonctionne correctement.

(defun ft-classify (fn / r em)
  (setq r (vl-catch-all-apply fn nil))
  (if (vl-catch-all-error-p r)
    (progn
      (setq em (vl-catch-all-error-message r))
      (if (null em) (setq em ""))
      (if (wcmatch em "TEST-FAIL:*")
        (list 'FAIL em)
        (list 'ERROR em)))
    (list 'OK "")))

(defun ft-run-suite (suite-name / cell tests total ok fail err res status msg)
  (setq cell (assoc suite-name *t:suites*))
  (if (null cell)
    (progn
      (princ (strcat "\n[run-tests] suite inconnue : " suite-name "\n"))
      nil)
    (progn
      (setq tests (reverse (cdr cell)))
      (setq total 0)
      (setq ok    0)
      (setq fail  0)
      (setq err   0)
      (foreach test tests
        (setq total  (1+ total))
        (setq res    (ft-classify (cadr test)))
        (setq status (car res))
        (setq msg    (cadr res))
        (cond
          ((eq status 'OK)
           (setq ok (1+ ok))
           (princ (strcat "OK    [" suite-name "] " (car test) "\n")))
          ((eq status 'FAIL)
           (setq fail (1+ fail))
           (princ (strcat "FAIL  [" suite-name "] " (car test) " -- " msg "\n")))
          (t
           (setq err (1+ err))
           (princ (strcat "ERROR [" suite-name "] " (car test) " -- " msg "\n")))))
      (princ (strcat "---- Suite [" suite-name "] ----\n"))
      (princ (strcat "Total: " (itoa total)
                     "  OK: " (itoa ok)
                     "  FAIL: " (itoa fail)
                     "  ERROR: " (itoa err) "\n"))
      (list total ok fail err))))

;; Les fixtures de configuration sont des fichiers .lsp ouverts par le
;; formateur : sous clautolisp (SECURELOAD=1) chaque lecture émet un
;; avertissement « untrusted location ». On déclare le dossier de fixtures
;; comme sûr le temps des tests. Emballé : TRUSTEDPATHS n'est pas garanti
;; accessible en écriture sur toutes les CAO.
(defun ft-trust-fixtures (/ f)
  (vl-catch-all-apply
    (function
      (lambda ()
        (setq f (findfile "tests/fixtures/capitalisation.txt"))
        (if f (setvar "TRUSTEDPATHS" (vl-filename-directory f)))))
    nil))

(defun C:MAIN (/ summary)
  (ft-trust-fixtures)
  (setq summary (ft-run-suite "autolisp-formatter"))
  (if (and summary
           (= (nth 2 summary) 0)
           (= (nth 3 summary) 0)
           (> (nth 0 summary) 0))
    (t:set-status 0)
    (t:set-status 1))
  (princ ""))

(princ)

;;; run-tests.lsp ends here
