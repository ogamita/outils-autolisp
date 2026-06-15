(in-package #:edward)

;;;; The query language — composable selectors over the node model.
;;;;
;;;; A selection is a plain list of NODEs, so the whole CL sequence library
;;;; composes for free. Roots (ENTITIES, OBJECTS, …) and navigators (CHILDREN,
;;;; DESCENDANTS, PARENT-OF, ASCEND-TO) live in node.lisp; this file adds the
;;;; filters (all built on WHERE) and terminals. The query "language" is just
;;;; Lisp: nest the combinators, or thread them with CHAIN.

;;;; --- filters ---------------------------------------------------------

(defun where (selection predicate)
  "The nodes of SELECTION for which (PREDICATE node) is true."
  (remove-if-not predicate (%as-selection selection)))

(defun %level (node &rest levels)
  (member (node-level node) levels))

(defun %hexeq (a b)
  "True if handle designators A and B denote the same handle."
  (and a b (ignore-errors (= (dwg:handle->integer a) (dwg:handle->integer b)))))

(defun node-handle (node)
  "The hex handle string of an :entity or :object NODE, else NIL."
  (case (node-level node)
    (:entity (dwg:entity-handle-string (node-payload node)))
    (:object (car (node-payload node)))
    (otherwise nil)))

(defun by-handle (selection handle)
  "Keep the :entity/:object nodes whose handle is HANDLE (hex string or int)."
  (where selection (lambda (n) (%hexeq (node-handle n) handle))))

(defun by-kind (selection kind)
  "Keep the :entity nodes of entity-kind KIND (a keyword or its name)."
  (let ((k (if (stringp kind) (intern (string-upcase kind) :keyword) kind)))
    (where selection (lambda (n) (and (%level n :entity)
                                      (eq (dwg:entity-kind (node-payload n)) k))))))

(defun by-layer (selection layer)
  "Keep the :entity nodes on layer LAYER (string-equal)."
  (where selection (lambda (n) (and (%level n :entity)
                                    (let ((l (dxf-assoc 8 (dwg:entity-dxf (node-payload n)))))
                                      (and l (string-equal l layer)))))))

(defun %entity-has-appid (entity appid)
  (member appid (entity-xdata entity) :key #'car :test #'string-equal))

(defun by-appid (selection appid)
  "Keep nodes belonging to APPID: :xdata-group nodes for APPID, and :entity
nodes that carry an APPID xdata group."
  (where selection
         (lambda (n)
           (case (node-level n)
             (:xdata-group (string-equal (car (node-payload n)) appid))
             (:entity (%entity-has-appid (node-payload n) appid))
             (otherwise nil)))))

(defun by-code (selection code)
  "Keep the :pair nodes whose group code is CODE."
  (where selection (lambda (n) (and (%level n :pair)
                                    (eql (car (node-payload n)) code)))))

(defun by-class (selection class)
  "Keep the :instance nodes of SCHMS class CLASS (string-equal)."
  (where selection (lambda (n) (and (%level n :instance)
                                    (let ((c (getf (node-payload n) :class)))
                                      (and c (string-equal c class)))))))

(defun by-version (selection version)
  "Keep the :instance nodes of schema version VERSION."
  (where selection (lambda (n) (and (%level n :instance)
                                    (eql (getf (node-payload n) :version) version)))))

(defun by-level (selection level)
  "Keep the nodes at LEVEL."
  (where selection (lambda (n) (eq (node-level n) level))))

;;;; --- pickers & terminals ---------------------------------------------

(defun pick (selection n)
  "A one-node selection holding the Nth node of SELECTION, or NIL."
  (let ((s (%as-selection selection)))
    (and (< -1 n (length s)) (list (nth n s)))))

(defun first-of (selection)
  "The first node of SELECTION, or NIL (a bare node, not a selection)."
  (car (%as-selection selection)))

(defun count-of (selection)
  "The number of nodes in SELECTION."
  (length (%as-selection selection)))

(defun to-list (selection)
  "SELECTION as a plain list of NODEs (identity for a list, wraps a node)."
  (%as-selection selection))

;;;; --- threading sugar -------------------------------------------------

(defmacro chain (x &rest forms)
  "Thread X through FORMS, inserting the prior result as each form's LAST
argument: (chain d (entities) (by-layer \"X\") (by-appid \"SCHMSPLUS\")
descendants). A bare symbol FORM is called as (FORM acc)."
  (reduce (lambda (acc form)
            (if (consp form) (append form (list acc)) (list form acc)))
          forms :initial-value x))
