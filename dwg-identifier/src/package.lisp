(defpackage #:dwg-identifier
  (:use #:cl)
  (:local-nicknames (#:dwg #:clautolisp.drawing))
  (:export
   ;; classification
   #:classify-drawing
   #:identify-file
   #:drawing-appids
   ;; result accessors
   #:classification
   #:classification-p
   #:classification-source
   #:classification-format
   #:classification-appids
   #:classification-products
   #:classification-plus-p
   #:classification-epure-p
   #:classification-entity-count
   #:classification-schema-versions
   #:classification-label
   ;; appid -> product
   #:appid-product
   #:*product-appids*
   ;; reporting / CLI
   #:report
   #:report-json
   #:main))
