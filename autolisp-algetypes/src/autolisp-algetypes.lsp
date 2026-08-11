;;; autolisp-algetypes.lsp --- Petits types algébriques pour AutoLISP

;;; Une valeur est représentée par :
;;;   (al-value TYPE VARIANTE (CHAMPS...))
;;; Les schémas de types sont conservés dans al-*types*.

(setq al-*types* nil)

(defun al--error (al-message)
  (error (strcat "autolisp-algetypes: " al-message)))

(defun al--symbol-p (al-value)
  (= (type al-value) 'SYM))

(defun al--proper-list-p (al-value / al-rest)
  (setq al-rest al-value)
  (while (and al-rest (= (type al-rest) 'LIST))
    (setq al-rest (cdr al-rest)))
  (null al-rest))

(defun al--member-eq (al-item al-items / al-found)
  (setq al-found nil)
  (while (and al-items (not al-found))
    (if (eq al-item (car al-items))
      (setq al-found T))
    (setq al-items (cdr al-items)))
  al-found)

(defun al--validate-fields (al-fields / al-seen)
  (if (not (al--proper-list-p al-fields))
    (al--error "la liste de champs est incorrecte"))
  (setq al-seen nil)
  (foreach al-field al-fields
    (if (not (al--symbol-p al-field))
      (al--error "un nom de champ doit être un symbole"))
    (if (al--member-eq al-field al-seen)
      (al--error "les noms de champs doivent être distincts"))
    (setq al-seen (cons al-field al-seen)))
  al-fields)

(defun al--validate-variants (al-variants / al-seen al-variant)
  (if (or (null al-variants) (not (al--proper-list-p al-variants)))
    (al--error "un type doit posséder au moins une variante"))
  (setq al-seen nil)
  (foreach al-spec al-variants
    (if (or (not (al--proper-list-p al-spec))
            (/= (length al-spec) 2))
      (al--error "une variante doit avoir la forme (nom (champs...))"))
    (setq al-variant (car al-spec))
    (if (not (al--symbol-p al-variant))
      (al--error "un nom de variante doit être un symbole"))
    (if (al--member-eq al-variant al-seen)
      (al--error "les noms de variantes doivent être distincts"))
    (al--validate-fields (cadr al-spec))
    (setq al-seen (cons al-variant al-seen)))
  al-variants)

(defun al-define-type (al-type al-variants / al-old)
  "Déclare TYPE à partir de ((VARIANTE (CHAMPS...)) ...)."
  (if (not (al--symbol-p al-type))
    (al--error "le nom du type doit être un symbole"))
  (al--validate-variants al-variants)
  (setq al-old (assoc al-type al-*types*))
  (if al-old
    (setq al-*types* (subst (cons al-type al-variants) al-old al-*types*))
    (setq al-*types* (cons (cons al-type al-variants) al-*types*)))
  al-type)

(defun al-type-defined-p (al-type)
  (not (null (assoc al-type al-*types*))))

(defun al-construct (al-type al-variant al-values / al-type-spec al-variant-spec)
  "Construit une valeur de TYPE et de VARIANTE avec AL-VALUES."
  (setq al-type-spec (assoc al-type al-*types*))
  (if (null al-type-spec)
    (al--error "type inconnu"))
  (setq al-variant-spec (assoc al-variant (cdr al-type-spec)))
  (if (null al-variant-spec)
    (al--error "variante inconnue pour ce type"))
  (if (not (al--proper-list-p al-values))
    (al--error "les valeurs des champs doivent former une liste"))
  (if (/= (length al-values) (length (cadr al-variant-spec)))
    (al--error "nombre de champs incorrect"))
  (list 'al-value al-type al-variant al-values))

(defun al-value-p (al-value)
  (and (al--proper-list-p al-value)
       (= (length al-value) 4)
       (eq (car al-value) 'al-value)
       (al-type-defined-p (cadr al-value))
       (not (null (assoc (caddr al-value)
                         (cdr (assoc (cadr al-value) al-*types*)))))
       (= (length (cadddr al-value))
          (length (cadr (assoc (caddr al-value)
                               (cdr (assoc (cadr al-value) al-*types*))))))))

(defun al--require-value (al-value)
  (if (not (al-value-p al-value))
    (al--error "valeur algébrique attendue"))
  al-value)

(defun al--require-type (al-value al-type)
  (al--require-value al-value)
  (if (not (eq (cadr al-value) al-type))
    (al--error (strcat "valeur de type "
                       (vl-symbol-name al-type)
                       " attendue")))
  al-value)

(defun al-type-of (al-value)
  (al--require-value al-value)
  (cadr al-value))

(defun al-variant-of (al-value)
  (al--require-value al-value)
  (caddr al-value))

(defun al-values (al-value)
  (al--require-value al-value)
  (cadddr al-value))

(defun al-is-p (al-value al-type al-variant)
  (and (al-value-p al-value)
       (eq (al-type-of al-value) al-type)
       (eq (al-variant-of al-value) al-variant)))

(defun al--field-index (al-field al-fields / al-index al-found)
  (setq al-index 0)
  (setq al-found nil)
  (while (and al-fields (null al-found))
    (if (eq al-field (car al-fields))
      (setq al-found al-index)
      (setq al-index (1+ al-index)))
    (setq al-fields (cdr al-fields)))
  al-found)

(defun al-field (al-value al-field / al-fields al-index)
  "Retourne le champ nommé AL-FIELD de AL-VALUE."
  (al--require-value al-value)
  (setq al-fields
        (cadr (assoc (al-variant-of al-value)
                     (cdr (assoc (al-type-of al-value) al-*types*)))))
  (setq al-index (al--field-index al-field al-fields))
  (if (null al-index)
    (al--error "champ inconnu pour cette variante"))
  (nth al-index (al-values al-value)))

(defun al--match-exhaustive-p (al-type-spec al-cases / al-ok)
  (setq al-ok T)
  (foreach al-variant-spec (cdr al-type-spec)
    (if (null (assoc (car al-variant-spec) al-cases))
      (setq al-ok nil)))
  al-ok)

(defun al-match (al-value al-cases / al-type-spec al-case)
  "Filtre AL-VALUE avec ((VARIANTE . FONCTION) ...)."
  (al--require-value al-value)
  (setq al-type-spec (assoc (al-type-of al-value) al-*types*))
  (if (not (al--proper-list-p al-cases))
    (al--error "les cas doivent former une liste"))
  (if (and (null (assoc 'otherwise al-cases))
           (not (al--match-exhaustive-p al-type-spec al-cases)))
    (al--error "filtrage non exhaustif"))
  (setq al-case (assoc (al-variant-of al-value) al-cases))
  (if (null al-case)
    (setq al-case (assoc 'otherwise al-cases)))
  (if (null al-case)
    (al--error "aucun cas applicable"))
  (apply (cdr al-case) (al-values al-value)))

;;; Types usuels.

(al-define-type 'option '((some (value)) (none ())))
(al-define-type 'result '((ok (value)) (error (reason))))

(defun al-some (al-value) (al-construct 'option 'some (list al-value)))
(defun al-none () (al-construct 'option 'none nil))
(defun al-ok (al-value) (al-construct 'result 'ok (list al-value)))
(defun al-error (al-reason) (al-construct 'result 'error (list al-reason)))

(defun al-option-map (al-function al-option)
  (al--require-type al-option 'option)
  (if (al-is-p al-option 'option 'some)
    (al-some (apply al-function (al-values al-option)))
    al-option))

(defun al-option-bind (al-function al-option / al-result)
  (al--require-type al-option 'option)
  (if (al-is-p al-option 'option 'some)
    (progn
      (setq al-result (apply al-function (al-values al-option)))
      (if (not (and (al-value-p al-result)
                    (eq (al-type-of al-result) 'option)))
        (al--error "option-bind attend une fonction retournant une option"))
      al-result)
    al-option))

(defun al-result-map (al-function al-result)
  (al--require-type al-result 'result)
  (if (al-is-p al-result 'result 'ok)
    (al-ok (apply al-function (al-values al-result)))
    al-result))

(defun al-result-bind (al-function al-result / al-next)
  (al--require-type al-result 'result)
  (if (al-is-p al-result 'result 'ok)
    (progn
      (setq al-next (apply al-function (al-values al-result)))
      (if (not (and (al-value-p al-next)
                    (eq (al-type-of al-next) 'result)))
        (al--error "result-bind attend une fonction retournant un résultat"))
      al-next)
    al-result))

(princ "")
