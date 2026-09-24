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

;; Résultats accumulés pour le rapport JUnit : liste, en ordre inverse, de
;; (NOM-DE-SUITE DURÉE-EN-SECONDES RÉSULTATS). Voir « Rapport JUnit » plus bas.
(setq *t:junit-suites* nil)
(setq *t:junit-file* nil)

;; AutoLISP has no real keywords: :foo is just a symbol named ":FOO" that
;; evaluates to NIL by default on every engine (BricsCAD, AutoCAD,
;; clautolisp). Bind each marker used below to itself so that result
;; records (list :ok ...) and their dispatch (eq (car res) :ok), as well
;; as the suite summary keys, behave as distinct self-evaluating tags
;; instead of all collapsing to NIL (which would count every test OK).
(setq :ok    ':ok)
(setq :fail  ':fail)
(setq :error ':error)
(setq :suite ':suite)
(setq :total ':total)

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
  (princ s) (terpri)
  (t:write-line-to (t:path "OUTFILE") (vl-princ-to-string s)))

(defun t:emit-err (s)
  (princ s) (terpri)
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

;; Horloge en millisecondes (variable système MILLISECS : AutoCAD, BricsCAD,
;; clautolisp). Rend nil si l'hôte ne la fournit pas : les durées valent alors 0.
(defun t:millisecs (/ ms)
  (setq ms (vl-catch-all-apply (function getvar) (list "MILLISECS")))
  (if (numberp ms) ms nil))

(defun t:elapsed (start / now)
  (setq now (t:millisecs))
  (if (and start now)
    (/ (- now start) 1000.0)
    0.0))

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

(defun signals-error (thunk msg / r)
  ;; thunk: (function (lambda () ...))
  ;; NB: pas de `let` ici — ce n'est pas de l'AutoLISP portable (indéfini
  ;; sous clautolisp, tous dialectes) ; on utilise une variable locale.
  (setq thunk (cond ((= (type thunk) 'USUBR) thunk)
                    ((= (type thunk) 'SUBR)  thunk)
                    (t thunk)))
  (setq msg (if msg msg "signals-error: expected an error"))
  (setq r (vl-catch-all-apply thunk nil))
  (if (vl-catch-all-error-p r)
    t
    (t:fail msg)))

;; -----------------------------
;; Exit status (portable)
;; -----------------------------

;; autolisp-set-status est fournie soit par le bootstrap file-IPC d'alfe sur
;; les CAO (BricsCAD/AutoCAD), soit comme extension clautolisp (dialectes
;; lax / clautolisp). Sous clautolisp on bascule temporairement *AUTOLISP-DIALECT*
;; en lax autour de l'appel (sinon warning « hors dialecte » en strict) puis on
;; restaure. Ailleurs (CAO), on appelle directement.
(defun t:set-status (code / saved)
  (if (boundp '*autolisp-dialect*)
    (progn
      (setq saved *autolisp-dialect*)
      (setq *autolisp-dialect* 'lax)
      (autolisp-set-status code)
      (setq *autolisp-dialect* saved))
    (autolisp-set-status code)))

;; -----------------------------
;; Runner + report
;; -----------------------------

(defun t:run-test (suite-name test / name fn r em is-fail start secs)
  (setq name (car test))
  (setq fn   (cadr test))

  (setq start (t:millisecs))
  (setq r (vl-catch-all-apply fn nil))
  (setq secs (t:elapsed start))

  ;; Résultat : (STATUT SUITE NOM MESSAGE DURÉE-EN-SECONDES).
  (cond
    ((vl-catch-all-error-p r)
     ;; distinguish FAIL (our t:fail uses error with prefix) from ERROR
     (setq em (vl-catch-all-error-message r))
     (setq is-fail (and em (wcmatch em "TEST-FAIL:*")))
     (if is-fail
       (list :fail suite-name name em secs)
       (list :error suite-name name em secs)))
    (t
     (list :ok suite-name name nil secs))))

(defun t:print-result (res / status suite name msg)
  (setq status (car res))
  ;; Coerce nil fields to "" : sous clautolisp vl-catch-all-error-message
  ;; peut renvoyer nil, et (strcat … nil) y est une erreur (fatale).
  (setq suite  (if (cadr res)   (cadr res)   "?"))
  (setq name   (if (caddr res)  (caddr res)  "?"))
  (setq msg    (if (cadddr res) (cadddr res) ""))

  (cond
    ((eq status :ok)
     (t:emit-out (strcat "OK    [" suite "] " name)))
    ((eq status :fail)
     (t:emit-err (strcat "FAIL  [" suite "] " name " -- " msg)))
    (t
     (t:emit-err (strcat "ERROR [" suite "] " name " -- " msg)))))

(defun run-suite (suite-name / cell tests test total ok fail err res results start)
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
      (setq results nil)
      (setq start (t:millisecs))

      (foreach test tests
        (setq total (1+ total))
        (setq res (t:run-test suite-name test))
        (setq results (cons res results))
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
      (t:junit-record suite-name (reverse results) (t:elapsed start))
      (list :suite suite-name :total total :ok ok :fail fail :error err))))

(defun run-all (/ s summaries)
  (setq *t:last-total* 0)
  (setq *t:last-ok* 0)
  (setq *t:last-fail* 0)
  (setq *t:last-error* 0)
  (setq *t:junit-suites* nil)
  (setq summaries nil)
  (foreach s *t:suites*
    (setq summaries (cons (run-suite (car s)) summaries)))
  (reverse summaries))

;; -----------------------------
;; Rapport JUnit (GitLab, etc.)
;; -----------------------------

;; Facultatif : si la variable d'environnement AUTOLISP_TEST_JUNIT — ou, à
;; défaut, la variable AutoLISP *t:junit-file* — nomme un fichier, chaque
;; run-suite (ré)écrit ce fichier au format JUnit XML avec TOUTES les suites
;; exécutées depuis le dernier run-all (ou depuis le chargement). La sortie
;; console est inchangée. Aucun appel de clôture n'est nécessaire : le
;; fichier est complet après chaque suite.
;;
;; Le rapport ne contient que des octets ASCII : outre les caractères spéciaux
;; XML et les caractères de contrôle, les caractères non ASCII sont écrits sous
;; forme de références numériques. L'en-tête UTF-8 reste donc exact aussi bien
;; avec clautolisp que sous une CAO qui écrit dans une page de codes locale.

(defun t:junit-path (/ v)
  (setq v (getenv "AUTOLISP_TEST_JUNIT"))
  (cond
    ((and v (/= v "")) v)
    ((and *t:junit-file* (/= *t:junit-file* "")) *t:junit-file*)
    (t nil)))

(defun t:xml-escape (x / s out i n c code)
  (setq s (cond ((null x) "")
                ((= (type x) 'STR) x)
                (t (t:str x))))
  (setq out "")
  (setq i 1)
  (setq n (strlen s))
  (while (<= i n)
    (setq c (substr s i 1))
    (setq code (ascii c))
    (setq out
          (strcat out
                  (cond
                    ((= c "&")  "&amp;")
                    ((= c "<")  "&lt;")
                    ((= c ">")  "&gt;")
                    ((= c "\"") "&quot;")
                    ((= c "'")  "&apos;")
                    ;; tabulation et fins de ligne : références de caractère,
                    ;; pour survivre à la normalisation des attributs.
                    ((= code 9)  "&#9;")
                    ((= code 10) "&#10;")
                    ((= code 13) "&#13;")
                    ;; autres caractères de contrôle : interdits en XML 1.0.
                    ((< code 32) "?")
                    ;; Les CAO Windows peuvent écrire en page de codes locale
                    ;; malgré l'en-tête UTF-8. Les références numériques gardent
                    ;; le rapport ASCII et donc valide dans tous les moteurs.
                    ((> code 127) (strcat "&#" (itoa code) ";"))
                    (t c))))
    (setq i (1+ i)))
  out)

(defun t:junit-time (secs)
  (rtos (if (numberp secs) secs 0.0) 2 3))

(defun t:junit-count (results status / n r)
  (setq n 0)
  (foreach r results
    (if (eq (car r) status)
      (setq n (1+ n))))
  n)

(defun t:junit-attr (name value)
  (strcat " " name "=\"" (t:xml-escape value) "\""))

(defun t:junit-write-testcase (f res / status suite name msg head tag)
  (setq status (car res))
  (setq suite  (if (cadr res)   (cadr res)   "?"))
  (setq name   (if (caddr res)  (caddr res)  "?"))
  (setq msg    (if (cadddr res) (cadddr res) ""))
  (setq head (strcat "    <testcase"
                     (t:junit-attr "classname" suite)
                     (t:junit-attr "name" name)
                     (t:junit-attr "time" (t:junit-time (nth 4 res)))))
  (if (eq status :ok)
    (write-line (strcat head "/>") f)
    (progn
      (setq tag (if (eq status :fail) "failure" "error"))
      (write-line (strcat head ">") f)
      (write-line (strcat "      <" tag
                          (t:junit-attr "message" msg)
                          (t:junit-attr "type" tag)
                          ">" (t:xml-escape msg) "</" tag ">")
                  f)
      (write-line "    </testcase>" f))))

(defun t:junit-write (path / f suites entry results res total fail err secs)
  (setq f (open path "w"))
  (if (null f)
    (progn
      (t:emit-err (strcat "[autolisp-test] cannot write JUnit report: " path))
      nil)
    (progn
      (setq suites (reverse *t:junit-suites*))
      (setq total 0)
      (setq fail 0)
      (setq err 0)
      (setq secs 0.0)
      (foreach entry suites
        (setq results (caddr entry))
        (setq total (+ total (length results)))
        (setq fail  (+ fail (t:junit-count results :fail)))
        (setq err   (+ err  (t:junit-count results :error)))
        (setq secs  (+ secs (cadr entry))))
      (write-line "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" f)
      (write-line (strcat "<testsuites"
                          (t:junit-attr "tests" (itoa total))
                          (t:junit-attr "failures" (itoa fail))
                          (t:junit-attr "errors" (itoa err))
                          (t:junit-attr "time" (t:junit-time secs))
                          ">")
                  f)
      (foreach entry suites
        (setq results (caddr entry))
        (write-line (strcat "  <testsuite"
                            (t:junit-attr "name" (car entry))
                            (t:junit-attr "tests" (itoa (length results)))
                            (t:junit-attr "failures" (itoa (t:junit-count results :fail)))
                            (t:junit-attr "errors" (itoa (t:junit-count results :error)))
                            (t:junit-attr "skipped" "0")
                            (t:junit-attr "time" (t:junit-time (cadr entry)))
                            ">")
                    f)
        (foreach res results
          (t:junit-write-testcase f res))
        (write-line "  </testsuite>" f))
      (write-line "</testsuites>" f)
      (close f)
      path)))

;; Point d'entrée public pour les exécuteurs maison (qui n'appellent pas
;; run-suite) : RESULTS est une liste d'enregistrements
;; (STATUT SUITE NOM MESSAGE DURÉE-EN-SECONDES), STATUT valant :ok, :fail ou
;; :error. Ajoute la suite au rapport et le réécrit s'il est demandé.
(defun t:junit-record (suite-name results secs / path)
  (setq *t:junit-suites*
        (cons (list suite-name (if (numberp secs) secs 0.0) results)
              *t:junit-suites*))
  (setq path (t:junit-path))
  (if path
    (t:junit-write path))
  suite-name)
