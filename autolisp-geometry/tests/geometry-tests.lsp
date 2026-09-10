;;; geometry-tests.lsp --- Tests for autolisp-geometry

(defsuite "autolisp-geometry")
(in-suite "autolisp-geometry")

;;; Helpers de comparaison approchée locaux aux tests (is-approx est
;;; scalaire ; on compose composant par composant pour les points).

(defun tg-approx (a b tol)
  (< (abs (- a b)) tol))

(defun tg-point-approx (p1 p2 tol)
  (and (tg-approx (car p1) (car p2) tol)
       (tg-approx (cadr p1) (cadr p2) tol)
       (tg-approx (caddr p1) (caddr p2) tol)))

(deftest
  "geom-identity is the identity matrix"
  (function
    (lambda ()
      (is (geom-identity-p (geom-identity) nil) nil)
      (is-equal '((1.0 0.0 0.0 0.0)
                  (0.0 1.0 0.0 0.0)
                  (0.0 0.0 1.0 0.0)
                  (0.0 0.0 0.0 1.0))
                (geom-identity) nil))))

(deftest
  "geom-translation moves a point and leaves a vector untouched"
  (function
    (lambda (/ m)
      (setq m (geom-translation 10.0 -5.0 2.0))
      (is (tg-point-approx '(11.0 -3.0 3.0) (geom-transform-point m '(1.0 2.0 1.0)) 1.0e-9) nil)
      (is (tg-point-approx '(1.0 2.0 1.0) (geom-transform-vector m '(1.0 2.0 1.0)) 1.0e-9) nil))))

(deftest
  "geom-scale scales a point along each axis"
  (function
    (lambda (/ m)
      (setq m (geom-scale 2.0 3.0 4.0))
      (is (tg-point-approx '(2.0 6.0 12.0) (geom-transform-point m '(1.0 2.0 3.0)) 1.0e-9) nil))))

(deftest
  "geom-rotation-z turns X into Y at 90 degrees"
  (function
    (lambda (/ m)
      (setq m (geom-rotation-z (/ pi 2.0)))
      (is (tg-point-approx '(0.0 1.0 0.0) (geom-transform-point m '(1.0 0.0 0.0)) 1.0e-9) nil))))

(deftest
  "geom-rotation-x turns Y into Z at 90 degrees"
  (function
    (lambda (/ m)
      (setq m (geom-rotation-x (/ pi 2.0)))
      (is (tg-point-approx '(0.0 0.0 1.0) (geom-transform-point m '(0.0 1.0 0.0)) 1.0e-9) nil))))

(deftest
  "geom-rotation-y turns X into -Z at 90 degrees"
  (function
    (lambda (/ m)
      (setq m (geom-rotation-y (/ pi 2.0)))
      (is (tg-point-approx '(0.0 0.0 -1.0) (geom-transform-point m '(1.0 0.0 0.0)) 1.0e-9) nil))))

(deftest
  "geom-rotation-axis-angle around Z agrees with geom-rotation-z"
  (function
    (lambda (/ ang)
      (setq ang (/ pi 3.0))
      (is (geom-equal (geom-rotation-z ang)
                       (geom-rotation-axis-angle '(0.0 0.0 1.0) ang)
                       1.0e-9)
          nil))))

(deftest
  "geom-multiply composes translation, rotation and scale left to right"
  (function
    (lambda (/ tm rm sm combined pt expected)
      (setq tm (geom-translation 5.0 0.0 0.0))
      (setq rm (geom-rotation-z (/ pi 2.0)))
      (setq sm (geom-scale 2.0 2.0 2.0))
      (setq combined (geom-multiply (list tm rm sm)))
      (setq pt '(1.0 0.0 0.0))
      ;; référence : appliquer S, puis R, puis T séparément
      (setq expected (geom-transform-point tm (geom-transform-point rm (geom-transform-point sm pt))))
      (is (tg-point-approx expected (geom-transform-point combined pt) 1.0e-9) nil))))

(deftest
  "geom-transpose is involutive and fixes the identity"
  (function
    (lambda (/ m)
      (setq m (geom-multiply (list (geom-translation 1.0 2.0 3.0) (geom-rotation-x 0.7))))
      (is-equal (geom-identity) (geom-transpose (geom-identity)) nil)
      (is (geom-equal m (geom-transpose (geom-transpose m)) 1.0e-9) nil))))

(deftest
  "geom-determinant of identity, scale and a proper rotation"
  (function
    (lambda ()
      (is (tg-approx 1.0 (geom-determinant (geom-identity)) 1.0e-9) nil)
      (is (tg-approx 24.0 (geom-determinant (geom-scale 2.0 3.0 4.0)) 1.0e-9) nil)
      (is (tg-approx 1.0 (geom-determinant (geom-rotation-axis-angle '(1.0 1.0 1.0) 0.9)) 1.0e-9) nil))))

(deftest
  "geom-inverse undoes a translation"
  (function
    (lambda (/ m)
      (setq m (geom-translation 3.0 -4.0 5.0))
      (is (tg-point-approx '(1.0 2.0 3.0)
                            (geom-transform-point (geom-inverse m) (geom-transform-point m '(1.0 2.0 3.0)))
                            1.0e-9)
          nil))))

(deftest
  "geom-inverse of a composed TRS matrix cancels it out"
  (function
    (lambda (/ m)
      (setq m (geom-multiply (list (geom-translation 7.0 -1.0 2.0)
                                    (geom-rotation-axis-angle '(1.0 2.0 3.0) 1.1)
                                    (geom-scale 1.5 2.5 0.5))))
      (is (geom-equal (geom-identity) (geom-mxm m (geom-inverse m)) 1.0e-6) nil))))

(deftest
  "geom-matrix->vlax-tmatrix / geom-vlax-tmatrix->matrix round-trip"
  (function
    (lambda (/ m variant back)
      (setq m (geom-multiply (list (geom-translation 1.0 2.0 3.0) (geom-rotation-z 0.4))))
      (setq variant (geom-matrix->vlax-tmatrix m))
      (setq back (geom-vlax-tmatrix->matrix variant))
      (is (geom-equal m back 1.0e-9) nil))))

(deftest
  "geom-matrix-p accepts a valid 4x4 and rejects malformed input"
  (function
    (lambda ()
      (is (geom-matrix-p (geom-identity)) nil)
      (is-not (geom-matrix-p '((1.0 0.0 0.0) (0.0 1.0 0.0 0.0))) nil)
      (is-not (geom-matrix-p "not a matrix") nil)
      (is-not (geom-matrix-p nil) nil))))

(deftest
  "translation-of / scale-of / axis-angle-of recover a composed matrix's components"
  (function
    (lambda (/ axis ang m aa)
      (setq axis (geom--normalize '(1.0 2.0 2.0)))
      (setq ang (/ pi 3.0))
      (setq m (geom-multiply (list (geom-translation 10.0 -5.0 2.0)
                                    (geom-rotation-axis-angle axis ang)
                                    (geom-scale 2.0 3.0 4.0))))
      (is (tg-point-approx '(10.0 -5.0 2.0) (geom-translation-of m) 1.0e-9) nil)
      (is (tg-point-approx '(2.0 3.0 4.0) (geom-scale-of m) 1.0e-9) nil)
      (setq aa (geom-axis-angle-of m))
      (is (tg-approx ang (cadr aa) 1.0e-6) nil)
      ;; le signe de l'axe retrouve peut etre oppose (rotation identique
      ;; pour (axe, ang) et (-axe, -ang)) : on compare via |produit scalaire|
      (is (tg-approx 1.0 (abs (geom--dot axis (car aa))) 1.0e-6) nil))))

(deftest
  "geom-axis-angle-of handles the numerically unstable 180 degree case"
  (function
    (lambda (/ axis m aa)
      (setq axis (geom--normalize '(1.0 1.0 0.0)))
      (setq m (geom-rotation-axis-angle axis pi))
      (setq aa (geom-axis-angle-of m))
      (is (tg-approx pi (cadr aa) 1.0e-6) nil)
      (is (tg-approx 1.0 (abs (geom--dot axis (car aa))) 1.0e-6) nil))))

(deftest
  "geom-axis-angle-of reports no axis for the identity"
  (function
    (lambda (/ aa)
      (setq aa (geom-axis-angle-of (geom-identity)))
      (is-equal nil (car aa) nil)
      (is-equal 0.0 (cadr aa) nil))))

(deftest
  "geom-decompose returns an alist with the expected keys"
  (function
    (lambda (/ m d)
      (setq m (geom-multiply (list (geom-translation 1.0 0.0 0.0) (geom-scale 2.0 2.0 2.0))))
      (setq d (geom-decompose m))
      (is (tg-point-approx '(1.0 0.0 0.0) (cdr (assoc 'geom-translation d)) 1.0e-9) nil)
      (is (tg-point-approx '(2.0 2.0 2.0) (cdr (assoc 'geom-scale d)) 1.0e-9) nil)
      (is (tg-approx 8.0 (cdr (assoc 'geom-determinant d)) 1.0e-9) nil))))
