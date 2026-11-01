;; Charger test-runner.lsp avant cette suite, puis executer C:MAIN.
;; FUNCTION produit un objet natif sur BricsCAD : ne pas le reconvertir en forme.
(defun tu:test-thunk-nomme () 42)
(defsuite "harnais-thunks")
(in-suite "harnais-thunks")
(deftest "fonction native nommee"
  (function (lambda ()
    (is-equal 42 (t:call-thunk (function tu:test-thunk-nomme)) nil))))
(deftest "lambda native"
  (function (lambda ()
    (is-equal 42 (t:call-thunk (function (lambda () 42))) nil))))
(deftest "lambda citee"
  (function (lambda ()
    (is-equal 42 (t:call-thunk '(lambda () 42)) nil))))
(deftest "symbole de fonction"
  (function (lambda ()
    (is-equal 42 (t:call-thunk 'tu:test-thunk-nomme) nil))))
(princ "")
