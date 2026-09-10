;;; aloop.lsp --- Boucles imbriquées décrites par une liste de clauses
;;;
;;; Port, sous forme de FONCTION (et non de macro), de la macro Elisp
;;; `rloop' de ~/src/public/emacs/pjb-emacs.el :
;;;
;;;   (defmacro rloop (clauses &rest body)
;;;     (if (null clauses)
;;;         `(progn ,@body)
;;;         `(loop ,@(car clauses) do (rloop ,(cdr clauses) ,@body))))
;;;
;;; `rloop' développait CLAUSES (une liste de fragments de clause
;;; `loop' Common Lisp) en boucles `loop' imbriquées, la première
;;; clause étant la boucle la plus externe. AutoLISP n'a ni macro
;;; utilisable comme en Elisp/Common Lisp ni boucle `loop' : ALOOP est
;;; donc une fonction ordinaire. Les clauses y sont de simples données
;;; (évaluées normalement, plus de « for var » : la variable de chaque
;;; niveau est liée positionnellement, via un LAMBDA) et un callback FN
;;; est appelé une fois par combinaison de valeurs, au niveau le plus
;;; imbriqué -- exactement comme des boucles for imbriquées classiques.
;;;
;;; Chaque clause est une liste décrivant une dimension d'itération :
;;;
;;; - (from start to end)      : entiers de start à end inclus (pas +1)
;;; - (from start upto end)    : synonyme de to (comme en Common Lisp LOOP)
;;; - (from start below end)   : entiers de start à end exclu (pas +1)
;;; - (from start downto end)  : entiers de start à end inclus (pas -1)
;;; - (from start above end)   : entiers de start à end exclu (pas -1)
;;; - (to end), (upto end), (below end), (downto end), (above end)
;;;                            : comme ci-dessus, start implicite = 0
;;; - toutes les clauses numériques ci-dessus acceptent un `by' final
;;;   donnant le pas, en grandeur (toujours positif, son sens -- +/- --
;;;   est déjà donné par le mot-clé de borne) : (below 10 by 2) =>
;;;   0 2 4 6 8 ; (from 10 downto 0 by 3) => 10 7 4 1. Sans `by', le
;;;   pas est 1.
;;; - (from start then step-fn bound-kw end) : pas calculé plutôt
;;;   qu'arithmétique -- la valeur suivante est (step-fn valeur
;;;   courante) au lieu de valeur+pas ; bound-kw/end (to/upto/below/
;;;   downto/above, comme ci-dessus) restent obligatoires : ALOOP
;;;   matérialise chaque clause en liste, il lui faut donc un arrêt
;;;   garanti -- pas de séquence infinie. Ex. :
;;;     (from 1 then (function (lambda (x) (* 2 x))) below 100)
;;;     => 1 2 4 8 16 32 64
;;; - (in list)      : les éléments de list, dans l'ordre (comme le
;;;   `for var in list' de Common Lisp LOOP)
;;; - (on list)      : les sous-listes successives de list, list elle-
;;;   même comprise (comme `for var on list') -- ex. (on (a b c)) =>
;;;   (a b c) (b c) (c)
;;; - (in list) et (on list) acceptent un `by' final donnant la
;;;   fonction de progression d'une sous-liste à la suivante (défaut :
;;;   cdr) ; n'importe quelle fonction d'un argument convient --
;;;   cdr, cddr, ou une fonction quelconque comme (function (lambda
;;;   (l) (member cible l))) pour sauter jusqu'à la prochaine
;;;   occurrence de cible. Le parcours s'arrête dès que la fonction ne
;;;   renvoie plus une liste non vide (nil compris).
;;;
;;; AutoLISP n'ayant pas de fonctions variadiques, les clauses sont
;;; regroupées dans une seule liste (et non un argument par clause) ;
;;; FN est un lambda prenant autant d'arguments qu'il y a de clauses,
;;; dans le même ordre (1re clause = 1er argument = boucle la plus
;;; externe ; dernière clause = dernier argument = boucle la plus
;;; interne, celle qui varie le plus vite).
;;;
;;; ALOOP renvoie toujours nil (comme `rloop', dont le corps ne
;;; collecte rien).
;;;
;;; Exemple (d'après l'énoncé) :
;;;   (aloop (list '(from 1 to 10) '(below 3) '(upto 5)
;;;                '(from 9 downto 1) '(in (a b c))
;;;                (list 'in my-list))
;;;          (function (lambda (a b c d e f) ...)))

(setq aloop 'aloop)

;|
  @Global
  (interne) Signale une erreur aloop : affiche message puis le
  transmet à error.
  @Param message string: description de l'erreur
  @Returns ne revient pas (error)
|;
(defun aloop--fail (aloop-message)
  (prompt (strcat "\naloop: " aloop-message))
  (error aloop-message))

;|
  @Global
  (interne) Matérialise en liste la plage d'entiers de start à end,
  en avançant de step (positif ou négatif, jamais nul) à chaque pas ;
  end fait partie de la plage seulement si inclusive est vrai.
  @Param start int: première valeur
  @Param end int: borne
  @Param step int: pas, positif ou négatif
  @Param inclusive bool: vrai si end fait partie de la plage
  @Returns int list: valeurs, dans l'ordre de parcours
|;
(defun aloop--range (aloop-start aloop-end aloop-step aloop-inclusive / aloop-values aloop-value)
  (setq aloop-values nil
        aloop-value  aloop-start)
  (while (if (> aloop-step 0)
           (if aloop-inclusive (<= aloop-value aloop-end) (< aloop-value aloop-end))
           (if aloop-inclusive (>= aloop-value aloop-end) (> aloop-value aloop-end)))
    (setq aloop-values (cons aloop-value aloop-values))
    (setq aloop-value (+ aloop-value aloop-step)))
  (reverse aloop-values))

;|
  @Global
  (interne) Comme aloop--range, mais la valeur suivante est calculée
  en appelant step-fn sur la valeur courante plutôt qu'en ajoutant un
  pas arithmétique -- pour la clause (from start then step-fn
  bound-kw end).
  @Param start int: première valeur
  @Param step-fn function: A -> A: calcule la valeur suivante à partir de la courante
  @Param bound-kw symbol: to, upto, below, downto ou above
  @Param end int: borne
  @Returns list: valeurs, dans l'ordre de parcours
|;
(defun aloop--computed-range (aloop-start aloop-step-fn aloop-bound-kw aloop-end / aloop-values aloop-value)
  (if (null aloop-bound-kw)
    (aloop--fail "(from start then step-fn ...) doit être suivie d'une borne : to/upto/below/downto/above end"))
  (setq aloop-values nil
        aloop-value  aloop-start)
  (while
    (cond
      ((or (= aloop-bound-kw 'to) (= aloop-bound-kw 'upto)) (<= aloop-value aloop-end))
      ((= aloop-bound-kw 'below)                            (<  aloop-value aloop-end))
      ((= aloop-bound-kw 'downto)                           (>= aloop-value aloop-end))
      ((= aloop-bound-kw 'above)                            (>  aloop-value aloop-end))
      (T (aloop--fail (strcat "mot-clé de borne inconnu : " (vl-prin1-to-string aloop-bound-kw)))))
    (setq aloop-values (cons aloop-value aloop-values))
    (setq aloop-value (apply aloop-step-fn (list aloop-value))))
  (reverse aloop-values))

;|
  @Global
  (interne) Matérialise en liste la plage d'entiers décrite par start,
  un mot-clé de borne (to, upto, below, downto ou above), end et un
  pas by éventuel (grandeur positive, nil pour le pas par défaut : 1).
  @Param start int: première valeur
  @Param bound-kw symbol: to, upto, below, downto ou above
  @Param end int: borne
  @Param by int|nil: grandeur du pas (positive), nil pour 1
  @Returns int list: valeurs, dans l'ordre de parcours
|;
(defun aloop--bound-values (aloop-start aloop-bound-kw aloop-end aloop-by / aloop-step)
  (if (and aloop-by (<= aloop-by 0))
    (aloop--fail "le pas de by doit être strictement positif"))
  (setq aloop-step (if aloop-by aloop-by 1))
  (cond
    ((or (= aloop-bound-kw 'to) (= aloop-bound-kw 'upto))
      (aloop--range aloop-start aloop-end aloop-step T))
    ((= aloop-bound-kw 'below)
      (aloop--range aloop-start aloop-end aloop-step nil))
    ((= aloop-bound-kw 'downto)
      (aloop--range aloop-start aloop-end (- aloop-step) T))
    ((= aloop-bound-kw 'above)
      (aloop--range aloop-start aloop-end (- aloop-step) nil))
    (T
      (aloop--fail (strcat "mot-clé de borne inconnu : " (vl-prin1-to-string aloop-bound-kw))))))

;|
  @Global
  (interne) Vrai si x est une liste non vide (une cellule cons) --
  false pour nil et pour tout atome. Sert de condition d'arrêt au
  parcours de (in list) / (on list) : il s'arrête dès que la fonction
  de progression cesse de renvoyer une liste non vide.
  @Param x any: valeur à tester
  @Returns bool
|;
(defun aloop--nonempty-list-p (aloop-x)
  (and aloop-x (= (type aloop-x) 'LIST)))

;|
  @Global
  (interne) La fonction de progression à utiliser pour (in list) /
  (on list) : by si non nil, sinon cdr par défaut.
  @Param by function|nil: fonction de progression explicite, ou nil
  @Returns function
|;
(defun aloop--step-fn (aloop-by)
  (if aloop-by aloop-by 'cdr))

;|
  @Global
  (interne) Matérialise en liste les éléments successifs de list --
  clause (in list [by step-fn]) : bind le CAR de chaque sous-liste
  rencontrée en avançant via step-fn (cdr par défaut) jusqu'à ce
  qu'elle ne renvoie plus une liste non vide.
  @Param list list: liste de départ
  @Param by function|nil: fonction de progression explicite, ou nil pour cdr
  @Returns list: éléments rencontrés, dans l'ordre de parcours
|;
(defun aloop--in-values (aloop-list aloop-by / aloop-step aloop-tail aloop-values)
  (setq aloop-step   (aloop--step-fn aloop-by)
        aloop-tail   aloop-list
        aloop-values nil)
  (while (aloop--nonempty-list-p aloop-tail)
    (setq aloop-values (cons (car aloop-tail) aloop-values))
    (setq aloop-tail (apply aloop-step (list aloop-tail))))
  (reverse aloop-values))

;|
  @Global
  (interne) Matérialise en liste les sous-listes successives de list,
  list elle-même comprise -- clause (on list [by step-fn]) : avance
  via step-fn (cdr par défaut) jusqu'à ce qu'elle ne renvoie plus une
  liste non vide.
  @Param list list: liste de départ
  @Param by function|nil: fonction de progression explicite, ou nil pour cdr
  @Returns list list: sous-listes rencontrées, dans l'ordre de parcours
|;
(defun aloop--on-values (aloop-list aloop-by / aloop-step aloop-tail aloop-values)
  (setq aloop-step   (aloop--step-fn aloop-by)
        aloop-tail   aloop-list
        aloop-values nil)
  (while (aloop--nonempty-list-p aloop-tail)
    (setq aloop-values (cons aloop-tail aloop-values))
    (setq aloop-tail (apply aloop-step (list aloop-tail))))
  (reverse aloop-values))

;|
  @Global
  (interne) Sépare un éventuel suffixe (by valeur) en fin de clause :
  renvoie (list clause-sans-son-suffixe valeur), ou (list clause nil)
  s'il n'y en a pas.
  @Param clause list: clause aloop, avec ou sans suffixe by
  @Returns list: (clause-dépouillée valeur-de-by-ou-nil)
|;
(defun aloop--split-by (aloop-clause / aloop-n)
  (setq aloop-n (length aloop-clause))
  (if (and (>= aloop-n 4) (= (nth (- aloop-n 2) aloop-clause) 'by))
    (list (reverse (cddr (reverse aloop-clause))) (nth (1- aloop-n) aloop-clause))
    (list aloop-clause nil)))

;|
  @Global
  (interne) Matérialise en liste les valeurs décrites par une seule
  clause aloop -- voir la grammaire des clauses en tête de fichier.
  @Param clause list: clause aloop (from/to/upto/below/downto/above/in/on, voir grammaire)
  @Returns list: valeurs de la clause, dans l'ordre de parcours
|;
(defun aloop--clause-values (aloop-clause / aloop-split aloop-core aloop-by aloop-head)
  (setq aloop-split (aloop--split-by aloop-clause)
        aloop-core  (car aloop-split)
        aloop-by    (cadr aloop-split))
  (setq aloop-head (car aloop-core))
  (cond
    ((= aloop-head 'in)
      (aloop--in-values (cadr aloop-core) aloop-by))
    ((= aloop-head 'on)
      (aloop--on-values (cadr aloop-core) aloop-by))
    ((and (= aloop-head 'from) (= (nth 2 aloop-core) 'then))
      (aloop--computed-range (cadr aloop-core) (nth 3 aloop-core) (nth 4 aloop-core) (nth 5 aloop-core)))
    ((= aloop-head 'from)
      (aloop--bound-values (cadr aloop-core) (nth 2 aloop-core) (nth 3 aloop-core) aloop-by))
    (T
      (aloop--bound-values 0 aloop-head (cadr aloop-core) aloop-by))))

;|
  @Global
  (interne) Cœur récursif de aloop : parcourt clauses niveau par
  niveau (la tête de clauses est le niveau le plus externe), en
  accumulant dans values (à l'envers) la valeur choisie à chaque
  niveau ; une fois clauses épuisée, applique fn aux valeurs
  accumulées, remises dans l'ordre des clauses d'origine.
  @Param clauses list: clauses aloop restant à traiter
  @Param fn function: A1 * A2 * ... -> any: callback, un argument par clause d'origine
  @Param values list: valeurs déjà choisies aux niveaux englobants, à l'envers
  @Returns nil
|;
(defun aloop--rec (aloop-clauses aloop-fn aloop-values / aloop-remaining)
  (if (null aloop-clauses)
    (apply aloop-fn (reverse aloop-values))
    (progn
      (setq aloop-remaining (aloop--clause-values (car aloop-clauses)))
      (while aloop-remaining
        (aloop--rec (cdr aloop-clauses) aloop-fn (cons (car aloop-remaining) aloop-values))
        (setq aloop-remaining (cdr aloop-remaining)))))
  nil)

;|
  @Global
  Exécute des boucles imbriquées décrites par clauses : pour chaque
  combinaison de valeurs (la première clause variant le moins vite,
  la dernière le plus vite -- comme des boucles for imbriquées dans
  cet ordre), appelle fn avec une valeur par clause, dans l'ordre de
  clauses. Voir la grammaire des clauses en tête de fichier.
  (aloop (list '(below 2) '(in (a b)))
         (function (lambda (i s) (princ (list i s)))))
  affiche (0 A)(0 B)(1 A)(1 B).
  @Param clauses list: liste de clauses aloop, une par niveau de boucle
  @Param fn function: A1 * A2 * ... -> any: callback, un argument par clause
  @Returns nil
|;
(defun aloop (aloop-clauses aloop-fn)
  (aloop--rec aloop-clauses aloop-fn nil))
