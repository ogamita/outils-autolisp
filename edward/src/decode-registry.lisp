(in-package #:edward)

;;;; appid -> decoder. Unknown appids fall back to the raw layer (the caller
;;;; always keeps the raw pairs), so no data is ever lost.

(defun decoder-name-for-appid (appid)
  "The decoder label edward applies to APPID, or NIL (raw only)."
  (cond ((string-equal appid "SCHMSPLUS") "schms")
        ((string-equal appid "PV")        "pv")
        (t nil)))

(defun decode-xdata-group (appid pairs)
  "Decode an entity xdata group (APPID . PAIRS) to a JSON object, or NIL
when no decoder applies to APPID."
  (cond
    ((string-equal appid "SCHMSPLUS") (schms-decoded->json pairs *xdata-codec*))
    ((string-equal appid "PV")        (pv-decoded->json pairs))
    (t nil)))
