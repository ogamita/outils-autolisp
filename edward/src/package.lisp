(defpackage #:edward
  (:use #:cl)
  (:local-nicknames (#:dwg #:clautolisp.drawing)
                    (#:id  #:dwg-identifier))
  (:documentation "edward — dump and transfer the EPURE application data
stored in DWG/DXF drawings. Built on clautolisp.drawing; reuses
dwg-identifier for APPID-table classification.")
  (:export
   ;; dwg-access helpers
   #:read-drawing
   #:entity-xdata
   #:walk-dictionaries
   #:dxf-pair-code
   #:dxf-pair-value
   ;; JSON
   #:json-emit
   #:jobj
   #:jarr
   ;; dump
   #:dump-drawing
   #:dump-file
   #:roundtrip-file
   ;; CLI
   #:main
   #:%toplevel))
