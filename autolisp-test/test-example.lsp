(defsuite "math")
(in-suite "math")

(deftest
  "addition"
  (function
    (lambda ()
      (is-equal 3 (+ 1 2))
      (is (= 7 (+ 3 4)))
      (is-not (= 0 (+ 1 2))))))

(deftest
  "approx"
  (function
    (lambda ()
      (is-approx 1.0 1.001 0.01))))

(deftest
  "signals"
  (function
    (lambda ()
      (signals-error
        (function (lambda () (error "boom")))))))

(run-suite "math")
;; or
(run-all)
