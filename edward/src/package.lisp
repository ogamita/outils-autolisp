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
   ;; explorer: globals & node model
   #:*drawing* #:*sel*
   #:node #:node-p #:node-level #:node-payload #:node-parent #:node-drawing #:node-index
   #:drawing-node #:node-children #:node-handle #:mutation-target #:node-path #:node-path-string
   ;; explorer: query language
   #:entities #:objects #:table-records #:dictionaries #:header-vars
   #:children #:descendants #:parent-of #:ascend-to
   #:where #:by-handle #:by-kind #:by-layer #:by-appid #:by-code #:by-class #:by-version #:by-level
   #:pick #:first-of #:count-of #:to-list #:chain
   ;; explorer: inspect & export
   #:show #:print-tree #:examine #:node-label #:export-sel #:node->json
   ;; explorer: validation
   #:rule #:make-rule #:defrule #:*rules* #:run-rules #:print-report #:report->json
   #:validate #:validate-file #:nodes-at
   ;; explorer: structured editor & operations
   #:edit-sexp #:edit #:del #:dup #:ins #:save #:edit-entity-pairs
   ;; explorer: REPL
   #:run-repl #:run-eval #:run-script #:load-dwg #:help-repl
   ;; CLI
   #:main
   #:%toplevel))
