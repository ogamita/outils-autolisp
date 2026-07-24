;;; test-entites.lsp --- Assertions sur les mutations d'entités

(defun t:entity-handles (records / result rec)
  (setq result nil)
  (foreach rec records
    (setq result (append result (list (ei-rec-handle rec)))))
  result)

(defun t:message (message fallback)
  (if message message fallback))

(defun attendu (condition message) (is condition message))
(defun attendu-non (condition message) (is-not condition message))
(defun attendu-egal (expected actual message)
  (is-equal expected actual message))

(defun t:assert-count (label expected actual message)
  (if (/= expected actual)
    (t:fail (t:message message (t:format-compare label expected actual))))
  t)

(defun attendu-aucune-creation (diff message)
  (if (ei-added diff)
    (t:fail (t:message message
             (strcat "créations inattendues: "
                     (t:str (t:entity-handles (ei-added diff)))))))
  t)

(defun attendu-aucune-suppression (diff message)
  (if (ei-deleted diff)
    (t:fail (t:message message
             (strcat "suppressions inattendues: "
                     (t:str (t:entity-handles (ei-deleted diff)))))))
  t)

(defun attendu-creees (diff count message)
  (t:assert-count "entités créées:" count (length (ei-added diff)) message))
(defun attendu-supprimees (diff count message)
  (t:assert-count "entités supprimées:" count (length (ei-deleted diff)) message))
(defun attendu-modifiees (diff count message)
  (t:assert-count "entités modifiées:" count (length (ei-modified diff)) message))

(defun modif-entite (diff handle / found pair)
  (setq found nil)
  (foreach pair (ei-modified diff)
    (if (= handle (ei-rec-handle (car pair)))
      (setq found (ei-entity-diff (car pair) (cdr pair)))))
  (if (null found)
    (t:fail (strcat "entité modifiée absente: " handle)))
  found)

(defun modif-unique (diff / modified)
  (setq modified (ei-modified diff))
  (if (/= 1 (length modified))
    (t:fail (t:format-compare "modif-unique:" 1 (length modified))))
  (ei-entity-diff (caar modified) (cdar modified)))

(defun t:find-ac (ediff code / found ac)
  (setq found nil)
  (foreach ac (ei-attr-changes ediff)
    (if (= code (ei-ac-code ac)) (setq found ac)))
  found)

(defun attendu-attribut-modifie (ediff code old new message / ac)
  (setq ac (t:find-ac ediff code))
  (if (or (null ac)
          (not (ei--value-equal old (ei-ac-old ac)))
          (not (ei--value-equal new (ei-ac-new ac))))
    (t:fail
      (t:message message
        (t:format-compare
          (strcat "attribut " (itoa code) ":")
          (list old new)
          (if ac (list (ei-ac-old ac) (ei-ac-new ac)) nil)))))
  t)

(defun attendu-attribut-inchange (ediff code message)
  (if (t:find-ac ediff code)
    (t:fail (t:message message
             (strcat "attribut modifié: " (itoa code)))))
  t)

(defun attendu-attribut-valeur (ediff code new message / ac)
  (setq ac (t:find-ac ediff code))
  (if (or (null ac) (not (ei--value-equal new (ei-ac-new ac))))
    (t:fail (t:message message
             (t:format-compare (strcat "attribut " (itoa code) ":")
                              new (if ac (ei-ac-new ac) nil)))))
  t)

(defun t:find-xd (changes app / found xd)
  (setq found nil)
  (foreach xd changes
    (if (= app (ei-xd-app xd)) (setq found xd)))
  found)

(defun attendu-xdata-ajoutee (ediff app values message / xd)
  (setq xd (t:find-xd (ei-xdata-added ediff) app))
  (if (or (null xd)
          (and values (not (ei--value-equal values (ei-xd-new xd)))))
    (t:fail (t:message message
             (t:format-compare (strcat "xdata ajoutée " app ":")
                              (if values values app)
                              (if xd (ei-xd-new xd) nil)))))
  t)

(defun attendu-xdata-supprimee (ediff app message)
  (if (null (t:find-xd (ei-xdata-deleted ediff) app))
    (t:fail (t:message message (strcat "xdata supprimée absente: " app))))
  t)

(defun attendu-xdata-modifiee (ediff app old new message / xd)
  (setq xd (t:find-xd (ei-xdata-modified ediff) app))
  (if (or (null xd)
          (not (ei--value-equal old (ei-xd-old xd)))
          (not (ei--value-equal new (ei-xd-new xd))))
    (t:fail (t:message message
             (t:format-compare (strcat "xdata modifiée " app ":")
                              (list old new)
                              (if xd (list (ei-xd-old xd) (ei-xd-new xd)) nil)))))
  t)

(defun attendu-xdata-valeur (ediff app new message / xd)
  (setq xd (t:find-xd (append (ei-xdata-added ediff)
                              (ei-xdata-modified ediff)) app))
  (if (or (null xd) (not (ei--value-equal new (ei-xd-new xd))))
    (t:fail (t:message message
             (t:format-compare (strcat "xdata valeur " app ":")
                              new (if xd (ei-xd-new xd) nil)))))
  t)

(defun attendu-aucune-xdata-changee (ediff message)
  (if (or (ei-xdata-added ediff)
          (ei-xdata-deleted ediff)
          (ei-xdata-modified ediff))
    (t:fail (t:message message "des xdata ont changé")))
  t)

(princ)
