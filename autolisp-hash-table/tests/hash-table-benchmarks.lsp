;;; hash-table-benchmarks.lsp --- Benchmark de vitesse : table de hachage vs a-list.
;;;
;;; Compare ah-hash-table (accès O(1) moyen) à une a-list AutoLISP (assoc en
;;; O(n)), en lecture seule et en lecture-écriture, pour des tailles
;;; croissantes. Objectif : valider l'intérêt de la table en vitesse ET en
;;; mutabilité (puthash mute en place ; l'a-list doit être reconstruite).
;;;
;;; Portable clautolisp / BricsCAD / AutoCAD (timer : (getvar "MILLISECS")).
;;; Dépend de autolisp-vector. Sortie : stdout + fichier artefact si
;;; $BENCH_OUTFILE est défini. Point d'entrée : (ah-run-benchmarks) / (C:BENCH)

(setq *ah-bench-min-ms* 50)
(setq *ah-bench-out-handle* nil)

(defun ah-bench-sizes () '(5 10 50 100 500 1000))

(defun ah-bench-ms () (getvar "MILLISECS"))

(defun ah-bench-line (s)
  (princ s) (princ "\n")
  (if *ah-bench-out-handle* (write-line s *ah-bench-out-handle*)))

(defun ah-bench-alist (n / i l)
  (setq i n l nil) (while (> i 0) (setq i (1- i) l (cons (cons i i) l))) l)

(defun ah-bench-keys (count size / l st)
  (setq l nil st 1)
  (repeat count
    (setq st (rem (+ (* st 30637) 17389) 32749))
    (setq l (cons (rem st size) l)))
  l)

;; met à jour la paire (key . val) d'une a-list : reconstruction O(n)
(defun ah-bench-alist-put (alist key val / out cell done)
  (setq out nil done nil)
  (foreach cell alist
    (if (and (not done) (equal (car cell) key))
      (progn (setq out (cons (cons key val) out)) (setq done T))
      (setq out (cons cell out))))
  (if (not done) (setq out (cons (cons key val) out)))
  (reverse out))

(defun ah-bench-us (ms ops / s)
  (setq s (rtos (/ (* ms 1000.0) ops) 2 3))
  (if (vl-string-search "," s) (setq s (vl-string-subst "." "," s)))
  s)

(defun ah-bench-ratio (msb opsb ms ops / s)
  (setq s (rtos (/ (/ (* msb 1.0) opsb) (/ (* ms 1.0) ops)) 2 2))
  (if (vl-string-search "," s) (setq s (vl-string-subst "." "," s)))
  s)

(defun ah-bench-pad (s w / o) (setq o s) (while (< (strlen o) w) (setq o (strcat " " o))) o)

;; --- mesures : renvoient (list ms-total ops-total) ---
(defun ah-bench-read-ht (ht keys / reps t0 el s done)
  (setq reps 1 done nil)
  (while (not done)
    (setq s 0 t0 (ah-bench-ms))
    (repeat reps (foreach k keys (setq s (+ s (ah-gethash ht k 0)))))
    (setq el (- (ah-bench-ms) t0))
    (if (or (>= el *ah-bench-min-ms*) (> reps 1048576)) (setq done T) (setq reps (* reps 2))))
  (list el (* (* reps 1.0) (length keys))))

(defun ah-bench-read-alist (al keys / reps t0 el s done)
  (setq reps 1 done nil)
  (while (not done)
    (setq s 0 t0 (ah-bench-ms))
    (repeat reps (foreach k keys (setq s (+ s (cdr (assoc k al))))))
    (setq el (- (ah-bench-ms) t0))
    (if (or (>= el *ah-bench-min-ms*) (> reps 1048576)) (setq done T) (setq reps (* reps 2))))
  (list el (* (* reps 1.0) (length keys))))

(defun ah-bench-rw-ht (ht keys / reps t0 el done k)
  (setq reps 1 done nil)
  (while (not done)
    (setq t0 (ah-bench-ms))
    (repeat reps (foreach k keys (ah-puthash ht k (+ 1 (ah-gethash ht k 0)))))
    (setq el (- (ah-bench-ms) t0))
    (if (or (>= el *ah-bench-min-ms*) (> reps 1048576)) (setq done T) (setq reps (* reps 2))))
  (list el (* (* reps 1.0) (length keys))))

(defun ah-bench-rw-alist (al keys / reps t0 el done work k)
  (setq reps 1 done nil)
  (while (not done)
    (setq work al t0 (ah-bench-ms))
    (repeat reps (foreach k keys (setq work (ah-bench-alist-put work k (+ 1 (cdr (assoc k work)))))))
    (setq el (- (ah-bench-ms) t0))
    (if (or (>= el *ah-bench-min-ms*) (> reps 1048576)) (setq done T) (setq reps (* reps 2))))
  (list el (* (* reps 1.0) (length keys))))

(defun ah-bench-size (n / al ht keys i rh ra wh wa)
  (setq al (ah-bench-alist n))
  (setq ht (ah-make-hash-table 'equal n 2.0 0.5))
  (setq i 0) (while (< i n) (ah-puthash ht i i) (setq i (1+ i)))
  (setq keys (ah-bench-keys n n))
  (setq rh (ah-bench-read-ht    ht  keys))
  (setq ra (ah-bench-read-alist al  keys))
  (setq wh (ah-bench-rw-ht      ht  keys))
  (setq wa (ah-bench-rw-alist   al  keys))
  (ah-bench-line
    (strcat (ah-bench-pad (itoa n) 6) " | "
            (ah-bench-pad (ah-bench-us (car rh) (cadr rh)) 8) " | "
            (ah-bench-pad (ah-bench-us (car ra) (cadr ra)) 8) " | "
            (ah-bench-pad (ah-bench-ratio (car ra) (cadr ra) (car rh) (cadr rh)) 6) " | "
            (ah-bench-pad (ah-bench-us (car wh) (cadr wh)) 8) " | "
            (ah-bench-pad (ah-bench-us (car wa) (cadr wa)) 8) " | "
            (ah-bench-pad (ah-bench-ratio (car wa) (cadr wa) (car wh) (cadr wh)) 6))))

(defun ah-run-benchmarks (/ path)
  (setq path (getenv "BENCH_OUTFILE"))
  (if (and path (/= path "")) (setq *ah-bench-out-handle* (open path "w")))
  (ah-bench-line "=== autolisp-hash-table : acces par cle -- table de hachage O(1) vs a-list (assoc O(n)) ===")
  (ah-bench-line "us/op = microsecondes par operation. ratio = a-list/table (>1 : table plus rapide).")
  (ah-bench-line "read-write table : puthash en place ; a-list : reconstruction O(n).")
  (ah-bench-line "")
  (ah-bench-line "taille |         read-only         |        read-write")
  (ah-bench-line "       |    table |   a-list | ratio |    table |   a-list | ratio")
  (ah-bench-line "-------+----------+----------+-------+----------+----------+-------")
  (foreach n (ah-bench-sizes) (ah-bench-size n))
  (ah-bench-line "")
  (if *ah-bench-out-handle* (progn (close *ah-bench-out-handle*) (setq *ah-bench-out-handle* nil)))
  T)

(defun C:BENCH () (ah-run-benchmarks) (princ))

(princ "")
