;;; format-tests.lsp --- Tests unitaires de misc/src/format.lsp

;;; =format.lsp= doit être chargé par le harness avant ce script.

(setq *format-test-fails* 0)

(defun format-check (label expected actual)
  (if (= expected actual)
    (progn (princ "PASS ") (princ label) (terpri))
    (progn
      (princ "FAIL ") (princ label) (terpri)
      (princ "  expected: ") (princ (vl-prin1-to-string expected)) (terpri)
      (princ "  actual:   ") (princ (vl-prin1-to-string actual)) (terpri)
      (setq *format-test-fails* (1+ *format-test-fails*)))))

(format-check "a-basic"
  "abc"
  (format "~A" '("abc")))

(format-check "a-width"
  "abc  "
  (format "~5A" '("abc")))

(format-check "s-basic"
  "\"abc\""
  (format "~S" '("abc")))

(format-check "d-width"
  "   12"
  (format "~5D" '(12)))

(format-check "bases"
  "1010 12 A"
  (format "~B ~O ~X" '(10 10 10)))

(format-check "float-width-decimals"
  "   12.50"
  (format "~8,2F" '(12.5)))

(format-check "char-basic"
  "Z"
  (format "~C" '("Zed")))

(format-check "char-at"
  "#\\Q"
  (format "~@C" '("Q")))

(format-check "tilde-and-percent"
  "~~\n"
  (format "~2~~%" '()))

(format-check "fresh-line-at-column-zero"
  "abc\n"
  (format "abc~&" '()))

(format-check "fresh-line-already-bol"
  "a\n\n"
  (format "a~2&" '()))

(format-check "dynamic-params"
  "xy        17"
  (format "~VA~VD" '(8 "xy" 4 17)))

(format-check "a-padchar"
  "hello-----"
  (format "~10,,,'-A" '("hello")))

(format-check "s-padchar"
  "\"hello\"---"
  (format "~10,,,'-S" '("hello")))

(format-check "d-padchar"
  "########42"
  (format "~10,'#D" '(42)))

(format-check "o-padchar"
  "########52"
  (format "~10,'#O" '(42)))

(format-check "x-padchar"
  "########2A"
  (format "~10,'#X" '(42)))

(format-check "b-padchar"
  "##########101010"
  (format "~16,'#B" '(42)))

(format-check "b-padchar-negative"
  "#########-101010"
  (format "~16,'#B" '(-42)))

(format-check "x-padchar-negative"
  "#############-2A"
  (format "~16,'#X" '(-42)))

(format-check "o-padchar-negative"
  "#############-52"
  (format "~16,'#O" '(-42)))

(format-check "d-padchar-negative"
  "#############-42"
  (format "~16,'#D" '(-42)))

(format-check "iteration-list"
  "| apple      |         12\n| orange     |        423\n| strawberry |       1200\n"
  (format "~{| ~10A | ~10D~%~}" '(("apple" 12 "orange" 423 "strawberry" 1200))))

(format-check "iteration-list-of-lists"
  "| apple      |         12\n| orange     |        423\n| strawberry |       1200\n"
  (format "~:{| ~10A | ~10D~%~}" '((("apple" 12 ripe) ("orange" 423 green) ("strawberry" 1200 bad)))))

(format-check "iteration-direct-args"
  "| apple      |         12\n| orange     |        423\n| strawberry |       1200\n"
  (format "~@{| ~10A | ~10D~%~}" '("apple" 12 "orange" 423 "strawberry" 1200)))

(format-check "iteration-list-args"
  "| apple      |         12\n| orange     |        423\n| strawberry |       1200\n"
  (format "~:@{| ~10A | ~10D~%~}" '(("apple" 12 ripe) ("orange" 423 green) ("strawberry" 1200 bad))))

(if (= *format-test-fails* 0)
  (princ "TESTS OK")
  (progn (princ "TESTS FAILED: ") (princ *format-test-fails*)))
(terpri)

(defun C:MAIN ()
  (if (= *format-test-fails* 0) "OK" "FAIL"))
