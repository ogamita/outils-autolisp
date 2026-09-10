;;; autolisp-geometry.lsp --- Matrices de transformation 4x4 pour AutoLISP

(vl-load-com)

;;; ------------------------------------------------------------------
;;; Représentation
;;; ------------------------------------------------------------------
;;;
;;; Une matrice est une liste de 4 lignes, chaque ligne une liste de 4
;;; réels (row-major) : c'est exactement la forme attendue en entrée
;;; par (vlax-tmatrix ...) et rendue par sa lecture inverse, donc
;;; aucune conversion n'est nécessaire pour passer d'ici à ActiveX.
;;;
;;;   ((m00 m01 m02 tx)
;;;    (m10 m11 m12 ty)
;;;    (m20 m21 m22 tz)
;;;    (0.0 0.0 0.0 1.0))
;;;
;;; Un point ou un vecteur est une liste (x y z). Les angles sont en
;;; radians (convention AutoLISP). Un point est transformé comme
;;; coordonnée homogène (w=1, la translation s'applique) ; un vecteur
;;; comme direction (w=0, la translation ne s'applique pas).
;;;
;;; API publique:
;;;
;;;   Construction:
;;;     geom-identity                  ( -> matrice identité)
;;;     geom-translation      (dx dy dz -> translation)
;;;     geom-scale            (sx sy sz -> mise à l'échelle par axe)
;;;     geom-rotation-x       (ang -> rotation autour de X)
;;;     geom-rotation-y       (ang -> rotation autour de Y)
;;;     geom-rotation-z       (ang -> rotation autour de Z)
;;;     geom-rotation-axis-angle (axis ang -> rotation autour d'un axe quelconque)
;;;
;;;   Conversion (ActiveX) :
;;;     geom-matrix->vlax-tmatrix (matrice -> variant pour vla-TransformBy)
;;;     geom-vlax-tmatrix->matrix (variant -> matrice, lecture inverse)
;;;
;;;   Prédicats :
;;;     geom-matrix-p   (valeur -> T si forme 4x4 de réels)
;;;     geom-identity-p (matrice [tol] -> T si proche de l'identité)
;;;     geom-equal      (m1 m2 [tol] -> T si proches composant à composant)
;;;
;;;   Composition et application :
;;;     geom-mxm              (m1 m2 -> produit matriciel)
;;;     geom-multiply          (liste-de-matrices -> produit, gauche à droite)
;;;     geom-transpose         (matrice -> transposée)
;;;     geom-determinant       (matrice -> déterminant du bloc linéaire 3x3)
;;;     geom-inverse           (matrice -> inverse ; suppose la dernière ligne (0 0 0 1))
;;;     geom-transform-point   (matrice pt -> point transformé, translation incluse)
;;;     geom-transform-vector  (matrice v  -> vecteur transformé, translation exclue)
;;;
;;;   Analyse (décomposition) :
;;;     geom-translation-of     (matrice -> (tx ty tz))
;;;     geom-scale-of            (matrice -> (sx sy sz) ; signe reporté sur sz si réflexion)
;;;     geom-rotation-matrix-of  (matrice -> partie rotation seule, en 4x4)
;;;     geom-axis-angle-of       (matrice -> (axis ang) ; axis=nil si rotation nulle)
;;;     geom-decompose           (matrice -> alist translation/scale/rotation-axis/
;;;                                          rotation-angle/determinant)
;;;
;;;   Divers :
;;;     geom-print (matrice -> affichage de débogage, valeur de retour sans intérêt)
;;;
;;; Limitations : les fonctions d'Analyse ci-dessus supposent une matrice
;;; construite comme Translation x Rotation x Échelle, sans cisaillement
;;; (shear). Une matrice quelconque contenant du cisaillement n'est pas
;;; correctement décomposée par geom-rotation-matrix-of / geom-axis-angle-of
;;; (aucune décomposition QR/polaire générale n'est fournie ici).

;;; ------------------------------------------------------------------
;;; Utilitaires internes
;;; ------------------------------------------------------------------

(defun geom--error (msg)
  (error (strcat "autolisp-geometry: " msg)))

(defun geom--dot (u v)
  ;; produit scalaire ; fonctionne aussi bien sur des lignes/colonnes
  ;; de longueur 3 que sur des lignes homogènes de longueur 4
  (apply '+ (mapcar '* u v)))

(defun geom--vector-length (v)
  (sqrt (geom--dot v v)))

(defun geom--normalize (v / len)
  (setq len (geom--vector-length v))
  (if (< len 1.0e-12)
    v
    (list (/ (car v) len) (/ (cadr v) len) (/ (caddr v) len))))

(defun geom--acos (x)
  ;; AutoLISP n'a pas de acos natif : on le dérive de atan (forme
  ;; atan2), en bornant x pour absorber les dépassements de [-1,1]
  ;; dus aux arrondis flottants.
  (cond ((>= x 1.0) 0.0)
        ((<= x -1.0) pi)
        (t (atan (sqrt (- 1.0 (* x x))) x))))

;;; ------------------------------------------------------------------
;;; Construction
;;; ------------------------------------------------------------------

(defun geom-identity ()
  (list (list 1.0 0.0 0.0 0.0)
        (list 0.0 1.0 0.0 0.0)
        (list 0.0 0.0 1.0 0.0)
        (list 0.0 0.0 0.0 1.0)))

(defun geom-translation (dx dy dz)
  (list (list 1.0 0.0 0.0 (float dx))
        (list 0.0 1.0 0.0 (float dy))
        (list 0.0 0.0 1.0 (float dz))
        (list 0.0 0.0 0.0 1.0)))

(defun geom-scale (sx sy sz)
  (list (list (float sx) 0.0 0.0 0.0)
        (list 0.0 (float sy) 0.0 0.0)
        (list 0.0 0.0 (float sz) 0.0)
        (list 0.0 0.0 0.0 1.0)))

(defun geom-rotation-x (ang / c s)
  (setq c (cos ang) s (sin ang))
  (list (list 1.0 0.0    0.0    0.0)
        (list 0.0 c      (- s)  0.0)
        (list 0.0 s      c      0.0)
        (list 0.0 0.0    0.0    1.0)))

(defun geom-rotation-y (ang / c s)
  (setq c (cos ang) s (sin ang))
  (list (list c      0.0 s    0.0)
        (list 0.0    1.0 0.0  0.0)
        (list (- s)  0.0 c    0.0)
        (list 0.0    0.0 0.0  1.0)))

(defun geom-rotation-z (ang / c s)
  (setq c (cos ang) s (sin ang))
  (list (list c    (- s) 0.0 0.0)
        (list s    c     0.0 0.0)
        (list 0.0  0.0   1.0 0.0)
        (list 0.0  0.0   0.0 1.0)))

(defun geom-rotation-axis-angle (axis ang / x y z len c s omc)
  ;; formule de Rodrigues, axe normalisé en interne
  (setq len (geom--vector-length axis))
  (if (< len 1.0e-12)
    (geom--error "rotation axis must be a non-zero vector"))
  (setq x (/ (car axis) len)
        y (/ (cadr axis) len)
        z (/ (caddr axis) len))
  (setq c (cos ang) s (sin ang) omc (- 1.0 c))
  (list (list (+ c (* x x omc))       (- (* x y omc) (* z s))   (+ (* x z omc) (* y s))   0.0)
        (list (+ (* y x omc) (* z s)) (+ c (* y y omc))         (- (* y z omc) (* x s))   0.0)
        (list (- (* z x omc) (* y s)) (+ (* z y omc) (* x s))   (+ c (* z z omc))         0.0)
        (list 0.0 0.0 0.0 1.0)))

;;; ------------------------------------------------------------------
;;; Conversion (ActiveX)
;;; ------------------------------------------------------------------

(defun geom-matrix->vlax-tmatrix (m)
  ;; vlax-tmatrix ne fait aucun calcul : c'est un pur marshalling
  ;; liste Lisp -> variant/safearray COM, requis par vla-TransformBy
  ;; et consorts.
  (vlax-tmatrix m))

(defun geom--reshape-4x4 (flat / n)
  ;; sous clautolisp, (vlax-safearray->list ...) sur le safearray 2D
  ;; de vlax-tmatrix rend une liste PLATE de 16 réels (ordre row-major :
  ;; row0 row1 row2 row3), pas une liste de 4 listes de 4 ; on ne sait
  ;; pas si BricsCAD/AutoCAD se comportent pareil (à vérifier), donc on
  ;; accepte les deux formes en entrée par prudence.
  (if (and (= (type flat) 'LIST)
           (= (length flat) 4)
           (= (type (car flat)) 'LIST))
    flat
    (progn
      (setq n 0)
      (mapcar
        (function
          (lambda (row / r)
            (setq r (list (nth n flat) (nth (+ n 1) flat) (nth (+ n 2) flat) (nth (+ n 3) flat)))
            (setq n (+ n 4))
            r))
        '(0 1 2 3)))))

(defun geom-vlax-tmatrix->matrix (variant)
  ;; opération inverse : variant -> safearray -> liste (voir geom--reshape-4x4
  ;; pour le cas où le résultat est rendu à plat).
  (geom--reshape-4x4 (vlax-safearray->list (vlax-variant-value variant))))

;;; ------------------------------------------------------------------
;;; Prédicats
;;; ------------------------------------------------------------------

(defun geom-matrix-p (m)
  (and (= (type m) 'LIST)
       (= (length m) 4)
       (vl-every
         (function
           (lambda (row)
             (and (= (type row) 'LIST)
                  (= (length row) 4)
                  (vl-every 'numberp row))))
         m)))

(defun geom-equal (m1 m2 tol / i j ok)
  (setq tol (if tol tol 1.0e-9))
  (setq ok t)
  (setq i 0)
  (while (and ok (< i 4))
    (setq j 0)
    (while (and ok (< j 4))
      (if (> (abs (- (nth j (nth i m1)) (nth j (nth i m2)))) tol)
        (setq ok nil))
      (setq j (1+ j)))
    (setq i (1+ i)))
  ok)

(defun geom-identity-p (m tol)
  (geom-equal m (geom-identity) tol))

;;; ------------------------------------------------------------------
;;; Composition et application
;;; ------------------------------------------------------------------

(defun geom-transpose (m)
  (list (mapcar 'car    m)
        (mapcar 'cadr   m)
        (mapcar 'caddr  m)
        (mapcar 'cadddr m)))

(defun geom-mxm (m1 m2 / bt)
  (setq bt (geom-transpose m2))
  (mapcar
    (function
      (lambda (row)
        (mapcar
          (function (lambda (col) (geom--dot row col)))
          bt)))
    m1))

(defun geom-multiply (matrices / result)
  ;; produit d'une liste de matrices, de gauche à droite :
  ;; (geom-multiply (list T R S)) applique S en premier au point.
  (if (null matrices)
    (geom-identity)
    (progn
      (setq result (car matrices))
      (foreach m (cdr matrices)
        (setq result (geom-mxm result m)))
      result)))

(defun geom-determinant (m / m00 m01 m02 m10 m11 m12 m20 m21 m22)
  ;; la dernière ligne étant supposée (0 0 0 1), le déterminant 4x4
  ;; d'une matrice affine vaut celui du bloc linéaire 3x3.
  (setq m00 (nth 0 (nth 0 m)) m01 (nth 1 (nth 0 m)) m02 (nth 2 (nth 0 m))
        m10 (nth 0 (nth 1 m)) m11 (nth 1 (nth 1 m)) m12 (nth 2 (nth 1 m))
        m20 (nth 0 (nth 2 m)) m21 (nth 1 (nth 2 m)) m22 (nth 2 (nth 2 m)))
  (+ (* m00 (- (* m11 m22) (* m12 m21)))
     (- (* m01 (- (* m10 m22) (* m12 m20))))
     (* m02 (- (* m10 m21) (* m11 m20)))))

(defun geom-inverse (m / m00 m01 m02 m10 m11 m12 m20 m21 m22
                          tx ty tz det
                          n00 n01 n02 n10 n11 n12 n20 n21 n22)
  ;; inverse d'une matrice affine (dernière ligne (0 0 0 1)) : inverse
  ;; du bloc linéaire 3x3 par cofacteurs/déterminant, puis translation
  ;; recalculée en -(L^-1 . t) — pas de pivot de Gauss-Jordan 4x4
  ;; générique, inutile ici.
  (setq m00 (nth 0 (nth 0 m)) m01 (nth 1 (nth 0 m)) m02 (nth 2 (nth 0 m))
        m10 (nth 0 (nth 1 m)) m11 (nth 1 (nth 1 m)) m12 (nth 2 (nth 1 m))
        m20 (nth 0 (nth 2 m)) m21 (nth 1 (nth 2 m)) m22 (nth 2 (nth 2 m))
        tx  (nth 3 (nth 0 m)) ty  (nth 3 (nth 1 m)) tz  (nth 3 (nth 2 m)))
  (setq det (geom-determinant m))
  (if (< (abs det) 1.0e-12)
    (geom--error "matrix is singular, cannot invert"))
  (setq n00 (/ (- (* m11 m22) (* m12 m21)) det)
        n01 (/ (- (* m02 m21) (* m01 m22)) det)
        n02 (/ (- (* m01 m12) (* m02 m11)) det)
        n10 (/ (- (* m12 m20) (* m10 m22)) det)
        n11 (/ (- (* m00 m22) (* m02 m20)) det)
        n12 (/ (- (* m02 m10) (* m00 m12)) det)
        n20 (/ (- (* m10 m21) (* m11 m20)) det)
        n21 (/ (- (* m01 m20) (* m00 m21)) det)
        n22 (/ (- (* m00 m11) (* m01 m10)) det))
  (list (list n00 n01 n02 (- (+ (* n00 tx) (* n01 ty) (* n02 tz))))
        (list n10 n11 n12 (- (+ (* n10 tx) (* n11 ty) (* n12 tz))))
        (list n20 n21 n22 (- (+ (* n20 tx) (* n21 ty) (* n22 tz))))
        (list 0.0 0.0 0.0 1.0)))

(defun geom-transform-point (m pt / h)
  (setq h (mapcar
            (function
              (lambda (row) (geom--dot row (list (car pt) (cadr pt) (caddr pt) 1.0))))
            m))
  (list (nth 0 h) (nth 1 h) (nth 2 h)))

(defun geom-transform-vector (m v / h)
  (setq h (mapcar
            (function
              (lambda (row) (geom--dot row (list (car v) (cadr v) (caddr v) 0.0))))
            m))
  (list (nth 0 h) (nth 1 h) (nth 2 h)))

;;; ------------------------------------------------------------------
;;; Analyse (décomposition)
;;; ------------------------------------------------------------------

(defun geom-translation-of (m)
  (list (nth 3 (nth 0 m)) (nth 3 (nth 1 m)) (nth 3 (nth 2 m))))

(defun geom-scale-of (m / c0 c1 c2 sx sy sz)
  (setq c0 (list (nth 0 (nth 0 m)) (nth 0 (nth 1 m)) (nth 0 (nth 2 m)))
        c1 (list (nth 1 (nth 0 m)) (nth 1 (nth 1 m)) (nth 1 (nth 2 m)))
        c2 (list (nth 2 (nth 0 m)) (nth 2 (nth 1 m)) (nth 2 (nth 2 m))))
  (setq sx (geom--vector-length c0)
        sy (geom--vector-length c1)
        sz (geom--vector-length c2))
  ;; les normes de colonnes sont toujours positives ; une matrice de
  ;; déterminant négatif contient une réflexion, dont le signe est
  ;; reporté sur sz par convention (pas de manière unique de la
  ;; localiser sur un axe précis).
  (if (< (geom-determinant m) 0.0)
    (setq sz (- sz)))
  (list sx sy sz))

(defun geom-rotation-matrix-of (m / s sx sy sz)
  (setq s (geom-scale-of m))
  (setq sx (nth 0 s) sy (nth 1 s) sz (nth 2 s))
  (if (or (< (abs sx) 1.0e-12) (< (abs sy) 1.0e-12) (< (abs sz) 1.0e-12))
    (geom--error "zero scale factor along one axis, rotation is undefined"))
  (list (list (/ (nth 0 (nth 0 m)) sx) (/ (nth 1 (nth 0 m)) sy) (/ (nth 2 (nth 0 m)) sz) 0.0)
        (list (/ (nth 0 (nth 1 m)) sx) (/ (nth 1 (nth 1 m)) sy) (/ (nth 2 (nth 1 m)) sz) 0.0)
        (list (/ (nth 0 (nth 2 m)) sx) (/ (nth 1 (nth 2 m)) sy) (/ (nth 2 (nth 2 m)) sz) 0.0)
        (list 0.0 0.0 0.0 1.0)))

(defun geom-axis-angle-of (m / r r00 r01 r02 r10 r11 r12 r20 r21 r22
                              tr cosang ang eps xx yy zz xy xz yz x y z sinang)
  ;; extraction axe/angle (Rodrigues inverse) à partir de la partie
  ;; rotation pure de m (l'échelle est retirée par geom-rotation-matrix-of,
  ;; qui est idempotent si m est déjà une rotation pure).
  (setq r (geom-rotation-matrix-of m))
  (setq r00 (nth 0 (nth 0 r)) r01 (nth 1 (nth 0 r)) r02 (nth 2 (nth 0 r))
        r10 (nth 0 (nth 1 r)) r11 (nth 1 (nth 1 r)) r12 (nth 2 (nth 1 r))
        r20 (nth 0 (nth 2 r)) r21 (nth 1 (nth 2 r)) r22 (nth 2 (nth 2 r)))
  (setq tr (+ r00 r11 r22))
  (setq cosang (/ (- tr 1.0) 2.0))
  (setq ang (geom--acos cosang))
  (setq eps 1.0e-6)
  (cond
    ;; angle ~ 0 : rotation identité, axe indéfini
    ((< ang eps)
     (list nil 0.0))
    ;; angle ~ pi : la formule générale divise par sin(ang) ~ 0 et
    ;; devient instable ; on extrait l'axe depuis la diagonale de
    ;; (R + I) / 2 = axis (x) axis (produit tensoriel de l'axe par
    ;; lui-même), en partant de sa plus grande composante diagonale.
    ((< (- pi ang) eps)
     (setq xx (/ (+ r00 1.0) 2.0)
           yy (/ (+ r11 1.0) 2.0)
           zz (/ (+ r22 1.0) 2.0)
           xy (/ (+ r01 r10) 4.0)
           xz (/ (+ r02 r20) 4.0)
           yz (/ (+ r12 r21) 4.0))
     (cond
       ((and (>= xx yy) (>= xx zz))
        (setq x (sqrt (max xx 0.0)))
        (setq y (if (> x eps) (/ xy x) 0.0))
        (setq z (if (> x eps) (/ xz x) 0.0)))
       ((>= yy zz)
        (setq y (sqrt (max yy 0.0)))
        (setq x (if (> y eps) (/ xy y) 0.0))
        (setq z (if (> y eps) (/ yz y) 0.0)))
       (t
        (setq z (sqrt (max zz 0.0)))
        (setq x (if (> z eps) (/ xz z) 0.0))
        (setq y (if (> z eps) (/ yz z) 0.0))))
     (list (geom--normalize (list x y z)) pi))
    ;; cas général
    (t
     (setq sinang (* 2.0 (sin ang)))
     (list (geom--normalize (list (/ (- r21 r12) sinang)
                                   (/ (- r02 r20) sinang)
                                   (/ (- r10 r01) sinang)))
           ang))))

(defun geom-decompose (m / aa)
  (setq aa (geom-axis-angle-of m))
  (list (cons 'geom-translation (geom-translation-of m))
        (cons 'geom-scale (geom-scale-of m))
        (cons 'geom-rotation-axis (car aa))
        (cons 'geom-rotation-angle (cadr aa))
        (cons 'geom-determinant (geom-determinant m))))

;;; ------------------------------------------------------------------
;;; Divers
;;; ------------------------------------------------------------------

(defun geom-print (m)
  (foreach row m
    (princ "\n  ")
    (foreach v row
      (princ (rtos v 2 6))
      (princ " ")))
  (princ "\n")
  (princ))
