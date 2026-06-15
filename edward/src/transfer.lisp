(in-package #:edward)

;;;; V2 — transfer drawing-level SCHMS data between drawings.
;;;;
;;;; The SCHMS database (non-graphic) tables LIGNES / VOIES / POSTES live as
;;;; named dictionaries under the NOD, each entry pointing at an XRECORD in
;;;; DRAWING-OBJECTS. This module copies those dictionaries (and their
;;;; XRECORDs) from a source drawing into a destination, with replace-prune
;;;; semantics: the destination's matching dictionary is removed first, then
;;;; the source's is copied in with freshly-allocated destination handles so
;;;; the copied XRECORDs can never collide with the destination's own
;;;; objects. Schema versions are preserved verbatim (no migration; §5).

(defparameter *bd-dictionaries* '("SCHMS_LIGNES" "SCHMS_VOIES" "SCHMS_POSTES")
  "The SCHMS database dictionaries (non-graphic) under the NOD.")

(defun %hex (n) (format nil "~X" n))

(defun %xrecord-rehandle (data handle owner)
  "A copy of XRECORD DATA with its own handle (5) set to HANDLE and every
owner pointer (330) set to OWNER (both hex strings)."
  (mapcar (lambda (p)
            (cond ((not (consp p)) p)
                  ((eql (car p) 5)   (cons 5 handle))
                  ((eql (car p) 330) (cons 330 owner))
                  (t p)))
          data))

(defun %remove-nod-dictionary (drawing name)
  "Remove the NOD sub-dictionary NAME from DRAWING along with the objects
its entries point at. Returns the count removed."
  (let* ((nod (dwg:drawing-dictionary drawing))
         (sub (dwg:dictionary-get nod name))
         (n 0))
    (when (dwg:dictionary-p sub)
      (dwg:map-dictionary
       (lambda (k v) (declare (ignore k))
         (when (and (stringp v) (dwg:remove-object drawing v)) (incf n)))
       sub)
      (dwg:dictionary-remove nod name))
    n))

(defun transfer-dictionary (source dest name)
  "Replace the NOD dictionary NAME in DEST with a copy of SOURCE's. Each
entry's XRECORD is copied with freshly-allocated DEST handles; DEST's
existing NAME dictionary (and its objects) are removed first. Returns the
number of entries copied, or NIL when SOURCE has no such dictionary."
  (let ((src-sub (dwg:dictionary-get (dwg:drawing-dictionary source) name)))
    (when (dwg:dictionary-p src-sub)
      (%remove-nod-dictionary dest name)
      (let* ((dest-nod    (dwg:drawing-dictionary dest))
             (sub-handle  (%hex (dwg:allocate-handle dest)))
             (new-sub     (dwg:make-dictionary :handle sub-handle))
             (count 0))
        (dwg:map-dictionary
         (lambda (key src-handle)
           (when (stringp src-handle)
             (let ((obj (dwg:find-object source src-handle)))
               (when obj
                 (let* ((h    (%hex (dwg:allocate-handle dest)))
                        (data (%xrecord-rehandle obj h sub-handle)))
                   (dwg:add-object dest h data)
                   (dwg:dictionary-put new-sub key h)
                   (incf count))))))
         src-sub)
        (dwg:dictionary-put dest-nod name new-sub)
        count))))

(defun transfer-bd-data (source dest &optional (names *bd-dictionaries*))
  "Transfer the SCHMS BD dictionaries NAMES from SOURCE into DEST. Returns
an alist (name . count) for the dictionaries actually transferred."
  (loop for name in names
        for n = (transfer-dictionary source dest name)
        when n collect (cons name n)))

(defun transfer-bd-file (source-path dest-path out-path &key (names *bd-dictionaries*))
  "Read SOURCE-PATH and DEST-PATH, transfer the BD dictionaries from source
into the in-memory destination, and write the result to OUT-PATH (DXF when
its type is \"dxf\", else native DWG). Returns the (name . count) report."
  (let* ((source (read-drawing source-path))
         (dest   (read-drawing dest-path))
         (report (transfer-bd-data source dest names))
         (type   (string-downcase (or (pathname-type (pathname out-path)) "dxf"))))
    (if (string= type "dxf")
        (dwg:dxf-write-drawing dest out-path :external-format :utf-8)
        (dwg:write-drawing dest out-path :format :dwg))
    report))
