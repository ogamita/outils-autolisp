(vl-load-com)

;; ================================================================
;; Minimal test framework for AutoLISP / Visual LISP
;; Suites + Tests + Assertions + Runner
;; ================================================================

(setq *t:suites* nil)
(setq *t:current-suite* "default")
(setq *t:last-total* 0)
(setq *t:last-ok* 0)
(setq *t:last-fail* 0)
(setq *t:last-error* 0)

(defun t:write-line-to (path s / f)
  (if (and path (/= path ""))
    (progn
      (setq f (open path "a"))
      (if f
        (progn
          (write-line s f)
          (close f))))))

(defun t:path (name / v)
  (setq v (getenv name))
  (if (or (null v) (= v ""))
    (cond
      ((= name "OUTFILE") *AUTOLISP_OUTFILE*)
      ((= name "ERRFILE") *AUTOLISP_ERRFILE*)
      (t nil))
    v))

(defun t:emit-out (s)
  (print s)
  (t:write-line-to (t:path "OUTFILE") (vl-princ-to-string s)))

(defun t:emit-err (s)
  (print s)
  (t:write-line-to (t:path "ERRFILE") (vl-princ-to-string s)))

(defun t:ensure-suite (name / cell)
  (setq cell (assoc name *t:suites*))
  (if cell
    cell
    (progn
      (setq *t:suites*
            (cons (cons name nil)
                  *t:suites*))
      (assoc name *t:suites*))))

(defun defsuite (name)
  (t:ensure-suite name)
  name)

(defun in-suite (name)
  (t:ensure-suite name)
  (setq *t:current-suite* name)
  name)

(defun t:replace-suite-tests (suite-name new-tests / out done pair)
  (setq out nil)
  (setq done nil)
  (foreach pair *t:suites*
    (if (and (not done) (= (car pair) suite-name))
      (progn
        (setq out (cons (cons suite-name new-tests) out))
        (setq done t))
      (setq out (cons pair out))))
  (if (not done)
    (setq out (cons (cons suite-name new-tests) out)))
  (setq *t:suites* (reverse out)))

(defun t:add-test (suite-name test-name fn / cell tests)
  (setq cell (t:ensure-suite suite-name))
  (setq tests (cdr cell))
  (t:replace-suite-tests
    suite-name
    (cons (list test-name fn) tests))
  test-name)

(defun deftest (name fn)
  ;; name: string
  ;; fn: (function (lambda () ...))
  (t:add-test *t:current-suite* name fn))

;; -----------------------------
;; Formatting helpers
;; -----------------------------

(defun t:str (x)
  (vl-princ-to-string x))

(defun t:fail (msg /)
  (error (strcat "TEST-FAIL: " msg)))

(defun t:format-compare (label expected actual)
  (strcat label
          " expected="
          (t:str expected)
          " actual="
          (t:str actual)))

;; -----------------------------
;; Assertions
;; -----------------------------

(defun is (condition msg)
  (if (not condition)
    (t:fail (if msg msg "is: condition is false")))
  t)

(defun is-not (condition msg)
  (if condition
    (t:fail (if msg msg "is-not: condition is true")))
  t)

(defun is-equal (expected actual msg)
  (if (not (equal expected actual))
    (t:fail (if msg
              msg
              (t:format-compare "is-equal:" expected actual))))
  t)

(defun is-approx (expected actual tol msg)
  ;; numeric approximate equality
  (if (not (equal expected actual tol))
    (t:fail (if msg
              msg
              (strcat "is-approx:"
                      " expected="
                      (t:str expected)
                      " actual="
                      (t:str actual)
                      " tol="
                      (t:str tol)))))
  t)

(defun signals-error (thunk msg)
  ;; thunk: (function (lambda () ...))
  (setq thunk (cond ((= (type thunk) 'USUBR) thunk)
                    ((= (type thunk) 'SUBR)  thunk)
                    (t thunk)))
  (setq msg (if msg msg "signals-error: expected an error"))
  (let ((r (vl-catch-all-apply thunk nil)))
    (if (vl-catch-all-error-p r)
      t
      (t:fail msg))))

;; -----------------------------
;; Runner + report
;; -----------------------------

(defun t:run-test (suite-name test / name fn r em is-fail)
  (setq name (car test))
  (setq fn   (cadr test))

  (setq r (vl-catch-all-apply fn nil))

  (cond
    ((vl-catch-all-error-p r)
     ;; distinguish FAIL (our t:fail uses error with prefix) from ERROR
     (setq em (vl-catch-all-error-message r))
     (setq is-fail (and em (wcmatch em "TEST-FAIL:*")))
     (if is-fail
       (list :fail suite-name name em)
       (list :error suite-name name em)))
    (t
     (list :ok suite-name name nil))))

(defun t:print-result (res / status suite name msg)
  (setq status (car res))
  (setq suite  (cadr res))
  (setq name   (caddr res))
  (setq msg    (cadddr res))

  (cond
    ((eq status :ok)
     (t:emit-out (strcat "OK    [" suite "] " name)))
    ((eq status :fail)
     (t:emit-err (strcat "FAIL  [" suite "] " name " -- " msg)))
    (t
     (t:emit-err (strcat "ERROR [" suite "] " name " -- " msg)))))

(defun run-suite (suite-name / cell tests total ok fail err res)
  (setq cell (assoc suite-name *t:suites*))
  (if (null cell)
    (progn
      (prompt (strcat "\n[run-suite] Unknown suite: " suite-name))
      nil)
    (progn
      (setq tests (reverse (cdr cell))) ;; preserve definition order
      (setq total 0)
      (setq ok 0)
      (setq fail 0)
      (setq err 0)

      (foreach test tests
        (setq total (1+ total))
        (setq res (t:run-test suite-name test))
        (t:print-result res)
        (cond
          ((eq (car res) :ok)    (setq ok (1+ ok)))
          ((eq (car res) :fail)  (setq fail (1+ fail)))
          (t                     (setq err (1+ err)))))

      (t:emit-out (strcat "---- Suite [" suite-name "] ----"))
      (t:emit-out (strcat "Total: " (itoa total)
                          "  OK: " (itoa ok)
                          "  FAIL: " (itoa fail)
                          "  ERROR: " (itoa err)))
      (setq *t:last-total* (+ *t:last-total* total))
      (setq *t:last-ok* (+ *t:last-ok* ok))
      (setq *t:last-fail* (+ *t:last-fail* fail))
      (setq *t:last-error* (+ *t:last-error* err))
      (list :suite suite-name :total total :ok ok :fail fail :error err))))

(defun run-all (/ s summaries)
  (setq *t:last-total* 0)
  (setq *t:last-ok* 0)
  (setq *t:last-fail* 0)
  (setq *t:last-error* 0)
  (setq summaries nil)
  (foreach s *t:suites*
    (setq summaries (cons (run-suite (car s)) summaries)))
  (reverse summaries))
