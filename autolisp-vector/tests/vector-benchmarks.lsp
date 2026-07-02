;;; vector-benchmarks.lsp --- Benchmark de vitesse : vecteur (arbre) vs liste.
;;;
;;; Compare av-vector (accès indexé en O(log n)) à une liste AutoLISP simple
;;; (accès en O(n)), en lecture seule et en lecture-écriture, pour des tailles
;;; croissantes. Objectif : valider l'intérêt du vecteur en vitesse ET en
;;; mutabilité (le vecteur mute en place ; la liste doit être reconstruite).
;;;
;;; Portable clautolisp / BricsCAD / AutoCAD (timer : (getvar "MILLISECS")).
;;; Sortie : stdout + fichier artefact si $BENCH_OUTFILE est défini.
;;; Point d'entrée : (av-run-benchmarks)  /  (C:BENCH)

(setq *av-bench-min-ms* 50)          ; durée mini mesurée par point (précision)
(setq *av-bench-out-handle* nil)

(defun av-bench-sizes () '(5 10 50 100 500 1000))

(defun av-bench-ms () (getvar "MILLISECS"))

(defun av-bench-line (s)
  (princ s) (princ "\n")
  (if *av-bench-out-handle* (write-line s *av-bench-out-handle*)))

;; liste (0 1 ... n-1)
(defun av-bench-range (n / i l)
  (setq i n l nil) (while (> i 0) (setq i (1- i) l (cons i l))) l)

;; indices pseudo-aléatoires bornés dans [0, size) ; LCG borné (< 2^31)
(defun av-bench-indices (count size / l st)
  (setq l nil st 1)
  (repeat count
    (setq st (rem (+ (* st 30637) 17389) 32749))
    (setq l (cons (rem st size) l)))
  l)

;; remplace l'élément idx d'une liste : reconstruction O(n) (la liste est
;; immuable — c'est le coût de mutation à comparer au vecteur en place).
(defun av-bench-list-set (lst idx val / out i cell)
  (setq out nil i 0 cell lst)
  (while cell
    (setq out (cons (if (= i idx) val (car cell)) out))
    (setq cell (cdr cell) i (1+ i)))
  (reverse out))

;; µs par opération, formaté (point décimal)
(defun av-bench-us (ms ops / s)
  (setq s (rtos (/ (* ms 1000.0) ops) 2 3))
  (if (vl-string-search "," s) (setq s (vl-string-subst "." "," s)))
  s)

;; ratio (base/op) / (struct/op) : combien de fois la structure est plus rapide
(defun av-bench-ratio (msb opsb ms ops / s)
  (setq s (rtos (/ (/ (* msb 1.0) opsb) (/ (* ms 1.0) ops)) 2 2))
  (if (vl-string-search "," s) (setq s (vl-string-subst "." "," s)))
  s)

;; cadrage à droite sur w colonnes
(defun av-bench-pad (s w / o) (setq o s) (while (< (strlen o) w) (setq o (strcat " " o))) o)

;; --- mesures : renvoient (list ms-total ops-total) ---
(defun av-bench-read-vec (v idxs / reps t0 el s done)
  (setq reps 1 done nil)
  (while (not done)
    (setq s 0 t0 (av-bench-ms))
    (repeat reps (foreach i idxs (setq s (+ s (av-aref v i)))))
    (setq el (- (av-bench-ms) t0))
    (if (or (>= el *av-bench-min-ms*) (> reps 1048576)) (setq done T) (setq reps (* reps 2))))
  (list el (* (* reps 1.0) (length idxs))))

(defun av-bench-read-list (lst idxs / reps t0 el s done)
  (setq reps 1 done nil)
  (while (not done)
    (setq s 0 t0 (av-bench-ms))
    (repeat reps (foreach i idxs (setq s (+ s (nth i lst)))))
    (setq el (- (av-bench-ms) t0))
    (if (or (>= el *av-bench-min-ms*) (> reps 1048576)) (setq done T) (setq reps (* reps 2))))
  (list el (* (* reps 1.0) (length idxs))))

(defun av-bench-rw-vec (v idxs / reps t0 el done i)
  (setq reps 1 done nil)
  (while (not done)
    (setq t0 (av-bench-ms))
    (repeat reps (foreach i idxs (av-set-aref v i (+ 1 (av-aref v i)))))
    (setq el (- (av-bench-ms) t0))
    (if (or (>= el *av-bench-min-ms*) (> reps 1048576)) (setq done T) (setq reps (* reps 2))))
  (list el (* (* reps 1.0) (length idxs))))

(defun av-bench-rw-list (lst idxs / reps t0 el done work i)
  (setq reps 1 done nil)
  (while (not done)
    (setq work lst t0 (av-bench-ms))
    (repeat reps (foreach i idxs (setq work (av-bench-list-set work i (+ 1 (nth i work))))))
    (setq el (- (av-bench-ms) t0))
    (if (or (>= el *av-bench-min-ms*) (> reps 1048576)) (setq done T) (setq reps (* reps 2))))
  (list el (* (* reps 1.0) (length idxs))))

(defun av-bench-size (n / lst v idxs rv rl wv wl)
  (setq lst (av-bench-range n))
  (setq v (av-make-array n nil lst nil))
  (setq idxs (av-bench-indices n n))    ; n accès dans une structure de taille n
  (setq rv (av-bench-read-vec  v   idxs))
  (setq rl (av-bench-read-list lst idxs))
  (setq wv (av-bench-rw-vec    v   idxs))
  (setq wl (av-bench-rw-list   lst idxs))
  (av-bench-line
    (strcat (av-bench-pad (itoa n) 6) " | "
            (av-bench-pad (av-bench-us (car rv) (cadr rv)) 8) " | "
            (av-bench-pad (av-bench-us (car rl) (cadr rl)) 8) " | "
            (av-bench-pad (av-bench-ratio (car rl) (cadr rl) (car rv) (cadr rv)) 6) " | "
            (av-bench-pad (av-bench-us (car wv) (cadr wv)) 8) " | "
            (av-bench-pad (av-bench-us (car wl) (cadr wl)) 8) " | "
            (av-bench-pad (av-bench-ratio (car wl) (cadr wl) (car wv) (cadr wv)) 6))))

(defun av-run-benchmarks (/ path)
  (setq path (getenv "BENCH_OUTFILE"))
  (if (and path (/= path "")) (setq *av-bench-out-handle* (open path "w")))
  (av-bench-line "=== autolisp-vector : acces indexe -- vecteur (arbre O(log n)) vs liste (O(n)) ===")
  (av-bench-line "us/op = microsecondes par operation. ratio = liste/vecteur (>1 : vecteur plus rapide).")
  (av-bench-line "read-write vecteur : mutation en place ; liste : reconstruction O(n).")
  (av-bench-line "")
  (av-bench-line "taille |         read-only         |        read-write")
  (av-bench-line "       |  vecteur |    liste | ratio |  vecteur |    liste | ratio")
  (av-bench-line "-------+----------+----------+-------+----------+----------+-------")
  (foreach n (av-bench-sizes) (av-bench-size n))
  (av-bench-line "")
  (if *av-bench-out-handle* (progn (close *av-bench-out-handle*) (setq *av-bench-out-handle* nil)))
  T)

(defun C:BENCH () (av-run-benchmarks) (princ))

(princ "")
