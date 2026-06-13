(in-package #:edward)

;;;; Reader for the SCHMS class-definition files *_ATTR.LSP, and validation
;;;; of decoded instances against them.
;;;;
;;;; A *_ATTR.LSP file (cp1252-encoded) is an S-expression alist:
;;;;   ((NOM_DAFFICHAGE . "Voie")
;;;;    (CATEGORIES "Non graphique")
;;;;    (SCHEMAS
;;;;      (3 "desc" ("UUID" chaine) ("TYPE_VOIE" enum "A" "B")
;;;;                (@inclure "/es/schms/commun/etats" 1))
;;;;      (2 "desc" ...) (1 "desc" ...)))
;;;; Versions are listed newest-first; a field is ("NAME" type args…); the
;;;; (@inclure "/path" version) directive splices, by value, the fields of
;;;; another class at a fixed version (recursive).
;;;;
;;;; edward reproduces this from the point of view of the *drawing*: the
;;;; schema informs (names, types, validation) but never overrides the raw
;;;; data — divergences are reported, not corrected (see decode-schms.lisp).

(defpackage #:edward.attr (:use)
  (:documentation "Throwaway package the *_ATTR.LSP reader interns into."))

(defparameter *schema-root* nil
  "Directory holding the SCHMS *_ATTR.LSP tree (e.g. the schms/ checkout).
NIL disables schema-informed validation (structural decode still works).")

(defvar *class-cache* (make-hash-table :test #'equal)
  "Cache of class-name -> parsed class (or :missing).")

;;; --- class-name -> file ------------------------------------------------

(defun %class-file (class-name &optional (root *schema-root*))
  "Resolve a SCHMS class name (/es/schms/<dir>/<name>) to its *_ATTR.LSP
pathname under ROOT: <dir> uppercased, <name> uppercased + _ATTR.LSP."
  (when root
    (let* ((segs (remove "" (uiop:split-string class-name :separator "/")
                         :test #'string=))
           (tail (let ((pos (position "schms" segs :test #'string-equal)))
                   (if pos (nthcdr (1+ pos) segs) segs))))
      (when (cdr tail)
        (let ((dirs (butlast tail))
              (name (car (last tail))))
          (merge-pathnames
           (make-pathname :directory (cons :relative (mapcar #'string-upcase dirs))
                          :name (concatenate 'string (string-upcase name) "_ATTR")
                          :type "LSP")
           (uiop:ensure-directory-pathname root)))))))

;;; --- reading the S-expression -----------------------------------------

(defun %read-attr-file (path)
  "Read PATH (cp1252) as a single S-expression, symbols interned into
EDWARD.ATTR, *read-eval* disabled. Returns the form, or NIL on failure."
  (handler-case
      (with-open-file (s path :external-format :cp1252)
        (let ((*package* (find-package '#:edward.attr))
              (*read-eval* nil))
          (read s)))
    (error () nil)))

(defun %sym= (x name)
  "True if X is a symbol whose name equals NAME (case-insensitive)."
  (and (symbolp x) (string-equal (symbol-name x) name)))

(defun %type->descriptor (form)
  "Map an *_ATTR.LSP type form to a descriptor: (:str)/(:int)/(:real)/
(:bool)/(:handle)/(:enum alt…)/(:list elem)/(:object class version).
Follows classe.lsp's conversion_type (LISTE's element is the tail (cdr typ));
defensive against bare-symbol type forms."
  (let* ((listp (consp form))
         (head  (if listp (car form) form))
         (args  (if listp (cdr form) nil)))
    (cond
      ((%sym= head "CHAINE")  '(:str))
      ((%sym= head "ENTIER")  '(:int))
      ((%sym= head "REEL")    '(:real))
      ((%sym= head "BOOLEEN") '(:bool))
      ((%sym= head "HANDLE")  '(:handle))
      ((%sym= head "ENUM")    (cons :enum args))
      ((%sym= head "LISTE")   (list :list (%type->descriptor args)))
      ((%sym= head "OBJET")   (list :object (first args) (second args)))
      (t                      (list :unknown (format nil "~A" head))))))

(defun %schema-fields (schema-body class-loader)
  "Turn one SCHEMAS version body (a list of field forms / @inclure forms)
into an ordered alist (name . descriptor), expanding @inclure by value."
  (let ((out '()))
    (dolist (item schema-body (nreverse out))
      (cond
        ((and (consp item) (%sym= (car item) "@INCLURE"))
         (let* ((inc (funcall class-loader (cadr item)))
                (ver (caddr item)))
           (when inc
             (dolist (f (class-version-fields inc ver))
               (push f out)))))
        ((and (consp item) (stringp (car item)))
         (push (cons (car item) (%type->descriptor (cdr item))) out))))))

;;; --- the class model ---------------------------------------------------

(defstruct (schema-class (:conc-name sc-))
  name display-name categories
  versions)        ; alist version -> alist(name . descriptor)

(defun class-version-fields (class version)
  "The ordered (name . descriptor) alist for CLASS at VERSION, or NIL."
  (cdr (assoc version (sc-versions class) :test #'eql)))

(defun %parse-class (form name)
  "Parse a raw *_ATTR.LSP FORM into a SCHEMA-CLASS named NAME."
  (flet ((entry (key) (cdr (assoc-if (lambda (k) (%sym= k key)) form))))
    (let* ((display (let ((d (entry "NOM_DAFFICHAGE"))) (and (stringp d) d)))
           (cats    (entry "CATEGORIES"))
           (schemas (entry "SCHEMAS"))
           (loader  (lambda (cn) (load-class cn)))
           (versions
             (mapcar (lambda (vform)
                       ;; vform = (N "desc" field…)
                       (cons (car vform)
                             (%schema-fields (cddr vform) loader)))
                     schemas)))
      (make-schema-class :name name :display-name display
                         :categories cats :versions versions))))

(defun load-class (class-name &optional (root *schema-root*))
  "Load and parse the SCHEMA-CLASS for CLASS-NAME (cached). Returns the
class, or NIL when ROOT is unset or the file is absent/unreadable."
  (when root
    (let ((cached (gethash class-name *class-cache* :none)))
      (if (not (eq cached :none))
          (and (not (eq cached :missing)) cached)
          (let* ((path (%class-file class-name root))
                 (form (and path (probe-file path) (%read-attr-file path)))
                 (class (and form (consp form) (%parse-class form class-name))))
            (setf (gethash class-name *class-cache*) (or class :missing))
            class)))))

;;; --- validating a decoded instance ------------------------------------

(defun %value-type-ok-p (descriptor value)
  "Loose check that VALUE (a decoded scalar / block) fits DESCRIPTOR."
  (case (car descriptor)
    (:str    (stringp value))
    (:handle (stringp value))
    (:enum   (and (stringp value) (member value (cdr descriptor) :test #'string=)))
    (:int    (integerp value))
    (:bool   (member value '(0 1)))
    (:real   (realp value))
    ((:list :object) (and (consp value) (eq (car value) :block)))
    (t t)))

(defun validate-instance (class-name version fields &optional (root *schema-root*))
  "Validate a decoded instance against its *_ATTR.LSP schema. Returns a
list of divergence plists, empty when conformant. NIL ROOT -> NIL (no
validation performed)."
  (when root
    (let ((class (load-class class-name root))
          (divs '()))
      (cond
        ((null class) (push (list :kind :unknown-class :class class-name) divs))
        (t
         (let ((schema (class-version-fields class version)))
           (if (and version (null schema)
                    (not (assoc version (sc-versions class) :test #'eql)))
               (push (list :kind :unknown-version :class class-name :version version) divs)
               (dolist (kv fields)
                 (let* ((fname (car kv)) (value (cdr kv))
                        (descr (cdr (assoc fname schema :test #'string=))))
                   (cond
                     ((null descr)
                      (push (list :kind :unknown-field :field fname) divs))
                     ((not (%value-type-ok-p descr value))
                      (push (list :kind :type-mismatch :field fname
                                  :expected (car descr) :value value) divs)))))))))
      (nreverse divs))))
