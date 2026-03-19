;;; doc-tests.lsp --- Tests for autolisp-doc

(defsuite "autolisp-doc")
(in-suite "autolisp-doc")

(deftest
  "documentation returns formatted function text"
  (function
    (lambda (/ ad-doc)
      (setq ad-doc (documentation 'open 'function))
      (is ad-doc)
      (is (wcmatch ad-doc "*open (AutoLISP)*"))
      (is (wcmatch ad-doc "*Signature:*"))
      (is (wcmatch ad-doc "*Source: https://help.autodesk.com/*")))))

(deftest
  "documentation rejects unsupported doc types"
  (function
    (lambda ()
      (is-equal nil (documentation 'open 'variable)))))

(deftest
  "describe uses documentation for documented symbols"
  (function
    (lambda (/ ad-text)
      (setq ad-text (CL:doc--object-description 'open))
      (is (wcmatch ad-text "*open (AutoLISP)*"))
      (is (wcmatch ad-text "*Return values:*")))))

(deftest
  "describe handles ordinary lists"
  (function
    (lambda (/ ad-text)
      (setq ad-text (CL:doc--object-description '(1 2 3)))
      (is (wcmatch ad-text "*List object*"))
      (is (wcmatch ad-text "*Length: 3*")))))

(deftest
  "apropos-list returns matching symbols"
  (function
    (lambda (/ ad-result)
      (setq ad-result (apropos-list "open"))
      (is ad-result)
      (is (member 'OPEN ad-result)))))

(deftest
  "apropos wildcard finds string functions"
  (function
    (lambda (/ ad-result)
      (setq ad-result (apropos-list "str*"))
      (is ad-result)
      (is (member 'STRCAT ad-result)))))

(deftest
  "apropos summary line includes name and summary"
  (function
    (lambda (/ ad-line)
      (setq ad-line (CL:doc--summary-line (CL:doc--entry 'open)))
      (is (wcmatch ad-line "open --*")))))

(deftest
  "help index returns public help symbols"
  (function
    (lambda (/ ad-result)
      (setq ad-result (help))
      (is (member 'HELP ad-result))
      (is (member 'DOCUMENTATION ad-result))
      (is (member 'APROPOS ad-result)))))

(deftest
  "help text search returns matching symbols"
  (function
    (lambda (/ ad-result)
      (setq ad-result (help "unicode"))
      (is ad-result)
      (is (member 'OPEN ad-result)))))

(deftest
  "text search scans documentation body"
  (function
    (lambda (/ ad-results ad-names)
      (setq ad-results (CL:doc--text-search "byte order marks"))
      (setq ad-names (mapcar '(lambda (ad-entry) (CL:doc--assoc-value 'name ad-entry))
                             ad-results))
      (is (member "open" ad-names)))))

(deftest
  "categorize collects source families from called functions"
  (function
    (lambda (/ ad-cats)
      (setq ad-cats
            (ad-categorize
              '(defun demo (x / d)
                 (setq d (load_dialog "demo.dcl"))
                 (action_tile "accept" "(done_dialog 1)")
                 (vl-load-com)
                 (vla-get-ActiveDocument (vlax-get-acad-object))
                 (alert x))))
      (is (member 'AUTOLISP ad-cats))
      (is (member 'AUTOLISP/DCL ad-cats))
      (is (member 'AUTOLISP/ACTIVE-X ad-cats)))))

(deftest
  "free variables excludes parameters and locals"
  (function
    (lambda (/ ad-vars)
      (setq ad-vars
            (ad-free-variables
              '(defun demo (a / b)
                 (setq b (+ a x))
                 (foreach item items
                   (setq z (+ item y b)))
                 (list a b z x y items))))
      (is (member 'X ad-vars))
      (is (member 'Y ad-vars))
      (is (member 'Z ad-vars))
      (is (member 'ITEMS ad-vars))
      (is-not (member 'A ad-vars))
      (is-not (member 'B ad-vars))
      (is-not (member 'ITEM ad-vars)))))

(deftest
  "ad aliases reuse public API"
  (function
    (lambda ()
      (is-equal (documentation 'open 'function)
                (ad-documentation 'open 'function))
      (is-equal (apropos-list "open")
                (ad-apropos-list "open"))
      (is-equal (ad-categorize '(alert "hi"))
                (categorize '(alert "hi")))
      (is-equal (ad-free-variables '(+ x y))
                (free-variables '(+ x y))))))
