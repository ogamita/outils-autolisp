(in-package #:dwg-identifier)

;;;; Classify a drawing by the application appids it carries.
;;;;
;;;; Each SNCF EPURE application registers an eponymous appid family in
;;;; the drawing's APPID table (and tags its objects with xdata under
;;;; that appid). The originating application is therefore read straight
;;;; off the APPID table — no AutoLISP, no schema decoding.
;;;;
;;;;   SCHMS     : SCHMS, SCHMSPLUS, SCHMS_*           (postes/voies/lignes)
;;;;   SCHME     : SCHME, SCHME+, SCHMEPLUS, SCHME[-_]*
;;;;   SCHMIEUX  : SCHMIEUX, SCHMIEUX_*
;;;;   PV        : PV, PVPLUS, PV2010, PV-SUITE, PVSX_*, PV_*
;;;;   EPURE     : EPURE, EPURELIB, EPURE_*, SNCF-Com_*  (shared umbrella)

(defparameter *product-appids*
  '((:schmieux . ("SCHMIEUX"))                       ; before :schms* (distinct anyway)
    (:schms    . ("SCHMS" "SCHMSPLUS" "SCHMS_" "SCHMS-"))
    (:schme    . ("SCHME" "SCHME+" "SCHMEPLUS" "SCHME_" "SCHME-"))
    (:pv       . ("PV" "PVPLUS" "PV2010" "PV-SUITE" "PVSX_" "PV_"))
    (:epure    . ("EPURE" "EPURELIB" "EPURE_" "SNCF-COM_")))
  "Map of product keyword -> appid names/prefixes that identify it.")

(defparameter *product-labels*
  '((:schms . "SCHMS") (:schme . "SCHME") (:schmieux . "SCHMIEUX")
    (:pv . "PV") (:epure . "EPURE"))
  "Human display names per product keyword.")

(defun %appid-matches-p (appid pattern)
  "True if APPID (uppercased) equals PATTERN or starts with it (PATTERN
ending in a separator, or being a known whole-name, makes the prefix a
family match)."
  (let ((la (length appid)) (lp (length pattern)))
    (or (string= appid pattern)
        (and (> la lp) (string= pattern appid :end2 lp)))))

(defun appid-product (appid)
  "The product keyword APPID belongs to, or NIL."
  (let ((a (string-upcase appid)))
    (loop for (product . patterns) in *product-appids*
          when (some (lambda (p) (%appid-matches-p a p)) patterns)
            return product)))

(defstruct (classification (:conc-name classification-))
  source            ; the file / drawing the result is about
  format            ; :dwg / :dxf-ascii / :dxf-binary / …
  appids            ; sorted list of all APPID-table names (strings)
  products          ; sorted list of product keywords found
  plus-p            ; T if a "+/PLUS" edition appid is present
  epure-p           ; T if an EPURE/SNCF umbrella appid is present
  entity-count)     ; number of entities

(defun drawing-appids (drawing)
  "The sorted list of APPID-table record names in DRAWING."
  (let ((ids '()))
    (dwg:map-table-records
     (lambda (r) (push (dwg:symbol-table-record-name r) ids))
     drawing :appid)
    (sort ids #'string<)))

(defun %plus-appid-p (appid)
  (let ((a (string-upcase appid)))
    (or (find #\+ a)
        (and (>= (length a) 4) (string= "PLUS" a :start2 (- (length a) 4))))))

(defun classify-drawing (drawing &optional source)
  "Classify DRAWING by its APPID table. SOURCE is recorded for the
report (a pathname / label)."
  (let* ((appids (drawing-appids drawing))
         (products (sort (remove-duplicates
                          (remove nil (mapcar #'appid-product appids)))
                         #'string< :key #'symbol-name)))
    (make-classification
     :source source
     :format (dwg:drawing-format drawing)
     :appids appids
     :products products
     :plus-p (and (some (lambda (a) (and (appid-product a) (%plus-appid-p a))) appids) t)
     :epure-p (and (member :epure products) t)
     :entity-count (dwg:drawing-entity-count drawing))))

(defun identify-file (path)
  "Read the drawing at PATH (DXF or, with clautolisp/drawing-dwg loaded,
DWG) and classify it."
  (classify-drawing (dwg:read-drawing path) path))

(defun classification-label (classification)
  "A short human label, e.g. \"SCHMS+ (EPURE)\", \"PV\", \"unknown (EPURE)\"."
  (let* ((apps (remove :epure (classification-products classification)))
         (names (mapcar (lambda (k) (cdr (assoc k *product-labels*))) apps))
         (base (if names
                   (format nil "~{~A~^ + ~}~:[~;+~]"
                           names (classification-plus-p classification))
                   "unknown")))
    (if (classification-epure-p classification)
        (format nil "~A (EPURE)" base)
        base)))
