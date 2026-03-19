(defun c:AUTOLISP-DIAG-WRITE-MARKER (/ f marker)
  (setq marker "/tmp/autolisp-bricscad-marker.txt")
  (setq f (open marker "w"))
  (if f
    (progn
      (write-line "autolisp bricscad batch marker" f)
      (close f)
      (princ (strcat "\nMARKER-WRITTEN " marker "\n")))
    (princ (strcat "\nMARKER-OPEN-FAILED " marker "\n")))
  (princ))

(c:AUTOLISP-DIAG-WRITE-MARKER)
