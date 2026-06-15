(in-package #:edward)

;;;; The explorer node model — a uniform handle on any element of a drawing,
;;;; at any level, for the interactive explorer (§ explorer specification).
;;;;
;;;; A NODE tags a level keyword, the underlying clautolisp/edward value
;;;; (payload), the parent node, the owning drawing, and the node's index/key
;;;; within its parent (for paths and locators). Children are produced lazily
;;;; by NODE-CHILDREN, reusing the existing parse/decode functions — no new
;;;; parsing lives here.
;;;;
;;;; Levels and payloads:
;;;;   :drawing       the clautolisp DRAWING
;;;;   :entity        an ENTITY-HANDLE
;;;;   :object        (handle-string . data-list)        a NOD object (XRECORD…)
;;;;   :table-record  a SYMBOL-TABLE-RECORD
;;;;   :dict          a DICTIONARY
;;;;   :dict-entry    (key . value)                       value: DICTIONARY |
;;;;                                                       handle-string | ENTITY-HANDLE
;;;;   :header-var    a SYSVAR-CELL
;;;;   :pair          a (code . value) DXF entry
;;;;   :block         (:block inner-pairs)                a decoded brace block
;;;;   :xdata-group   (appid . pairs)                     entity xdata for one appid
;;;;   :instance      (:class :version :fields) + codec   a decoded SCHMS instance
;;;;   :field         (name . value)                      one instance field
;;;;
;;;; Mutation is always rooted at the nearest :entity or :object ancestor (the
;;;; only units clautolisp can replace); MUTATION-TARGET climbs to it.

(defvar *drawing* nil
  "The drawing the REPL / explorer is currently working on.")
(defvar *sel* nil
  "The current selection (a list of NODEs) in the REPL.")

(defstruct (node (:constructor %make-node) (:conc-name node-))
  level
  payload
  (parent nil)
  drawing
  (index nil)   ; this node's key/index within its parent (for paths)
  (codec nil))  ; for :xdata-group/:object/:instance: which xcodec decodes it

(defun mk-node (level payload &key parent drawing index codec)
  "Construct a NODE, inheriting DRAWING and CODEC from PARENT when omitted."
  (%make-node :level level :payload payload :parent parent :index index
              :drawing (or drawing (and parent (node-drawing parent)))
              :codec   (or codec  (and parent (node-codec parent)))))

(defun %as-selection (x)
  "Coerce X (a NODE or a list of NODEs) to a selection (list of NODEs)."
  (cond ((node-p x) (list x))
        ((listp x)  x)
        (t (error "Not a node or selection: ~S" x))))

(defparameter *table-kinds*
  '(:appid :block_record :dimstyle :layer :ltype :style :ucs :view :vport)
  "The standard symbol-table kinds enumerated by TABLE-RECORDS.")

;;;; --- roots: drawing -> selection -------------------------------------

(defun drawing-node (drawing)
  "The single :drawing root node for DRAWING."
  (mk-node :drawing drawing :drawing drawing))

(defun entities (drawing &key include-deleted)
  "Selection of every entity (model space and blocks)."
  (let ((acc '()))
    (dwg:map-entities (lambda (e) (push e acc)) drawing :include-deleted include-deleted)
    (mapcar (lambda (e) (mk-node :entity e :drawing drawing
                                 :index (dwg:entity-handle-string e)))
            (nreverse acc))))

(defun objects (drawing)
  "Selection of every non-graphical NOD object (XRECORDs etc.)."
  (let ((acc '()))
    (dwg:map-objects (lambda (h d) (push (cons h d) acc)) drawing)
    (mapcar (lambda (hd) (mk-node :object hd :drawing drawing :index (car hd)
                                  :codec *xrecord-codec*))
            (nreverse acc))))

(defun table-records (drawing &optional kind)
  "Selection of symbol-table records; KIND (a keyword) restricts to one table,
NIL enumerates all of *TABLE-KINDS*."
  (let ((acc '()))
    (dolist (k (if kind (list kind) *table-kinds*))
      (dwg:map-table-records (lambda (r) (push r acc)) drawing k))
    (mapcar (lambda (r) (mk-node :table-record r :drawing drawing
                                 :index (dwg:symbol-table-record-name r)))
            (nreverse acc))))

(defun dictionaries (drawing)
  "Selection holding the root named-object dictionary (descend with CHILDREN)."
  (list (mk-node :dict (dwg:drawing-dictionary drawing) :drawing drawing :index "NOD")))

(defun header-vars (drawing)
  "Selection of every header (system) variable cell."
  (let ((acc '()))
    (dwg:map-variables (lambda (c) (push c acc)) drawing)
    (mapcar (lambda (c) (mk-node :header-var c :drawing drawing
                                 :index (dwg:sysvar-cell-name c)))
            (nreverse acc))))

;;;; --- children: node -> child nodes -----------------------------------

(defun %first-xdata-index (data)
  "Index of the first (1001 . _) xdata marker in DATA, or NIL."
  (position-if (lambda (p) (and (consp p) (eql (car p) 1001))) data))

(defun %pair-nodes (pairs parent &key (from 0) (to nil))
  "Wrap the (code . value) entries of PAIRS[FROM:TO] as :pair child nodes of
PARENT, indexed by their position in PAIRS."
  (loop for p in (subseq pairs from to)
        for i from from
        when (consp p)
          collect (mk-node :pair p :parent parent :index i)))

(defun %instance-nodes (pairs parent codec)
  "Decode PAIRS with CODEC and wrap each instance as an :instance child node."
  (loop for inst in (decode-instance-stream pairs codec)
        for n from 0
        collect (mk-node :instance inst :parent parent :index n :codec codec)))

(defun node-children (node)
  "The immediate child NODEs of NODE (level-aware; empty for leaves)."
  (let ((p (node-payload node)))
    (case (node-level node)
      (:drawing
       (let ((d p))
         (append (entities d) (objects d) (dictionaries d)
                 (table-records d) (header-vars d))))
      (:entity
       (let* ((data (dwg:entity-dxf p))
              (xstart (%first-xdata-index data)))
         (append (%pair-nodes data node :to xstart)
                 (loop for g in (entity-xdata p)
                       collect (mk-node :xdata-group g :parent node
                                        :index (car g) :codec *xdata-codec*)))))
      (:object
       (let ((data (cdr p)))
         (append (%pair-nodes data node)
                 (let ((stream (xrecord-instance-pairs data)))
                   (and stream (%instance-nodes stream node *xrecord-codec*))))))
      (:xdata-group
       (let ((pairs (cdr p)))
         (append (%pair-nodes pairs node)
                 (%instance-nodes pairs node (node-codec node)))))
      (:instance
       (loop for kv in (getf p :fields)
             collect (mk-node :field kv :parent node :index (car kv))))
      (:field
       (let ((v (cdr p)))
         (when (and (consp v) (eq (car v) :block))
           (%pair-nodes (second v) node))))
      (:block
       (%pair-nodes (second p) node))
      (:dict
       (let ((acc '()))
         (dwg:map-dictionary (lambda (k v) (push (cons k v) acc)) p)
         (nreverse
          (mapcar (lambda (kv) (mk-node :dict-entry kv :parent node :index (car kv)))
                  (nreverse acc)))))
      (:dict-entry
       (let ((v (cdr p)))
         (cond
           ((dwg:dictionary-p v) (list (mk-node :dict v :parent node :index (car p))))
           ((stringp v)
            (let ((obj (dwg:find-object (node-drawing node) v)))
              (when obj (list (mk-node :object (cons v obj) :parent node
                                       :index v :codec *xrecord-codec*)))))
           ((dwg:entity-handle-p v)
            (list (mk-node :entity v :parent node
                           :index (dwg:entity-handle-string v))))
           (t nil))))
      (:table-record
       (%pair-nodes (dwg:symbol-table-record-data p) node))
      (otherwise nil))))

;;;; --- navigation ------------------------------------------------------

(defun children (selection)
  "All child nodes of every node in SELECTION (a node or selection)."
  (mapcan #'node-children (%as-selection selection)))

(defun descendants (selection &key (depth 16))
  "SELECTION plus all transitive children, depth-first, bounded by DEPTH."
  (labels ((walk (nodes d)
             (when (and nodes (plusp d))
               (mapcan (lambda (n) (cons n (walk (node-children n) (1- d))))
                       nodes))))
    (walk (%as-selection selection) depth)))

(defun parent-of (selection)
  "The parent nodes of SELECTION (duplicates removed, NILs dropped)."
  (remove-duplicates (remove nil (mapcar #'node-parent (%as-selection selection)))))

(defun ascend-to (selection level)
  "For each node in SELECTION, its nearest self-or-ancestor at LEVEL, or NIL."
  (remove nil
          (mapcar (lambda (n)
                    (loop for c = n then (node-parent c)
                          while c
                          when (eq (node-level c) level) return c))
                  (%as-selection selection))))

;;;; --- mutation rooting ------------------------------------------------

(defun mutation-target (node)
  "Climb NODE's ancestry to the nearest mutable unit and return
(values level handle), where LEVEL is :entity or :object and HANDLE its hex
string; or (values level nil) for a self-mutable :table-record / :dict /
:dict-entry / :header-var; or (values nil nil) when nothing applies."
  (loop for n = node then (node-parent n)
        while n
        do (case (node-level n)
             (:entity (return (values :entity (dwg:entity-handle-string (node-payload n)))))
             (:object (return (values :object (car (node-payload n)))))
             ((:table-record :dict :dict-entry :header-var)
              (return (values (node-level n) (node-index n))))
             (otherwise nil))
        finally (return (values nil nil))))

;;;; --- locator / path (best-effort, for display & re-selection) --------

(defun node-path (node)
  "A root-first list of (level . index) steps locating NODE, for display."
  (loop for n = node then (node-parent n)
        while n
        collect (cons (node-level n) (node-index n)) into steps
        finally (return (nreverse steps))))

(defun node-path-string (node)
  "A compact slash path of NODE for one-line display, e.g.
entity:2F0/xdata:SCHMSPLUS/instance:0/field:UUID."
  (format nil "~{~A~^/~}"
          (mapcar (lambda (step)
                    (if (cdr step)
                        (format nil "~(~A~):~A" (car step) (cdr step))
                        (format nil "~(~A~)" (car step))))
                  (node-path node))))
