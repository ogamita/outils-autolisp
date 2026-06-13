(in-package #:edward.tests)
(in-suite edward-suite)

(defun emit (value) (with-output-to-string (s) (edward:json-emit value s nil)))

(test json-scalars
  (is (string= "true"  (emit :true)))
  (is (string= "false" (emit :false)))
  (is (string= "null"  (emit :null)))
  (is (string= "42"    (emit 42)))
  (is (string= "\"a\"" (emit "a"))))

(test json-number-no-lisp-exponent
  ;; A double-float must not leak a Lisp 'd0' exponent marker.
  (is (string= "1.5" (emit 1.5d0)))
  (let ((s (emit 1.0d10)))
    (is (not (find #\d s)))
    (is (not (find #\D s)))))

(test json-string-escaping
  (is (string= "\"a\\\"b\\\\c\"" (emit "a\"b\\c")))
  (is (string= "\"x\\ny\"" (emit (format nil "x~%y")))))

(test json-object-and-array
  (is (string= "{\"a\":1,\"b\":[\"x\",2,true]}"
               (emit (edward:jobj "a" 1 "b" (edward:jarr (list "x" 2 :true))))))
  (is (string= "{}" (emit (edward:jobj))))
  (is (string= "[]" (emit (edward:jarr '())))))
