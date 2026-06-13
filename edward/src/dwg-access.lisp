(in-package #:edward)

;;;; Thin adaptation layer over clautolisp.drawing.
;;;;
;;;; It isolates edward from the exact shape of the clautolisp API and adds
;;;; the few helpers clautolisp does not provide directly: grouping an
;;;; entity's xdata by appid, and a depth-first walk of the named-object
;;;; dictionary (NOD).
;;;;
;;;; Runtime shapes (verified against real SCHMS+ DWG via libredwg):
;;;;  - entity / object / table-record data is a list of DXF entries, each a
;;;;    dotted pair (CODE . VALUE) — VALUE an atom — or, for coalesced points,
;;;;    a proper list (CODE X Y Z).
;;;;  - xdata appears FLAT at the tail of an entity's data: a (1001 . APPID)
;;;;    marker followed by that appid's xdata pairs (codes >= 1000), until the
;;;;    next 1001 marker or the end.
;;;;  - NOD entries map a key to a sub-DICTIONARY, a hex-handle STRING (an
;;;;    object in DRAWING-OBJECTS, e.g. an XRECORD), or an ENTITY-HANDLE.

(defun read-drawing (source &key format)
  "Read SOURCE (DXF or, with clautolisp/drawing-dwg loaded, DWG) into a
clautolisp drawing value."
  (dwg:read-drawing source :format format))

(declaim (inline dxf-pair-code dxf-pair-value))

(defun dxf-pair-code (pair)
  "The DXF group code of a (CODE . VALUE) entry."
  (car pair))

(defun dxf-pair-value (pair)
  "The value of a DXF entry: an atom for a scalar (CODE . VALUE), or a
proper list (X Y Z) for a coalesced point (CODE X Y Z)."
  (cdr pair))

(defun entity-xdata (entity)
  "Group ENTITY's xdata by appid. Returns a list of (APPID . PAIRS) in
document order; PAIRS are the raw (CODE . VALUE) entries (codes >= 1000)
that follow each (1001 . APPID) marker, the marker excluded. An entity
with no xdata yields NIL."
  (let ((groups '()) (curapp nil) (cur '()))
    (flet ((flush ()
             (when curapp
               (push (cons curapp (nreverse cur)) groups)
               (setf curapp nil cur '()))))
      (dolist (p (dwg:entity-dxf entity))
        (when (consp p)
          (let ((code (car p)))
            (cond
              ((eql code 1001) (flush) (setf curapp (cdr p)))
              ((and curapp (integerp code) (>= code 1000)) (push p cur))))))
      (flush))
    (nreverse groups)))

(defun walk-dictionaries (drawing fn &optional
                                       (dictionary (dwg:drawing-dictionary drawing))
                                       (path '()))
  "Depth-first walk of DRAWING's named-object dictionary. For every entry
call FN with (PATH KEY VALUE): PATH is the root-first list of ancestor
dictionary names, KEY the entry name, VALUE a sub-DICTIONARY, a hex-handle
string, or an ENTITY-HANDLE. Recurses into sub-dictionaries (FN is called
on the sub-dictionary entry before descending). Returns NIL."
  (dwg:map-dictionary
   (lambda (key value)
     (funcall fn path key value)
     (when (dwg:dictionary-p value)
       (walk-dictionaries drawing fn value (append path (list key)))))
   dictionary)
  nil)

(defun drawing-appids (drawing)
  "The sorted list of APPID-table record names (strings)."
  (let ((ids '()))
    (dwg:map-table-records
     (lambda (r) (push (dwg:symbol-table-record-name r) ids))
     drawing :appid)
    (sort ids #'string<)))
