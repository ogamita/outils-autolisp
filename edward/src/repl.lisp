(in-package #:edward)

;;;; The interactive explorer REPL.
;;;;
;;;; RUN-REPL loads a drawing into *drawing* / *sel* and runs a real Lisp
;;;; read-eval-print loop in the edward package, so the whole query / inspect /
;;;; validate / ops vocabulary is available unqualified. Nodes and selections
;;;; print as trees; other values use the normal Lisp printer. RUN-EVAL and
;;;; RUN-SCRIPT are the non-interactive forms (one form / a stream of forms).

(defun load-dwg (path)
  "Read PATH into *drawing* and reset *sel* to all its entities."
  (setf *drawing* (read-drawing path)
        *sel*     (entities *drawing*))
  (format t "~&;; loaded ~A — ~A entities, ~A appids~%"
          path (dwg:drawing-entity-count *drawing*) (length (drawing-appids *drawing*)))
  *drawing*)

(defun help-repl ()
  "Print a short crib of the explorer vocabulary."
  (format t "~&edward explorer — globals *drawing* and *sel*.
  roots      (entities d) (objects d) (table-records d) (dictionaries d) (header-vars d)
  navigate   (children s) (descendants s) (parent-of s) (ascend-to s :level)
  filter     (by-layer s \"L\") (by-kind s :insert) (by-appid s \"SCHMSPLUS\")
             (by-class s \"…\") (by-code s 1000) (where s #'pred) (pick s n)
  thread     (chain *drawing* (entities) (by-layer \"X\") (by-appid \"SCHMSPLUS\"))
  inspect    (show s [depth]) (examine node) (export-sel s :format :json|:sexp|:dxf-fragment)
  validate   (validate)            ; runs the rule engine on *drawing*
  edit       (edit node) (del s) (dup s) (ins dxf) (save \"out.dxf\")
  load       (load-dwg \"f.dwg\")    ; reads into *drawing* / *sel*
Quit with q, :q, or end-of-file.~%")
  (values))

(defun %print-repl-value (v)
  "Print a REPL result: trees for nodes/selections, normal printer otherwise."
  (cond
    ((node-p v) (print-tree v))
    ((and (consp v) (every #'node-p v))
     (let ((n (length v)))
       (print-tree (if (> n 40) (subseq v 0 40) v) :depth 1)
       (when (> n 40) (format t "~&;; … ~A nodes total~%" n))))
    ((null v) (format t "~&nil~%"))
    (t (format t "~&~S~%" v)))
  (values))

(defun %bind-globals (file schema-root)
  (when file (load-dwg file))
  (values))

(defun run-repl (&optional file &key schema-root)
  "Interactive explorer REPL. Loads FILE (if given), then read-eval-prints in
the edward package. Returns 0."
  (%bind-globals file schema-root)
  (let ((*package* (find-package :edward))
        (*schema-root* (or schema-root *schema-root*)))
    (format t "~&edward explorer REPL — (help-repl) for the vocabulary; q to quit.~%")
    (loop
      (format t "~&edward> ")
      (finish-output)
      (let ((form (handler-case (read *standard-input* nil :eof)
                    (end-of-file () :eof)
                    (error (e) (format t "~&;; read error: ~A~%" e) :skip))))
        (cond
          ((eq form :eof) (terpri) (return 0))
          ((eq form :skip) nil)
          ((member form '(q quit :q :quit)) (return 0))
          (t (handler-case
                 (let ((v (eval form)))
                   (setf *** ** ** * * v)
                   (%print-repl-value v))
               (error (e) (format t "~&;; error: ~A~%" e)))))))))

(defun run-eval (form-string &optional file &key schema-root)
  "Evaluate the single FORM-STRING (with FILE loaded if given) and print the
result. Returns 0, or 1 on error."
  (%bind-globals file schema-root)
  (let ((*package* (find-package :edward))
        (*schema-root* (or schema-root *schema-root*)))
    (handler-case
        (progn (%print-repl-value (eval (read-from-string form-string))) 0)
      (error (e) (format *error-output* "~&edward: ~A~%" e) 1))))

(defun run-script (&optional file &key schema-root)
  "Read forms from *standard-input* until EOF (FILE loaded if given),
evaluating each. Returns 0."
  (%bind-globals file schema-root)
  (let ((*package* (find-package :edward))
        (*schema-root* (or schema-root *schema-root*)))
    (loop for form = (read *standard-input* nil :eof)
          until (eq form :eof)
          do (handler-case
                 (let ((v (eval form))) (when v (%print-repl-value v)))
               (error (e) (format *error-output* "~&;; error: ~A~%" e)))))
  0)
