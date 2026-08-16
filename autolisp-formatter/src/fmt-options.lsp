;;;; -*- mode:lisp; coding:utf-8 -*-
;;;; fmt-options.lsp --- Analyse et normalisation des options du formateur.
;;;;
;;;; Module unique d'interprétation des options, partagé par les trois voies
;;;; d'entrée prévues par la spécification :
;;;;
;;;;   - la ligne de commande        (--style cl --symbol-case downcase …)
;;;;   - le fichier de configuration (:style-parentheses :cl …)
;;;;   - l'appel programmatique      (liste d'options passée à l'API)
;;;;
;;;; Les trois produisent la même structure interne normalisée : une alist
;;;; dont les clés sont les chaînes canoniques ci-dessous.
;;;;
;;;; Priorité (spécification § « Résolution des conflits ») :
;;;;   1. options de l'appel courant
;;;;   2. options du fichier de configuration
;;;;   3. valeurs par défaut

;;; ------------------------------------------------------------------
;;; Valeurs par défaut
;;; ------------------------------------------------------------------

(defun fmt-default-options ()
  (list
    (cons "paren-style"           'CL)
    (cons "symbol-case"           'PRESERVE)
    (cons "comment-style"         'PRESERVE)
    (cons "block-comments"        'PRESERVE)
    (cons "contextual-comments"   nil)
    (cons "inline-comment-column" nil)
    (cons "case-exceptions-file"  nil)
    (cons "check-case-exceptions" nil)
    (cons "report-stacked"        nil)
    (cons "in-place"              nil)
    (cons "check"                 nil)
    (cons "output"                nil)
    (cons "config"                nil)
    (cons "files"                 nil)))

(defun fmt-option (opts key)
  (fmt-alist-get opts key))

(defun fmt-option-set (opts key value)
  (fmt-alist-put opts key value))

;;; ------------------------------------------------------------------
;;; Table des noms acceptés
;;; ------------------------------------------------------------------
;;; (NOM-ACCEPTÉ CLÉ-CANONIQUE TYPE), TYPE ∈ ENUM INT BOOL STR.
;;; Les noms sont comparés après suppression des « - » et « : » de tête et
;;; passage en majuscules : « --style », « :style » et « STYLE » coïncident.

(defun fmt-option-table ()
  (list
    (list "STYLE"                          "paren-style"           'ENUM)
    (list "PAREN-STYLE"                    "paren-style"           'ENUM)
    (list "STYLE-PARENTHESES"              "paren-style"           'ENUM)
    (list "SYMBOL-CASE"                    "symbol-case"           'ENUM)
    (list "CASSE-SYMBOLES"                 "symbol-case"           'ENUM)
    (list "COMMENT-STYLE"                  "comment-style"         'ENUM)
    (list "STYLE-COMMENTAIRES"             "comment-style"         'ENUM)
    (list "BLOCK-COMMENTS"                 "block-comments"        'ENUM)
    (list "COMMENTAIRES-BLOC"              "block-comments"        'ENUM)
    (list "CONTEXTUAL-COMMENTS"            "contextual-comments"   'BOOL)
    (list "COMMENTAIRES-CONTEXTUELS"       "contextual-comments"   'BOOL)
    (list "INLINE-COMMENT-COLUMN"          "inline-comment-column" 'INT)
    (list "COLONNE-COMMENTAIRES-EN-LIGNE"  "inline-comment-column" 'INT)
    (list "CASE-EXCEPTIONS"                "case-exceptions-file"  'STR)
    (list "CASE-EXCEPTIONS-FILE"           "case-exceptions-file"  'STR)
    (list "FICHIER-EXCEPTIONS-CASSE"       "case-exceptions-file"  'STR)
    (list "CHECK-CASE-EXCEPTIONS"          "check-case-exceptions" 'BOOL)
    (list "CONTROLE-EXCEPTIONS-CASSE"      "check-case-exceptions" 'BOOL)
    (list "REPORT-STACKED"                 "report-stacked"        'BOOL)
    (list "SIGNALER-EMPILEES"              "report-stacked"        'BOOL)
    (list "IN-PLACE"                       "in-place"              'BOOL)
    (list "SUR-PLACE"                      "in-place"              'BOOL)
    (list "CHECK"                          "check"                 'BOOL)
    (list "VERIFIER"                       "check"                 'BOOL)
    (list "OUTPUT"                         "output"                'STR)
    (list "SORTIE"                         "output"                'STR)
    (list "CONFIG"                         "config"                'STR)
    (list "CONFIG-FILE"                    "config"                'STR)
    (list "FICHIER-CONFIGURATION"          "config"                'STR)))

;; Nom d'option normalisé, ou nil si ITEM n'a pas la forme d'un nom d'option.
(defun fmt-option-name (item / s codes)
  (setq s (fmt-name-of item))
  (setq codes (vl-string->list s))
  (if (or (null codes)
          (not (or (= (car codes) 45)     ; -
                   (= (car codes) 58))))  ; :
    nil
    (progn
      (while (and codes
                  (or (= (car codes) 45) (= (car codes) 58)))
        (setq codes (cdr codes)))
      (if codes (vl-list->string codes) nil))))

(defun fmt-option-entry (name)
  (assoc name (fmt-option-table)))

;;; ------------------------------------------------------------------
;;; Normalisation des valeurs
;;; ------------------------------------------------------------------

(defun fmt-boolean-value-p (item / n)
  (setq n (fmt-value-name item))
  (or (= n "T") (= n "NIL") (= n "YES") (= n "NO")
      (= n "OUI") (= n "NON") (= n "TRUE") (= n "FALSE")))

(defun fmt-boolean-value (item / n)
  (setq n (fmt-value-name item))
  (not (or (= n "NIL") (= n "NO") (= n "NON") (= n "FALSE"))))

(defun fmt-int-value (item)
  (cond
    ((= (type item) 'INT)  item)
    ((= (type item) 'REAL) (fix item))
    ((null item)           nil)
    ((= (fmt-name-of item) "NIL") nil)
    ((= (fmt-name-of item) "NONE") nil)
    (t (atoi (vl-princ-to-string item)))))

;; Valeur d'énumération canonique pour KEY, ou nil si VALUE est inconnue.
(defun fmt-enum-value (key value / n)
  (setq n (fmt-value-name value))
  (cond
    ((= key "paren-style")
     (cond ((= n "CL")                                  'CL)
           ((= n "NAIL")                                'NAIL)
           ((or (= n "STACKED-NAIL") (= n "EMPILEES")
                (= n "NAIL-EMPILE"))                    'STACKED-NAIL)
           (t nil)))
    ((= key "symbol-case")
     (cond ((or (= n "PRESERVE") (= n "PRESERVER"))     'PRESERVE)
           ((or (= n "DOWNCASE") (= n "MINUSCULES"))    'DOWNCASE)
           ((or (= n "UPCASE")   (= n "MAJUSCULES"))    'UPCASE)
           (t nil)))
    ((= key "comment-style")
     (cond ((or (= n "PRESERVE") (= n "PRESERVER"))     'PRESERVE)
           ((= n "CL")                                  'CL)
           (t nil)))
    ((= key "block-comments")
     (cond ((or (= n "PRESERVE") (= n "PRESERVER"))     'PRESERVE)
           ((or (= n "TO-SEMICOLONS")
                (= n "POINTS-VIRGULES"))                'TO-SEMICOLONS)
           (t nil)))
    (t nil)))

(defun fmt-string-value (item)
  (cond
    ((null item)              nil)
    ((= (type item) 'STR)     item)
    (t                        (vl-princ-to-string item))))

;;; ------------------------------------------------------------------
;;; Analyse d'une suite d'items
;;; ------------------------------------------------------------------

;; ITEMS : liste de chaînes (ligne de commande) et/ou de symboles, nombres et
;; chaînes (fichier de configuration, appel programmatique).
;; Renvoie OPTS enrichie ; les arguments positionnels s'accumulent sous
;; la clé "files", dans l'ordre.
(defun fmt-parse-args (items opts / item name entry key kind value files)
  (setq files (fmt-option opts "files"))
  (while items
    (setq item  (car items))
    (setq items (cdr items))
    (setq name  (fmt-option-name item))
    (setq entry (if name (fmt-option-entry name) nil))
    (cond

      ;; nom d'option connu
      (entry
       (setq key  (nth 1 entry))
       (setq kind (nth 2 entry))
       (cond
         ((eq kind 'BOOL)
          ;; « --check » vaut T ; « :verifier nil » est également accepté.
          (if (and items (fmt-boolean-value-p (car items)))
            (progn
              (setq opts  (fmt-option-set opts key (fmt-boolean-value (car items))))
              (setq items (cdr items)))
            (setq opts (fmt-option-set opts key t))))
         ((null items)
          (fmt-error (strcat "valeur manquante pour l'option " name) nil nil))
         ((eq kind 'INT)
          (setq opts  (fmt-option-set opts key (fmt-int-value (car items))))
          (setq items (cdr items)))
         ((eq kind 'STR)
          (setq opts  (fmt-option-set opts key (fmt-string-value (car items))))
          (setq items (cdr items)))
         (t                             ; ENUM
          (setq value (fmt-enum-value key (car items)))
          (if (null value)
            (fmt-error (strcat "valeur invalide pour l'option " name " : "
                               (fmt-name-of (car items)))
                       nil nil))
          (setq opts  (fmt-option-set opts key value))
          (setq items (cdr items)))))

      ;; nom d'option inconnu : erreur explicite plutôt que fichier fantôme
      (name
       (fmt-error (strcat "option inconnue : " name) nil nil))

      ;; argument positionnel
      (t
       (setq files (append files (list (fmt-string-value item)))))))
  (fmt-option-set opts "files" files))

;;; ------------------------------------------------------------------
;;; Fichier de configuration
;;; ------------------------------------------------------------------

;; Convertit un nœud CST en valeur AutoLISP ordinaire. Les commentaires et
;; les lignes blanches du fichier de configuration sont ignorés (la
;; spécification les prévoyait comme extension future : ils sont acceptés).
(defun fmt-node->value (node / kind)
  (setq kind (fmt-node-kind node))
  (cond
    ((eq kind 'STR)  (fmt-unescape-string (fmt-node-text node)))
    ((eq kind 'ATOM) (if (fmt-number-string-p (fmt-node-text node))
                       (if (vl-string-search "." (fmt-node-text node))
                         (atof (fmt-node-text node))
                         (atoi (fmt-node-text node)))
                       (read (fmt-node-text node))))
    ((eq kind 'LIST) (mapcar (function fmt-node->value)
                             (fmt-filter-code (fmt-node-children node))))
    ((eq kind 'QUOTE) (fmt-node->value (fmt-node-child node)))
    (t nil)))

(defun fmt-filter-code (nodes / out)
  (setq out nil)
  (foreach n nodes
    (if (fmt-node-code-p n)
      (setq out (cons n out))))
  (reverse out))

;; Retire les guillemets encadrants et interprète les échappements.
(defun fmt-unescape-string (text / codes out c)
  (setq codes (vl-string->list text))
  (if (and codes (= (car codes) *fmt-ch-dquote*))
    (setq codes (cdr codes)))
  (setq codes (reverse codes))
  (if (and codes (= (car codes) *fmt-ch-dquote*))
    (setq codes (cdr codes)))
  (setq codes (reverse codes))
  (setq out nil)
  (while codes
    (setq c (car codes))
    (setq codes (cdr codes))
    (if (and (= c *fmt-ch-backslash*) codes)
      (progn
        (setq c (car codes))
        (setq codes (cdr codes))
        (setq out (cons (cond ((= c 110) *fmt-ch-newline*)   ; \n
                              ((= c 116) *fmt-ch-tab*)       ; \t
                              ((= c 114) *fmt-ch-return*)    ; \r
                              (t         c))
                        out)))
      (setq out (cons c out))))
  (vl-list->string (reverse out)))

;; Lit un fichier de configuration et renvoie la liste des items à analyser.
;; Les deux formes prévues par la spécification sont acceptées : une seule
;; s-expression englobante, ou une suite d'items sans liste englobante.
(defun fmt-read-config-items (path / text nodes values)
  (setq text   (fmt-read-file path))
  (setq nodes  (fmt-filter-code (fmt-parse (fmt-scan text))))
  (setq values (mapcar (function fmt-node->value) nodes))
  (if (and values
           (= (length values) 1)
           (listp (car values)))
    (car values)
    values))

(defun fmt-load-config (path opts)
  (fmt-parse-args (fmt-read-config-items path) opts))

;;; ------------------------------------------------------------------
;;; Construction complète des options
;;; ------------------------------------------------------------------

;; ITEMS : options de l'appel courant. Si elles désignent un fichier de
;; configuration, celui-ci est chargé d'abord, puis recouvert par les
;; options explicites — ordre de priorité de la spécification.
(defun fmt-build-options (items / explicit opts config)
  (setq explicit (fmt-parse-args items (fmt-default-options)))
  (setq config   (fmt-option explicit "config"))
  (if config
    (progn
      (setq opts (fmt-load-config config (fmt-default-options)))
      ;; les fichiers du fichier de configuration sont conservés seulement
      ;; si l'appel courant n'en fournit aucun
      (setq opts (fmt-parse-args items (fmt-option-set opts "files" nil)))
      (if (null (fmt-option opts "files"))
        (setq opts (fmt-option-set opts "files"
                                   (fmt-option
                                     (fmt-load-config config (fmt-default-options))
                                     "files")))))
    (setq opts explicit))
  opts)

(princ)

;;; fmt-options.lsp ends here
