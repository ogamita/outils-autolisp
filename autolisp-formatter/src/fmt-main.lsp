;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; fmt-main.lsp --- API publique et pilote en ligne de commande.
;;;;
;;;; API :
;;;;   (fmt-format-string TEXTE OPTIONS)      -> texte formaté
;;;;   (fmt-format TEXTE ITEMS)               -> idem, options non normalisées
;;;;   (fmt-check-string TEXTE OPTIONS)       -> T si déjà conforme
;;;;   (fmt-format-file ENTREE SORTIE OPTIONS)
;;;;   (fmt-check-file FICHIER OPTIONS)       -> T si déjà conforme
;;;;   (fmt-main ITEMS)                       -> code de retour (0/1/2)
;;;;
;;;; ITEMS est la liste d'options telle qu'elle arrive de la ligne de
;;;; commande, du fichier de configuration ou d'un appel programmatique ;
;;;; c'est fmt-build-options qui en fait une structure normalisée.

;;; ------------------------------------------------------------------
;;; Formatage
;;; ------------------------------------------------------------------

(defun fmt-exceptions-of (opts / path)
  (setq path (fmt-option opts "case-exceptions-file"))
  (if path (fmt-load-case-exceptions path) nil))

;; Texte -> texte. OPTS est une alist normalisée (fmt-build-options).
(defun fmt-format-string (text opts / toks nodes)
  (fmt-case-reset-seen)
  (setq toks  (fmt-scan text))
  (setq nodes (fmt-parse toks))
  (fmt-print nodes opts (fmt-exceptions-of opts)))

;; Variante « tout en un » : options brutes.
(defun fmt-format (text items)
  (fmt-format-string text (fmt-build-options items)))

(defun fmt-check-string (text opts)
  (= (fmt-format-string text opts) (fmt-normalized-source text)))

;; Le source d'entrée ramené à la forme que produirait le formateur pour un
;; fichier déjà conforme : lignes sans blancs de fin, terminé par un \n.
(defun fmt-normalized-source (text / lines)
  (setq lines (mapcar (function fmt-trim-right) (fmt-split-lines text)))
  (while (and lines (= (car lines) ""))
    (setq lines (cdr lines)))
  (setq lines (reverse lines))
  (while (and lines (= (car lines) ""))
    (setq lines (cdr lines)))
  (setq lines (reverse lines))
  (if (null lines)
    ""
    (strcat (fmt-string-join lines "\n") "\n")))

(defun fmt-format-file (in-path out-path opts / text out)
  (setq text (fmt-read-file in-path))
  (setq out  (fmt-format-string text opts))
  (fmt-write-file out-path out)
  out)

(defun fmt-check-file (path opts)
  (fmt-check-string (fmt-read-file path) opts))

;;; ------------------------------------------------------------------
;;; Diagnostics
;;; ------------------------------------------------------------------

;; Lignes du source en « nail-clipping à fermetures empilées ».
(defun fmt-stacked-report (text)
  (reverse (fmt-stacked-closer-lines (fmt-scan text))))

(defun fmt-report-line (s)
  (princ (strcat s "\n"))
  (princ))

;;; ------------------------------------------------------------------
;;; Pilote
;;; ------------------------------------------------------------------

(defun fmt-usage ()
  (fmt-report-line "usage: autolisp-format [OPTIONS] FICHIER...")
  (fmt-report-line "")
  (fmt-report-line "  --style cl|nail|stacked-nail")
  (fmt-report-line "  --symbol-case preserve|downcase|upcase")
  (fmt-report-line "  --comment-style preserve|cl")
  (fmt-report-line "  --block-comments preserve|to-semicolons")
  (fmt-report-line "  --contextual-comments yes|no")
  (fmt-report-line "  --inline-comment-column N")
  (fmt-report-line "  --case-exceptions FICHIER")
  (fmt-report-line "  --check-case-exceptions")
  (fmt-report-line "  --report-stacked")
  (fmt-report-line "  --config FICHIER")
  (fmt-report-line "  --in-place")
  (fmt-report-line "  --check")
  (fmt-report-line "  --output FICHIER"))

;; Traite un fichier. Renvoie 0 (conforme / écrit) ou 1 (non conforme).
(defun fmt-process-file (path opts / text out status exceptions stacked)
  (setq text   (fmt-read-file path))
  (setq status 0)

  (if (fmt-option opts "report-stacked")
    (progn
      (setq stacked (fmt-stacked-report text))
      (foreach line stacked
        (fmt-report-line (strcat path ":" (itoa line)
                                 ": fermetures empilées")))))

  (setq out (fmt-format-string text opts))

  (if (fmt-option opts "check-case-exceptions")
    (progn
      (setq exceptions (fmt-exceptions-of opts))
      (foreach sym (fmt-unused-case-exceptions exceptions)
        (fmt-report-line (strcat path ": exception de casse jamais rencontrée : "
                                 sym)))))

  (cond
    ((fmt-option opts "check")
     (if (= out (fmt-normalized-source text))
       (setq status 0)
       (progn
         (fmt-report-line (strcat path ": non conforme"))
         (setq status 1))))
    ((fmt-option opts "in-place")
     (fmt-write-file path out))
    ((fmt-option opts "output")
     (fmt-write-file (fmt-option opts "output") out))
    (t
     (princ out)
     (princ)))
  status)

;; Point d'entrée du programme. Renvoie 0 (succès), 1 (au moins un fichier
;; non conforme en mode --check) ou 2 (erreur).
(defun fmt-main (items / opts files status r)
  (setq r (vl-catch-all-apply
            (function
              (lambda ()
                (setq opts  (fmt-build-options items))
                (setq files (fmt-option opts "files"))
                (if (null files)
                  (progn
                    (fmt-usage)
                    (setq status 2))
                  (progn
                    (setq status 0)
                    (foreach path files
                      (if (= (fmt-process-file path opts) 1)
                        (setq status 1)))))
                status))
            nil))
  (if (vl-catch-all-error-p r)
    (progn
      (fmt-report-line (vl-catch-all-error-message r))
      2)
    r))

(princ)

;;; fmt-main.lsp ends here
