;;; autolisp-introspection.lsp --- Introspection des entités d'un dessin

(vl-load-com)

;;; Public API:
;;;   ei-snapshot ei-diff ei-added ei-deleted ei-modified
;;;   ei-rec-handle ei-rec-ename ei-rec-type ei-rec-dxf ei-rec-xdata
;;;   ei-entity-diff ei-attr-changes
;;;   ei-ac-code ei-ac-old ei-ac-new ei-ac-kind
;;;   ei-xdata-added ei-xdata-deleted ei-xdata-modified
;;;   ei-xd-app ei-xd-old ei-xd-new

(setq ei-*fuzz* 0.0)
(setq :changed ':changed)
(setq :added ':added)
(setq :deleted ':deleted)
(setq :multi ':multi)

(defun ei--make-rec (handle ename type dxf xdata)
  (list 'ei-rec handle ename type dxf xdata))

(defun ei-rec-handle (rec) (cadr rec))
(defun ei-rec-ename  (rec) (caddr rec))
(defun ei-rec-type   (rec) (cadddr rec))
(defun ei-rec-dxf    (rec) (car (cddddr rec)))
(defun ei-rec-xdata  (rec) (cadr (cddddr rec)))

(defun ei--make-diff (added deleted modified)
  (list 'ei-diff added deleted modified))

(defun ei-added    (diff) (cadr diff))
(defun ei-deleted  (diff) (caddr diff))
(defun ei-modified (diff) (cadddr diff))

(defun ei--make-ediff (before after attrs xa xd xm)
  (list 'ei-entity-diff before after attrs xa xd xm))

(defun ei--ed-before (ediff) (cadr ediff))
(defun ei--ed-after  (ediff) (caddr ediff))
(defun ei-attr-changes   (ediff) (cadddr ediff))
(defun ei-xdata-added    (ediff) (car (cddddr ediff)))
(defun ei-xdata-deleted  (ediff) (cadr (cddddr ediff)))
(defun ei-xdata-modified (ediff) (caddr (cddddr ediff)))

(defun ei--make-ac (code old new kind) (list 'ei-ac code old new kind))
(defun ei-ac-code (ac) (cadr ac))
(defun ei-ac-old  (ac) (caddr ac))
(defun ei-ac-new  (ac) (cadddr ac))
(defun ei-ac-kind (ac) (car (cddddr ac)))

(defun ei--make-xd (app old new) (list 'ei-xd app old new))
(defun ei-xd-app (xd) (cadr xd))
(defun ei-xd-old (xd) (caddr xd))
(defun ei-xd-new (xd) (cadddr xd))

(defun ei--ename-p (value)
  (eq (type value) 'ENAME))

(defun ei--ename-handle (ename / data)
  (setq data (entget ename))
  (if data (cdr (assoc 5 data)) ename))

(defun ei--normalize (value)
  (cond
    ((ei--ename-p value) (ei--ename-handle value))
    ((null value) nil)
    ((listp value)
     (cons (ei--normalize (car value))
           (ei--normalize (cdr value))))
    (t value)))

(defun ei--normalized-equal (left right)
  (cond
    ((and (numberp left) (numberp right))
     (equal left right ei-*fuzz*))
    ((and (listp left) (listp right))
     (cond
       ((and (null left) (null right)) t)
       ((or (null left) (null right)) nil)
       (t (and (ei--normalized-equal (car left) (car right))
               (ei--normalized-equal (cdr left) (cdr right))))))
    (t (equal left right))))

(defun ei--value-equal (left right)
  (ei--normalized-equal (ei--normalize left) (ei--normalize right)))

(defun ei--excluded-code-p (code)
  (or (= code -1) (= code -2) (= code 5) (= code -3)))

(defun ei--capture-xdata (data / result pair group)
  (setq result nil)
  (foreach pair data
    (if (= (car pair) -3)
      (foreach group (cdr pair)
        (setq result
              (append result
                      (list (cons (cons 1001 (car group))
                                  (cdr group))))))))
  result)

(defun ei--capture-dxf (data / result pair)
  (setq result nil)
  (foreach pair data
    (if (not (ei--excluded-code-p (car pair)))
      (setq result (append result (list pair)))))
  result)

(defun ei--capture (ename / data handle type)
  (setq data (entget ename '("*")))
  (setq handle (cdr (assoc 5 data)))
  (setq type (cdr (assoc 0 data)))
  (ei--make-rec handle ename type
                (ei--capture-dxf data)
                (ei--capture-xdata data)))

(defun ei--snapshot-all (/ result ename rec)
  (setq result nil)
  (setq ename (entnext))
  (while ename
    (setq rec (ei--capture ename))
    (if (ei-rec-handle rec)
      (setq result (cons (cons (ei-rec-handle rec) rec) result)))
    (setq ename (entnext ename)))
  (reverse result))

(defun ei--selection-set-p (scope)
  (= (type scope) 'PICKSET))

(defun ei--snapshot-scope (scope / result index ename rec)
  (setq result nil)
  (cond
    ((or (null scope) (eq scope 'all))
     (ei--snapshot-all))
    ((ei--selection-set-p scope)
     (setq index 0)
     (while (< index (sslength scope))
       (setq ename (ssname scope index))
       (setq rec (ei--capture ename))
       (setq result (cons (cons (ei-rec-handle rec) rec) result))
       (setq index (1+ index)))
     (reverse result))
    ((listp scope)
     (foreach ename scope
       (setq rec (ei--capture ename))
       (setq result (cons (cons (ei-rec-handle rec) rec) result)))
     (reverse result))
    (t (error "ei-snapshot: portée invalide"))))

(defun ei-snapshot (scope)
  (ei--snapshot-scope scope))

(defun ei--codes (dxf / codes pair)
  (setq codes nil)
  (foreach pair dxf
    (if (not (member (car pair) codes))
      (setq codes (append codes (list (car pair))))))
  codes)

(defun ei--values-for-code (dxf code / values pair)
  (setq values nil)
  (foreach pair dxf
    (if (= code (car pair))
      (setq values (append values (list (cdr pair))))))
  values)

(defun ei--single-or-list (values)
  (if (= (length values) 1) (car values) values))

(defun ei--attr-changes (before after / codes code old new result kind)
  (setq codes (ei--codes (append before after)))
  (setq result nil)
  (foreach code codes
    (setq old (ei--values-for-code before code))
    (setq new (ei--values-for-code after code))
    (if (not (ei--value-equal old new))
      (progn
        (setq kind
              (cond ((null old) :added)
                    ((null new) :deleted)
                    ((or (> (length old) 1) (> (length new) 1)) :multi)
                    (t :changed)))
        (setq result
              (append result
                      (list (ei--make-ac code
                                        (if old (ei--single-or-list old) nil)
                                        (if new (ei--single-or-list new) nil)
                                        kind)))))))
  result)

(defun ei--xdata-app (entry) (cdr (assoc 1001 entry)))
(defun ei--xdata-values (entry) entry)

(defun ei--xdata-apps (xdata / result entry)
  (setq result nil)
  (foreach entry xdata
    (if (not (member (ei--xdata-app entry) result))
      (setq result (append result (list (ei--xdata-app entry))))))
  result)

(defun ei--xdata-find (xdata app / found entry)
  (setq found nil)
  (foreach entry xdata
    (if (= app (ei--xdata-app entry)) (setq found entry)))
  found)

(defun ei--xdata-changes (before after / apps app old new added deleted modified)
  (setq apps (ei--xdata-apps (append before after)))
  (setq added nil deleted nil modified nil)
  (foreach app apps
    (setq old (ei--xdata-find before app))
    (setq new (ei--xdata-find after app))
    (cond
      ((null old)
       (setq added (append added (list (ei--make-xd app nil new)))))
      ((null new)
       (setq deleted (append deleted (list (ei--make-xd app old nil)))))
      ((not (ei--value-equal old new))
       (setq modified (append modified (list (ei--make-xd app old new)))))))
  (list added deleted modified))

(defun ei-entity-diff (before after / attrs xchanges)
  (if (/= (ei-rec-handle before) (ei-rec-handle after))
    (error "ei-entity-diff: les handles diffèrent"))
  (setq attrs (ei--attr-changes (ei-rec-dxf before) (ei-rec-dxf after)))
  (setq xchanges (ei--xdata-changes (ei-rec-xdata before) (ei-rec-xdata after)))
  (ei--make-ediff before after attrs
                   (car xchanges) (cadr xchanges) (caddr xchanges)))

(defun ei--records-differ-p (before after / ediff)
  (setq ediff (ei-entity-diff before after))
  (or (ei-attr-changes ediff)
      (ei-xdata-added ediff)
      (ei-xdata-deleted ediff)
      (ei-xdata-modified ediff)))

(defun ei-diff (before after / added deleted modified cell old new)
  (setq added nil deleted nil modified nil)
  (foreach cell after
    (setq old (assoc (car cell) before))
    (if old
      (if (ei--records-differ-p (cdr old) (cdr cell))
        (setq modified (append modified (list (cons (cdr old) (cdr cell))))))
      (setq added (append added (list (cdr cell))))))
  (foreach cell before
    (setq new (assoc (car cell) after))
    (if (null new)
      (setq deleted (append deleted (list (cdr cell))))))
  (ei--make-diff added deleted modified))

(princ)
