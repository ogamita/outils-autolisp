;;; algetypes-tests.lsp --- Tests de autolisp-algetypes

(defsuite "autolisp-algetypes")
(in-suite "autolisp-algetypes")

(deftest
  "déclare et construit un type somme"
  (function
    (lambda (/ shape)
      (al-define-type 'shape '((circle (radius)) (point (x y))))
      (setq shape (al-construct 'shape 'point '(3 4)))
      (is (al-value-p shape) nil)
      (is-equal 'shape (al-type-of shape) nil)
      (is-equal 'point (al-variant-of shape) nil)
      (is-equal '(3 4) (al-values shape) nil)
      (is-equal 3 (al-field shape 'x) nil)
      (is-equal 4 (al-field shape 'y) nil))))

(deftest
  "rejette une construction incorrecte"
  (function
    (lambda ()
      (signals-error
        (function (lambda () (al-construct 'option 'some nil))) nil)
      (signals-error
        (function (lambda () (al-construct 'missing 'x nil))) nil))))

(deftest
  "filtre de manière exhaustive"
  (function
    (lambda (/ value result)
      (setq value (al-some 21))
      (setq result
            (al-match
              value
              (list
                (cons 'some (function (lambda (x) (* x 2))))
                (cons 'none (function (lambda () 0))))))
      (is-equal 42 result nil)
      (signals-error
        (function
          (lambda ()
            (al-match value
                      (list (cons 'some (function (lambda (x) x)))))))
        nil))))

(deftest
  "otherwise complète le filtrage"
  (function
    (lambda ()
      (is-equal
        'absent
        (al-match (al-none)
                  (list
                    (cons 'some (function (lambda (x) x)))
                    (cons 'otherwise (function (lambda () 'absent)))))
        nil))))

(deftest
  "option map et bind"
  (function
    (lambda (/ mapped bound)
      (setq mapped
            (al-option-map (function (lambda (x) (1+ x))) (al-some 4)))
      (setq bound
            (al-option-bind
              (function (lambda (x) (if (> x 0) (al-some (* x 2)) (al-none))))
              mapped))
      (is-equal 5 (al-field mapped 'value) nil)
      (is-equal 10 (al-field bound 'value) nil)
      (is (al-is-p (al-option-map (function (lambda (x) x)) (al-none))
                   'option 'none)
          nil))))

(deftest
  "map rejette une valeur d'un autre type"
  (function
    (lambda ()
      (signals-error
        (function
          (lambda ()
            (al-option-map (function (lambda (x) x)) (al-ok 1))))
        nil))))

(deftest
  "result map et bind propagent les erreurs"
  (function
    (lambda (/ failure success)
      (setq failure (al-result-map (function (lambda (x) (1+ x)))
                                   (al-error "échec")))
      (setq success (al-result-bind (function (lambda (x) (al-ok (* x 3))))
                                    (al-ok 7)))
      (is (al-is-p failure 'result 'error) nil)
      (is-equal "échec" (al-field failure 'reason) nil)
      (is-equal 21 (al-field success 'value) nil))))
