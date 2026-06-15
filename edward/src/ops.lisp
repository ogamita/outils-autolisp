(in-package #:edward)

;;;; Operations on selections — delete / duplicate / insert / edit, plus DXF
;;;; write-back. All mutate the in-memory drawing through the clautolisp API;
;;;; output is DXF only (the libredwg R2018 encoder is unavailable). The unit
;;;; of mutation is a whole :entity or :object (MUTATION-TARGET); EDIT routes
;;;; through the structured sexp editor (sedit.lisp).

(defun mutation-pairs (node)
  "The live DXF pair list of NODE's mutation target (:entity or :object)."
  (multiple-value-bind (kind handle) (mutation-target node)
    (ecase kind
      (:entity (dwg:entity-dxf (dwg:find-entity (node-drawing node) handle)))
      (:object (dwg:find-object (node-drawing node) handle)))))

(defun write-back-pairs (node new-pairs)
  "Replace NODE's mutation target with NEW-PAIRS (the single edit chokepoint;
clautolisp re-injects the handle, so do not double-inject code 5/-1)."
  (multiple-value-bind (kind handle) (mutation-target node)
    (ecase kind
      (:entity (dwg:modify-entity (node-drawing node) handle new-pairs))
      (:object (progn (dwg:remove-object (node-drawing node) handle)
                      (dwg:add-object (node-drawing node) handle new-pairs))))
    (values kind handle)))

(defun edit-entity-pairs (node fn)
  "Apply FN (pair-list -> pair-list) to NODE's mutation target and write the
result back. Returns the new pair list."
  (let ((new (funcall fn (copy-tree (mutation-pairs node)))))
    (write-back-pairs node new)
    new))

(defun edit (node)
  "Interactively edit NODE's mutation target with the structured sexp editor,
then write it back into the in-memory drawing. Returns NODE."
  (let ((n (if (node-p node) node (first-of node))))
    (multiple-value-bind (kind handle) (mutation-target n)
      (unless (member kind '(:entity :object))
        (error "edit: no editable entity/object owns this node"))
      (let ((edited (edit-sexp (copy-tree (mutation-pairs n)))))
        (write-back-pairs n edited)
        (format t "~&;; wrote ~(~A~) #~A~%" kind handle))
      n)))

(defun del (selection)
  "Delete the nodes of SELECTION: entities are marked deleted; objects are
removed; dict-entries are unlinked from their dictionary. Returns the count."
  (let ((n 0))
    (dolist (node (%as-selection selection))
      (case (node-level node)
        (:entity (dwg:set-entity-deleted-status
                  (node-drawing node) (dwg:entity-handle-string (node-payload node)) t)
                 (incf n))
        (:object (when (dwg:remove-object (node-drawing node) (car (node-payload node)))
                   (incf n)))
        (:dict-entry (let ((parent (node-parent node)))
                       (when (and parent (eq (node-level parent) :dict))
                         (dwg:dictionary-remove (node-payload parent) (car (node-payload node)))
                         (incf n))))
        (otherwise nil)))
    (format t "~&;; deleted ~A element(s)~%" n)
    n))

(defun dup (selection)
  "Duplicate the entity/object nodes of SELECTION within the same drawing,
with freshly-allocated handles. Returns a selection of the new nodes."
  (let ((out '()))
    (dolist (node (%as-selection selection))
      (let ((d (node-drawing node)))
        (case (node-level node)
          (:entity
           (let* ((e (node-payload node))
                  (ne (dwg:add-entity d (copy-tree (dwg:entity-dxf e))
                                      :handle (dwg:allocate-handle d)
                                      :block (dwg:entity-handle-block e))))
             (push (mk-node :entity ne :drawing d
                            :index (dwg:entity-handle-string ne)) out)))
          (:object
           (let* ((p (node-payload node))
                  (h (%hex (dwg:allocate-handle d)))
                  (owner (or (dxf-assoc 330 (cdr p)) h))
                  (data (%xrecord-rehandle (cdr p) h owner)))
             (dwg:add-object d h data)
             (push (mk-node :object (cons h data) :drawing d :index h
                            :codec *xrecord-codec*) out)))
          (otherwise nil))))
    (let ((new (nreverse out)))
      (format t "~&;; duplicated ~A element(s)~%" (length new))
      new)))

(defun ins (dxf &key (drawing *drawing*) block)
  "Insert a new entity from the DXF pair list (must contain (0 . \"TYPE\")).
Returns its node."
  (let ((e (dwg:add-entity drawing dxf :block block)))
    (mk-node :entity e :drawing drawing :index (dwg:entity-handle-string e))))

(defun save (path &optional (drawing *drawing*))
  "Write DRAWING (default *drawing*) to PATH as ASCII DXF (UTF-8). Native DWG
output is refused — the libredwg R2018 encoder is unavailable."
  (let ((type (string-downcase (or (pathname-type (pathname path)) "dxf"))))
    (unless (string= type "dxf")
      (error "edward writes DXF only (libredwg R2018 encoder unavailable); use a .dxf path"))
    (dwg:dxf-write-drawing drawing path :external-format :utf-8)
    (format t "~&;; wrote ~A~%" path)
    path))
