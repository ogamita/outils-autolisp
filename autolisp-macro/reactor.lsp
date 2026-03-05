(vl-load-com)

(setq *my:obj-reactor* nil)
(setq *my:watched-ename* nil)

(defun my:watch-line ()
  (setq *my:watched-ename*
        (car (entsel "\nSelect a LINE to watch: ")))

  (if (null *my:watched-ename*)
    (prompt "\nNothing selected.")
    (progn
      ;; create object reactor attached to that entity
      (setq *my:obj-reactor*
            (vlr-object-reactor
              (list *my:watched-ename*)
              "my-line-reactor"
              '((:vlr-modified . my:on-modified)
                (:vlr-erased   . my:on-erased)
                (:vlr-copied   . my:on-copied))))

      (prompt "\nObject reactor installed. Modify / erase / copy the line to see callbacks.")))

  (princ))

(defun my:on-modified (reactor obj / en)
  ;; obj is a VLA-object
  (setq en (vlax-vla-object->ename obj))
  (prompt (strcat "\n[reactor] modified: " (vl-princ-to-string en)))
  (princ))

(defun my:on-erased (reactor obj flag / en)
  ;; flag = T when erased, NIL when unerased
  (setq en (vlax-vla-object->ename obj))
  (prompt
    (strcat "\n[reactor] erased state changed: "
            (vl-princ-to-string en)
            " erased="
            (if flag "T" "NIL")))
  (princ))

(defun my:on-copied (reactor obj newobj / en newen)
  (setq en    (vlax-vla-object->ename obj))
  (setq newen (vlax-vla-object->ename newobj))
  (prompt
    (strcat "\n[reactor] copied: "
            (vl-princ-to-string en)
            " -> "
            (vl-princ-to-string newen)))
  (princ))

(defun my:unwatch-line ()
  (if *my:obj-reactor*
    (progn
      (vlr-remove *my:obj-reactor*)
      (setq *my:obj-reactor* nil)
      (setq *my:watched-ename* nil)
      (prompt "\nObject reactor removed."))
    (prompt "\nNo reactor installed."))
  (princ))

(defun c:watchline ()   (my:watch-line))
(defun c:unwatchline () (my:unwatch-line))
