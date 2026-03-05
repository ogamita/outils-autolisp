(setq a 10)
(setq xs '(3 4))

(m:meval
  '(quasiquote (1 2 (unquote a) (splice xs) 5)))
;; => (1 2 10 3 4 5)

(defmacro when (test &rest body)
  (quasiquote
    (if (unquote test)
        (progn (splice body)))))
