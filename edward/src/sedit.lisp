(in-package #:edward)

;;;; Structured s-expression editor — a cursor-based editor over cons trees.
;;;;
;;;; Adapted for edward from
;;;;   ~/src/public/lisp/small-cl-pgms/sedit/sedit.lisp
;;;; Copyright Pascal J. Bourguignon 2010-2016, GNU AGPL v3 (edward is AGPL-3.0
;;;; too — same author, license-compatible). Adaptations: moved into the
;;;; edward package, internal symbols prefixed SEDIT-, file save/load dropped
;;;; (edward owns persistence), and EDIT-SEXP returns the modified tree.
;;;;
;;;; edward's data is trees of conses — a DXF entity is ((code . value) …),
;;;; xdata/xrecord blocks nest — so a structural editor (navigate by car/cdr,
;;;; cut/copy/paste/insert/replace whole sub-trees) is the natural editing UI.
;;;; The buffer is a one-element root list holding the edited sexp; the cursor
;;;; is a SEDIT-SELECTION struct destructively spliced into the tree.

(defstruct sedit-selection
  parent-list
  sexp)

(defstruct (sedit-buffer (:constructor %make-sedit-buffer))
  root selection)

(defvar *sedit-clipboard* nil)

(defun sedit-make-buffer (contents)
  (let* ((root      (list contents))
         (selection (make-sedit-selection)))
    (sedit-select selection root 0)
    (setf (first root) selection)
    (%make-sedit-buffer :root root :selection selection)))

(defmacro with-sedit-buffer ((buffer rootvar selectionvar) &body body)
  `(with-accessors ((,rootvar sedit-buffer-root)
                    (,selectionvar sedit-buffer-selection))
       ,buffer
     ,@body))

(defun sedit-find-cell (object list)
  (cond
    ((eq (car list) object) list)
    ((null (cdr list)) nil)
    ((and (atom (cdr list)) (eq (cdr list) object)) list)
    (t (sedit-find-cell object (cdr list)))))

(defun sedit-unselect (selection)
  (let ((cell (sedit-find-cell selection (sedit-selection-parent-list selection))))
    (when cell
      (if (eq (car cell) selection)
          (setf (car cell) (sedit-selection-sexp selection))
          (setf (cdr cell) (sedit-selection-sexp selection))))))

(defun sedit-nth-cdr (n list)
  (cond ((not (plusp n)) list)
        ((atom list) list)
        (t (sedit-nth-cdr (1- n) (cdr list)))))

(defun sedit-select (selection parent index)
  "Splice the cursor SELECTION at INDEX of PARENT. Handles dotted tails (the
CDR of a dotted pair, e.g. a DXF (code . value) entry) by splicing into the
holding cons, not the atom value."
  (when (atom parent) (error "Cannot select from an atom."))
  (let ((holder (sedit-nth-cdr index parent)))
    (cond
      ((null holder) (error "cannot select so far"))
      ((consp holder)               ; normal element: select its CAR
       (setf (sedit-selection-parent-list selection) parent
             (sedit-selection-sexp selection) (car holder)
             (car holder) selection))
      (t                            ; dotted tail at INDEX: splice the holder's CDR
       (let ((hc (sedit-nth-cdr (1- index) parent)))
         (setf (sedit-selection-parent-list selection) parent
               (sedit-selection-sexp selection) (cdr hc)
               (cdr hc) selection))))))

(defun sedit-find-object (sexp object)
  "Return the cons cell of SEXP where OBJECT is held."
  (cond
    ((atom sexp) nil)
    ((eq sexp object) nil)
    ((or (eq (car sexp) object) (eq (cdr sexp) object)) sexp)
    (t (or (sedit-find-object (car sexp) object)
           (sedit-find-object (cdr sexp) object)))))

(defmethod print-object ((selection sedit-selection) stream)
  (princ "【" stream)
  (prin1 (sedit-selection-sexp selection) stream)
  (princ "】" stream)
  selection)

(defun sedit-print (buffer)
  (pprint (first (sedit-buffer-root buffer)))
  (finish-output))

(defun sedit-unselected-sexp (list selection)
  "A copy of LIST with the selection cursor removed."
  (cond
    ((consp list) (cons (sedit-unselected-sexp (car list) selection)
                        (sedit-unselected-sexp (cdr list) selection)))
    ((eq list selection) (sedit-unselected-sexp (sedit-selection-sexp selection) selection))
    (t list)))

(defmacro sedit-reporting-errors (&body body)
  `(handler-case (progn ,@body)
     (error (err) (format *error-output* "~&;; ~A: ~A~%" (class-name (class-of err)) err)
       (finish-output *error-output*))))

(defun sedit-eval (buffer)
  (with-sedit-buffer (buffer root selection)
    (declare (ignore root))
    (sedit-reporting-errors
      (format *query-io* "~& --> ~{~S~^ ;~%     ~}~%"
              (multiple-value-list (eval (sedit-selection-sexp selection)))))
    (finish-output *query-io*)))

(defun sedit-down (buffer)
  (with-sedit-buffer (buffer root selection)
    (declare (ignore root))
    (if (atom (sedit-selection-sexp selection))
        (format *query-io* "Cannot enter an atom.~%")
        (progn (sedit-unselect selection)
               (sedit-select selection (sedit-selection-sexp selection) 0)))))

(defun sedit-up (buffer)
  (with-sedit-buffer (buffer root selection)
    (let ((gparent (sedit-find-object root (sedit-selection-parent-list selection))))
      (when gparent
        (sedit-unselect selection)
        (sedit-select selection gparent 0)))))

(defun sedit-forward (buffer)
  (with-sedit-buffer (buffer root selection)
    (let ((index (position selection (sedit-selection-parent-list selection))))
      (if (or (null index) (<= (length (sedit-selection-parent-list selection)) (1+ index)))
          (sedit-up buffer)
          (progn (sedit-unselect selection)
                 (sedit-select selection (sedit-selection-parent-list selection) (1+ index)))))))

(defun sedit-backward (buffer)
  (with-sedit-buffer (buffer root selection)
    (let ((index (position selection (sedit-selection-parent-list selection))))
      (if (or (null index) (<= index 0))
          (sedit-up buffer)
          (progn (sedit-unselect selection)
                 (sedit-select selection (sedit-selection-parent-list selection) (1- index)))))))

(defun sedit-cut (buffer)
  (with-sedit-buffer (buffer root selection)
    (setf *sedit-clipboard* (sedit-selection-sexp selection))
    (let ((gparent (sedit-find-object root (sedit-selection-parent-list selection))))
      (if (eq (car gparent) (sedit-selection-parent-list selection))
          (setf (car gparent) (delete selection (sedit-selection-parent-list selection)))
          (setf (cdr gparent) (delete selection (sedit-selection-parent-list selection))))
      (sedit-select selection gparent 0))))

(defun sedit-copy (buffer)
  (with-sedit-buffer (buffer root selection)
    (declare (ignore root))
    (setf *sedit-clipboard* (copy-tree (sedit-selection-sexp selection)))))

(defun sedit-paste (buffer)
  (with-sedit-buffer (buffer root selection)
    (declare (ignore root))
    (setf (sedit-selection-sexp selection) (copy-tree *sedit-clipboard*))))

(defun sedit-insert-into (object list where reference)
  (ecase where
    ((:before)
     (cond ((null list) (error "Cannot insert in an empty list."))
           ((eq reference (car list))
            (setf (cdr list) (cons (car list) (cdr list)) (car list) object))
           (t (sedit-insert-into object (cdr list) where reference))))
    ((:after)
     (cond ((null list) (error "Cannot insert in an empty list."))
           ((eq (car list) reference) (push object (cdr list)))
           (t (sedit-insert-into object (cdr list) where reference))))))

(defun sedit-read-sexp (prompt)
  (princ prompt *query-io*) (finish-output *query-io*)
  (read *query-io*))

(defun sedit-insert (buffer)
  (with-sedit-buffer (buffer root selection)
    (let ((new-sexp (sedit-read-sexp "sexp to insert before: ")))
      (cond
        ((eq selection (first root))
         (setf (car root) (list new-sexp selection)
               (sedit-selection-parent-list selection) (car root)))
        ((eq selection (first (sedit-selection-parent-list selection)))
         (let ((gparent (sedit-find-object root (sedit-selection-parent-list selection))))
           (setf (sedit-selection-parent-list selection)
                 (if (eq (car gparent) (sedit-selection-parent-list selection))
                     (setf (car gparent) (cons new-sexp (sedit-selection-parent-list selection)))
                     (setf (cdr gparent) (cons new-sexp (sedit-selection-parent-list selection)))))))
        (t (sedit-insert-into new-sexp (sedit-selection-parent-list selection) :before selection))))))

(defun sedit-add (buffer)
  (with-sedit-buffer (buffer root selection)
    (let ((new-sexp (sedit-read-sexp "sexp to insert after: ")))
      (if (eq selection (first root))
          (setf (car root) (list selection new-sexp)
                (sedit-selection-parent-list selection) (car root))
          (sedit-insert-into new-sexp (sedit-selection-parent-list selection) :after selection)))))

(defun sedit-replace (buffer)
  (with-sedit-buffer (buffer root selection)
    (declare (ignore root))
    (setf (sedit-selection-sexp selection) (sedit-read-sexp "replacement sexp: "))))

(defun sedit-quit (buffer)
  (throw 'sedit-done buffer))

;;; Command table / bindings

(defparameter *sedit-command-map*
  '((q quit sedit-quit "return the modified sexp.")
    (d down sedit-down "enter inside the selected list.")
    (u up sedit-up "select the list containing the selection.")
    (f forward sedit-forward "select the next sexp (or up).")
    (n next sedit-forward "select the next sexp (or up).")
    (b backward sedit-backward "select the previous sexp (or up).")
    (p previous sedit-backward "select the previous sexp (or up).")
    (i insert sedit-insert "insert a new sexp before the selection.")
    (r replace sedit-replace "replace the selection with a new sexp.")
    (a add sedit-add "add a new sexp after the selection.")
    (x cut sedit-cut "cut the selection to the clipboard.")
    (c copy sedit-copy "copy the selection to the clipboard.")
    (y paste sedit-paste "paste the clipboard over the selection.")
    (e eval sedit-eval "evaluate the selection.")
    (h help sedit-help "print this help.")))

(defvar *sedit-bindings* (make-hash-table))

(defun sedit-bind (command function) (setf (gethash command *sedit-bindings*) function))
(defun sedit-binding (command) (gethash command *sedit-bindings*))

(defun sedit-help (buffer)
  (declare (ignore buffer))
  (format *query-io* "~:{~A) ~10A ~*~A~%~}" *sedit-command-map*))

(defun sedit-initialize-bindings ()
  (loop for (short long function) in *sedit-command-map*
        do (sedit-bind short function) (sedit-bind long function)))

(defun sedit-core (buffer)
  (sedit-print buffer)
  (terpri *query-io*)
  (princ "sedit> " *query-io*)
  (finish-output *query-io*)
  (let* ((command (let ((*package* (find-package :edward))) (read *query-io*)))
         (function (sedit-binding command)))
    (if function
        (funcall function buffer)
        (format *query-io* "~&Commands: ~{~(~A~)~^ ~}.~%"
                (mapcar #'first *sedit-command-map*)))))

(defun edit-sexp (&optional sexp)
  "Interactively edit SEXP (a cons tree) and return the modified tree.
SEXP is modified destructively; pass a COPY-TREE to keep the original."
  (format *query-io* "~&Sexp editor — h for help, q to finish.~%")
  (sedit-initialize-bindings)
  (let ((buffer (sedit-make-buffer sexp)))
    (unwind-protect
         (catch 'sedit-done
           (loop (sedit-reporting-errors (sedit-core buffer))))
      (sedit-unselect (sedit-buffer-selection buffer)))
    (first (sedit-buffer-root buffer))))
