;;; autolisp-doc.lsp --- Documentation helpers backed by *autolisp-reference*

(vl-load-com)

(setq *CL:HELP-ENTRIES*
  '(
    ("DOCUMENTATION" .
      ((name . "documentation")
       (title . "documentation")
       (summary . "Returns a formatted documentation string for a documented symbol.")
       (feature-groups . ("Help"))
       (signature . "(documentation symbol doc-type)")
       (return-values . "Type: String or nil\nA documentation string when the symbol is documented and doc-type is T or FUNCTION; otherwise nil.")
       (examples . "(documentation 'open 'function)")
       (url . nil)))
    ("DESCRIBE" .
      ((name . "describe")
       (title . "describe")
       (summary . "Prints a human-readable description of an AutoLISP object.")
       (feature-groups . ("Help"))
       (signature . "(describe object)")
       (return-values . "Type: Object\nReturns the object after printing its description.")
       (examples . "(describe 'open)\n(describe '(1 2 3))")
       (url . nil)))
    ("APROPOS" .
      ((name . "apropos")
       (title . "apropos")
       (summary . "Prints a summary line for each documented function whose name matches a simplified wildcard pattern.")
       (feature-groups . ("Help"))
       (signature . "(apropos pattern)")
       (return-values . "Type: List\nReturns the list of matching symbols.")
       (examples . "(apropos \"str*\")")
       (url . nil)))
    ("APROPOS-LIST" .
      ((name . "apropos-list")
       (title . "apropos-list")
       (summary . "Returns the documented symbols whose names match a simplified wildcard pattern.")
       (feature-groups . ("Help"))
       (signature . "(apropos-list pattern)")
       (return-values . "Type: List\nReturns the list of matching symbols without printing summaries.")
       (examples . "(apropos-list \"get*\")")
       (url . nil)))
    ("HELP" .
      ((name . "help")
       (title . "help")
       (summary . "Entry point for help commands, name search, and documentation text search.")
       (feature-groups . ("Help"))
       (signature . "(help [arg])")
       (return-values . "Type: List or Object\nReturns a list of matching symbols for searches, or the described object.")
       (examples . "(help)\n(help 'open)\n(help \"unicode\")")
       (url . nil)))
    ("AD-CATEGORIZE" .
      ((name . "ad-categorize")
       (title . "ad-categorize")
       (summary . "Analyzes a Lisp form and returns the source categories implied by the documented functions it calls.")
       (feature-groups . ("Help" "Analysis"))
       (signature . "(ad-categorize form)")
       (return-values . "Type: List\nReturns a list such as (AUTOLISP AUTOLISP/DCL AUTOLISP/ACTIVE-X).")
       (examples . "(ad-categorize '(defun c:test () (action_tile \"k\" \"\") (vl-load-com) (alert \"hi\")))")
       (url . nil)))
    ("CATEGORIZE" .
      ((name . "categorize")
       (title . "categorize")
       (summary . "Alias of ad-categorize.")
       (feature-groups . ("Help" "Analysis"))
       (signature . "(categorize form)")
       (return-values . "Type: List\nSame result as ad-categorize.")
       (examples . "(categorize form)")
       (url . nil)))
    ("AD-FREE-VARIABLES" .
      ((name . "ad-free-variables")
       (title . "ad-free-variables")
       (summary . "Returns the symbols used in a form that are not bound locally or passed as parameters.")
       (feature-groups . ("Help" "Analysis"))
       (signature . "(ad-free-variables form)")
       (return-values . "Type: List\nReturns a list such as (X Y Z).")
       (examples . "(ad-free-variables '(defun foo (a / b) (setq b (+ a x)) (+ b y)))")
       (url . nil)))
    ("FREE-VARIABLES" .
      ((name . "free-variables")
       (title . "free-variables")
       (summary . "Alias of ad-free-variables.")
       (feature-groups . ("Help" "Analysis"))
       (signature . "(free-variables form)")
       (return-values . "Type: List\nSame result as ad-free-variables.")
       (examples . "(free-variables form)")
       (url . nil)))
    ("AD-DOCUMENTATION" .
      ((name . "ad-documentation")
       (title . "ad-documentation")
       (summary . "Alias of documentation.")
       (feature-groups . ("Help"))
       (signature . "(ad-documentation symbol doc-type)")
       (return-values . "Type: String or nil\nSame result as documentation.")
       (examples . "(ad-documentation 'open 'function)")
       (url . nil)))
    ("AD-DESCRIBE" .
      ((name . "ad-describe")
       (title . "ad-describe")
       (summary . "Alias of describe.")
       (feature-groups . ("Help"))
       (signature . "(ad-describe object)")
       (return-values . "Type: Object\nSame result as describe.")
       (examples . "(ad-describe 'open)")
       (url . nil)))
    ("AD-APROPOS" .
      ((name . "ad-apropos")
       (title . "ad-apropos")
       (summary . "Alias of apropos.")
       (feature-groups . ("Help"))
       (signature . "(ad-apropos pattern)")
       (return-values . "Type: List\nSame result as apropos.")
       (examples . "(ad-apropos \"str*\")")
       (url . nil)))
    ("AD-APROPOS-LIST" .
      ((name . "ad-apropos-list")
       (title . "ad-apropos-list")
       (summary . "Alias of apropos-list.")
       (feature-groups . ("Help"))
       (signature . "(ad-apropos-list pattern)")
       (return-values . "Type: List\nSame result as apropos-list.")
       (examples . "(ad-apropos-list \"open\")")
       (url . nil)))
    ("AD-HELP" .
      ((name . "ad-help")
       (title . "ad-help")
       (summary . "Alias of help.")
       (feature-groups . ("Help"))
       (signature . "(ad-help [arg])")
       (return-values . "Type: List or Object\nSame result as help.")
       (examples . "(ad-help)\n(ad-help 'open)")
       (url . nil)))))

(defun CL:doc--string-empty-p (cl:value)
  (or (null cl:value)
      (= cl:value "")))

(defun CL:doc--stringify (cl:value)
  (cond
    ((null cl:value) nil)
    ((= (type cl:value) 'STR) cl:value)
    ((= (type cl:value) 'SYM) (vl-symbol-name cl:value))
    (T (vl-princ-to-string cl:value))))

(defun CL:doc--upcase (cl:text)
  (if cl:text
    (strcase cl:text)
    ""))

(defun CL:doc--contains-wildcards-p (cl:pattern)
  (or (wcmatch cl:pattern "*`**")
      (wcmatch cl:pattern "*`?*")))

(defun CL:doc--normalize-pattern (cl:pattern)
  (setq cl:pattern (CL:doc--upcase (CL:doc--stringify cl:pattern)))
  (if (CL:doc--string-empty-p cl:pattern)
    "*"
    (if (CL:doc--contains-wildcards-p cl:pattern)
      cl:pattern
      (strcat "*" cl:pattern "*"))))

(defun CL:doc--match-p (cl:text cl:pattern)
  (wcmatch (CL:doc--upcase (CL:doc--stringify cl:text))
           (CL:doc--normalize-pattern cl:pattern)))

(defun CL:doc--substring-match-p (cl:text cl:pattern)
  (not (null (vl-string-search (CL:doc--upcase (CL:doc--stringify cl:pattern))
                               (CL:doc--upcase (CL:doc--stringify cl:text))))))

(defun CL:doc--assoc-value (cl:key cl:alist)
  (cdr (assoc cl:key cl:alist)))

(defun CL:doc--entry (cl:name / cl:key)
  (setq cl:key (CL:doc--stringify cl:name))
  (cond
    ((null cl:key) nil)
    ((assoc cl:key *CL:HELP-ENTRIES*) (cdr (assoc cl:key *CL:HELP-ENTRIES*)))
    ((assoc cl:key *autolisp-reference*) (cdr (assoc cl:key *autolisp-reference*)))
    ((assoc (strcase cl:key) *CL:HELP-ENTRIES*) (cdr (assoc (strcase cl:key) *CL:HELP-ENTRIES*)))
    ((assoc (strcase cl:key) *autolisp-reference*) (cdr (assoc (strcase cl:key) *autolisp-reference*)))
    ((assoc (strcase cl:key T) *CL:HELP-ENTRIES*) (cdr (assoc (strcase cl:key T) *CL:HELP-ENTRIES*)))
    ((assoc (strcase cl:key T) *autolisp-reference*) (cdr (assoc (strcase cl:key T) *autolisp-reference*)))
    (T nil)))

(defun CL:doc--database ()
  (append *CL:HELP-ENTRIES* *autolisp-reference*))

(defun CL:doc--join-paragraphs (cl:parts / cl:clean cl:result)
  (setq cl:clean nil)
  (foreach cl:part cl:parts
    (if (not (CL:doc--string-empty-p cl:part))
      (setq cl:clean (cons cl:part cl:clean))))
  (setq cl:clean (reverse cl:clean))
  (setq cl:result "")
  (foreach cl:part cl:clean
    (setq cl:result
          (strcat cl:result
                  (if (= cl:result "") "" "\n\n")
                  cl:part)))
  cl:result)

(defun CL:doc--format-arguments (cl:arguments / cl:result)
  (setq cl:result nil)
  (foreach cl:item cl:arguments
    (setq cl:result
          (cons
            (strcat (car cl:item) ": "
                    (if (cdr cl:item) (cdr cl:item) ""))
            cl:result)))
  (setq cl:result (reverse cl:result))
  (if cl:result
    (CL:doc--join-paragraphs cl:result)
    nil))

(defun CL:doc--format-entry (cl:entry / cl:features cl:feature-text cl:args)
  (setq cl:features (CL:doc--assoc-value 'feature-groups cl:entry))
  (setq cl:feature-text
        (if cl:features
          (apply 'strcat
                 (cons (car cl:features)
                       (mapcar '(lambda (cl:item) (strcat ", " cl:item))
                               (cdr cl:features))))
          nil))
  (setq cl:args (CL:doc--format-arguments (CL:doc--assoc-value 'arguments cl:entry)))
  (CL:doc--join-paragraphs
    (list
      (CL:doc--assoc-value 'title cl:entry)
      (CL:doc--assoc-value 'summary cl:entry)
      (if cl:feature-text (strcat "Features: " cl:feature-text) nil)
      (if (CL:doc--assoc-value 'supported-platforms cl:entry)
        (strcat "Platforms: " (CL:doc--assoc-value 'supported-platforms cl:entry))
        nil)
      (if (CL:doc--assoc-value 'signature cl:entry)
        (strcat "Signature:\n" (CL:doc--assoc-value 'signature cl:entry))
        nil)
      (if cl:args
        (strcat "Arguments:\n" cl:args)
        nil)
      (if (CL:doc--assoc-value 'return-values cl:entry)
        (strcat "Return values:\n" (CL:doc--assoc-value 'return-values cl:entry))
        nil)
      (if (CL:doc--assoc-value 'history cl:entry)
        (strcat "History:\n" (CL:doc--assoc-value 'history cl:entry))
        nil)
      (if (CL:doc--assoc-value 'examples cl:entry)
        (strcat "Examples:\n" (CL:doc--assoc-value 'examples cl:entry))
        nil)
      (if (CL:doc--assoc-value 'url cl:entry)
        (strcat "Source: " (CL:doc--assoc-value 'url cl:entry))
        nil))))

(defun CL:doc--summary-line (cl:entry)
  (strcat
    (if (CL:doc--assoc-value 'name cl:entry)
      (CL:doc--assoc-value 'name cl:entry)
      "<unnamed>")
    (if (CL:doc--assoc-value 'summary cl:entry)
      (strcat " -- " (CL:doc--assoc-value 'summary cl:entry))
      "")))

(defun CL:doc--sort-strings (cl:strings)
  (vl-sort cl:strings
           '(lambda (cl:left cl:right)
              (< (strcmp (strcase cl:left) (strcase cl:right)) 0))))

(defun CL:doc--read-symbol (cl:name)
  (read cl:name))

(defun ad--pushnew (ad-item ad-list)
  (if (member ad-item ad-list)
    ad-list
    (append ad-list (list ad-item))))

(defun ad--quoted-lambda-p (ad-form)
  (and (= (type ad-form) 'LIST)
       ad-form
       (or (eq (car ad-form) 'LAMBDA)
           (eq (car ad-form) 'lambda))))

(defun ad--bound-vars-from-lambda-list (ad-lambda-list / ad-vars)
  (setq ad-vars nil)
  (foreach ad-item ad-lambda-list
    (if (and (= (type ad-item) 'SYM)
             (not (eq ad-item '/)))
      (setq ad-vars (ad--pushnew ad-item ad-vars))))
  ad-vars)

(defun ad--constant-symbol-p (ad-symbol / ad-name)
  (setq ad-name (vl-symbol-name ad-symbol))
  (or (eq ad-symbol T)
      (eq ad-symbol 'T)
      (eq ad-symbol 'NIL)
      (eq ad-symbol '/)
      (= ad-name "NIL")
      (wcmatch ad-name ":*")))

(defun ad--source-kind-symbol (ad-source-kind)
  (cond
    ((= ad-source-kind "AutoLISP") 'autolisp)
    ((= ad-source-kind "AutoLISP/DCL") 'autolisp/dcl)
    ((= ad-source-kind "AutoLISP/ActiveX") 'autolisp/active-x)
    ((= ad-source-kind "AutoLISP/Visual LISP IDE") 'autolisp/visual-lisp-ide)
    (T nil)))

(defun ad--categorize-called-symbol (ad-symbol ad-categories / ad-entry ad-category)
  (setq ad-entry (CL:doc--entry ad-symbol))
  (if ad-entry
    (progn
      (setq ad-category (ad--source-kind-symbol (CL:doc--assoc-value 'source-kind ad-entry)))
      (if ad-category
        (setq ad-categories (ad--pushnew ad-category ad-categories)))))
  ad-categories)

(defun ad--categorize-form-list (ad-forms ad-categories)
  (foreach ad-form ad-forms
    (setq ad-categories (ad--categorize-form ad-form ad-categories)))
  ad-categories)

(defun ad--categorize-form (ad-form ad-categories / ad-head)
  (cond
    ((or (null ad-form)
         (/= (type ad-form) 'LIST))
     ad-categories)
    ((null (car ad-form))
     (ad--categorize-form-list ad-form ad-categories))
    (T
     (setq ad-head (car ad-form))
     (cond
       ((or (eq ad-head 'QUOTE)
            (eq ad-head 'quote))
        (if (and (> (length ad-form) 1)
                 (ad--quoted-lambda-p (cadr ad-form)))
          (ad--categorize-form (cadr ad-form) ad-categories)
          ad-categories))
       ((or (eq ad-head 'FUNCTION)
            (eq ad-head 'function))
        (if (> (length ad-form) 1)
          (if (= (type (cadr ad-form)) 'SYM)
            (ad--categorize-called-symbol (cadr ad-form) ad-categories)
            (ad--categorize-form (cadr ad-form) ad-categories))
          ad-categories))
       ((or (eq ad-head 'DEFUN)
            (eq ad-head 'defun))
        (ad--categorize-form-list (cdddr ad-form) ad-categories))
       ((or (eq ad-head 'LAMBDA)
            (eq ad-head 'lambda))
        (ad--categorize-form-list (cddr ad-form) ad-categories))
       (T
        (if (= (type ad-head) 'SYM)
          (setq ad-categories
                (ad--categorize-called-symbol ad-head ad-categories)))
        (ad--categorize-form-list (cdr ad-form) ad-categories))))))

(defun ad-categorize (ad-form)
  (ad--categorize-form ad-form nil))

(defun categorize (ad-form)
  (ad-categorize ad-form))

(defun ad--free-variable-symbol (ad-symbol ad-bound ad-result)
  (if (or (ad--constant-symbol-p ad-symbol)
          (member ad-symbol ad-bound))
    ad-result
    (ad--pushnew ad-symbol ad-result)))

(defun ad--free-vars-form-list (ad-forms ad-bound ad-result)
  (foreach ad-form ad-forms
    (setq ad-result (ad--free-vars-form ad-form ad-bound ad-result)))
  ad-result)

(defun ad--free-vars-quoted (ad-form ad-bound ad-result)
  (if (ad--quoted-lambda-p ad-form)
    (ad--free-vars-form ad-form ad-bound ad-result)
    ad-result))

(defun ad--free-vars-setq (ad-pairs ad-bound ad-result / ad-var ad-expr)
  (while ad-pairs
    (setq ad-var (car ad-pairs))
    (setq ad-expr (cadr ad-pairs))
    (if (= (type ad-var) 'SYM)
      (setq ad-result (ad--free-variable-symbol ad-var ad-bound ad-result)))
    (setq ad-result (ad--free-vars-form ad-expr ad-bound ad-result))
    (setq ad-pairs (cddr ad-pairs)))
  ad-result)

(defun ad--free-vars-form (ad-form ad-bound ad-result / ad-head ad-locals ad-var)
  (cond
    ((null ad-form) ad-result)
    ((= (type ad-form) 'SYM)
     (ad--free-variable-symbol ad-form ad-bound ad-result))
    ((/= (type ad-form) 'LIST)
     ad-result)
    ((null ad-form)
     ad-result)
    (T
     (setq ad-head (car ad-form))
     (cond
       ((or (eq ad-head 'QUOTE)
            (eq ad-head 'quote))
        (if (> (length ad-form) 1)
          (ad--free-vars-quoted (cadr ad-form) ad-bound ad-result)
          ad-result))
       ((or (eq ad-head 'FUNCTION)
            (eq ad-head 'function))
        (if (> (length ad-form) 1)
          (if (ad--quoted-lambda-p (cadr ad-form))
            (ad--free-vars-form (cadr ad-form) ad-bound ad-result)
            ad-result)
          ad-result))
       ((or (eq ad-head 'DEFUN)
            (eq ad-head 'defun))
        (setq ad-locals (ad--bound-vars-from-lambda-list (caddr ad-form)))
        (ad--free-vars-form-list (cdddr ad-form)
                                 (append ad-bound ad-locals)
                                 ad-result))
       ((or (eq ad-head 'LAMBDA)
            (eq ad-head 'lambda))
        (setq ad-locals (ad--bound-vars-from-lambda-list (cadr ad-form)))
        (ad--free-vars-form-list (cddr ad-form)
                                 (append ad-bound ad-locals)
                                 ad-result))
       ((or (eq ad-head 'FOREACH)
            (eq ad-head 'foreach))
        (setq ad-var (cadr ad-form))
        (setq ad-result (ad--free-vars-form (caddr ad-form) ad-bound ad-result))
        (ad--free-vars-form-list (cdddr ad-form)
                                 (if (= (type ad-var) 'SYM)
                                   (append ad-bound (list ad-var))
                                   ad-bound)
                                 ad-result))
       ((or (eq ad-head 'SETQ)
            (eq ad-head 'setq))
        (ad--free-vars-setq (cdr ad-form) ad-bound ad-result))
       (T
        (ad--free-vars-form-list (cdr ad-form) ad-bound ad-result))))))

(defun ad-free-variables (ad-form)
  (ad--free-vars-form ad-form nil nil))

(defun free-variables (ad-form)
  (ad-free-variables ad-form))

(defun CL:doc--documentation-type-supported-p (cl:doc-type)
  (or (null cl:doc-type)
      (eq cl:doc-type T)
      (eq cl:doc-type 'FUNCTION)
      (eq cl:doc-type 'function)))

(defun documentation (cl:symbol cl:doc-type / cl:entry)
  (if (not (CL:doc--documentation-type-supported-p cl:doc-type))
    nil
    (progn
      (setq cl:entry (CL:doc--entry cl:symbol))
      (if cl:entry
        (CL:doc--format-entry cl:entry)
        nil))))

(defun ad-documentation (ad-symbol ad-doc-type)
  (documentation ad-symbol ad-doc-type))

(defun CL:doc--object-description (cl:object / cl:type)
  (setq cl:type (type cl:object))
  (cond
    ((= cl:type 'SYM)
     (cond
       ((CL:doc--entry cl:object)
        (documentation cl:object 'function))
       ((boundp cl:object)
        (CL:doc--join-paragraphs
          (list
            (strcat "Symbol " (vl-symbol-name cl:object))
            (strcat "Value:\n" (vl-princ-to-string (eval cl:object)))
            (strcat "Type of value: " (vl-princ-to-string (type (eval cl:object)))))))
       (T
        (strcat "Symbol " (vl-symbol-name cl:object) " is unbound and undocumented."))))
    ((= cl:type 'LIST)
     (CL:doc--join-paragraphs
       (list
         "List object"
         (strcat "Length: " (itoa (length cl:object)))
         (strcat "Printed form:\n" (vl-princ-to-string cl:object)))))
    (T
     (CL:doc--join-paragraphs
       (list
         (strcat "Object type: " (vl-princ-to-string cl:type))
         (strcat "Printed form:\n" (vl-princ-to-string cl:object)))))))

(defun describe (cl:object / cl:text)
  (setq cl:text (CL:doc--object-description cl:object))
  (if cl:text
    (progn
      (princ cl:text)
      (terpri)))
  cl:object)

(defun ad-describe (ad-object)
  (describe ad-object))

(defun CL:doc--apropos-matches (cl:pattern / cl:results)
  (setq cl:results nil)
  (foreach cl:item (CL:doc--database)
    (if (CL:doc--match-p (car cl:item) cl:pattern)
      (setq cl:results (cons (car cl:item) cl:results))))
  (CL:doc--sort-strings cl:results))

(defun apropos-list (cl:pattern / cl:names)
  (setq cl:names (CL:doc--apropos-matches cl:pattern))
  (mapcar 'CL:doc--read-symbol cl:names))

(defun ad-apropos-list (ad-pattern)
  (apropos-list ad-pattern))

(defun apropos (cl:pattern / cl:names cl:entry)
  (setq cl:names (CL:doc--apropos-matches cl:pattern))
  (if cl:names
    (foreach cl:name cl:names
      (setq cl:entry (CL:doc--entry cl:name))
      (princ (CL:doc--summary-line cl:entry))
      (terpri))
    (progn
      (princ "No documented function matches.")
      (terpri)))
  (mapcar 'CL:doc--read-symbol cl:names))

(defun ad-apropos (ad-pattern)
  (apropos ad-pattern))

(defun CL:doc--entry-text (cl:entry)
  (CL:doc--join-paragraphs
    (list
      (CL:doc--assoc-value 'name cl:entry)
      (CL:doc--assoc-value 'title cl:entry)
      (CL:doc--assoc-value 'summary cl:entry)
      (CL:doc--assoc-value 'signature cl:entry)
      (CL:doc--format-arguments (CL:doc--assoc-value 'arguments cl:entry))
      (CL:doc--assoc-value 'return-values cl:entry)
      (CL:doc--assoc-value 'history cl:entry)
      (CL:doc--assoc-value 'examples cl:entry)
      (CL:doc--assoc-value 'url cl:entry))))

(defun CL:doc--text-search (cl:pattern / cl:results cl:entry cl:raw-pattern)
  (setq cl:results nil)
  (setq cl:raw-pattern (CL:doc--stringify cl:pattern))
  (foreach cl:item (CL:doc--database)
    (setq cl:entry (cdr cl:item))
    (if (if (CL:doc--contains-wildcards-p (CL:doc--upcase cl:raw-pattern))
          (CL:doc--match-p (CL:doc--entry-text cl:entry) cl:pattern)
          (CL:doc--substring-match-p (CL:doc--entry-text cl:entry) cl:pattern))
      (setq cl:results (cons cl:entry cl:results))))
  (vl-sort cl:results
           '(lambda (cl:left cl:right)
              (< (strcmp (strcase (CL:doc--assoc-value 'name cl:left))
                         (strcase (CL:doc--assoc-value 'name cl:right)))
                 0))))

(defun CL:doc--print-help-index ()
  (foreach cl:line
           '("Help functions:"
             "  (help)                 List help entry points."
             "  (help 'symbol)         Search documented functions by name."
             "  (help \"text\")         Search text across the documentation database."
             "  (documentation 'f 'function)"
             "  (describe object)"
             "  (apropos pattern)"
             "  (apropos-list pattern)"
             ""
             "Planned:"
             "  inspect"))
    (princ cl:line)
    (terpri)))

(defun help (cl:arg / cl:matches)
  (cond
    ((null cl:arg)
     (CL:doc--print-help-index)
     '(help documentation describe apropos apropos-list inspect))
    ((= (type cl:arg) 'SYM)
     (apropos (vl-symbol-name cl:arg)))
    ((= (type cl:arg) 'STR)
     (setq cl:matches (CL:doc--text-search cl:arg))
     (if cl:matches
       (foreach cl:entry cl:matches
         (princ (CL:doc--summary-line cl:entry))
         (terpri))
       (progn
         (princ "No documentation text matches.")
         (terpri)))
     (mapcar '(lambda (cl:entry) (CL:doc--read-symbol (CL:doc--assoc-value 'name cl:entry)))
             cl:matches))
    (T
     (describe cl:arg))))

(defun ad-help (ad-arg)
  (help ad-arg))

(princ)

;;; autolisp-doc.lsp ends here
