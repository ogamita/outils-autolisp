;;; map.lsp --- Famille Common Lisp mapc / mapl / maplist / mapcan / mapcon
;;;
;;; AutoLISP n'implémente nativement que MAPCAR (fonction native et
;;; variadique : elle accepte plusieurs listes). Ce module ajoute les
;;; autres fonctions de la famille « map » de Common Lisp (chapitre 14,
;;; Conses) qui lui manquent : MAPC, MAPL, MAPLIST, MAPCAN et MAPCON.
;;;
;;; AutoLISP ne permet pas de définir de fonction variadique (pas de
;;; &rest) : chaque fonction Common Lisp « (mapX function &rest lists) »
;;; est donc scindée ici en deux fonctions :
;;; - (mapX  fn list)  : la forme usuelle, une seule liste ;
;;; - (mapX* fn lists) : la forme générale, LISTS étant une liste de
;;;   listes (l'équivalent du &rest de Common Lisp, sous forme d'un
;;;   argument explicite).
;;;
;;; Comme MAPCAR, toutes ces fonctions itèrent jusqu'à épuisement de la
;;; liste la plus courte parmi les listes fournies ; ce n'est pas une
;;; erreur que les listes aient des longueurs différentes.
;;;
;;; MAPCAN et MAPCON concatènent les résultats successifs avec APPEND
;;; plutôt qu'avec NCONC (Common Lisp les concatène en place, par effet
;;; de bord, pour l'efficacité) : AutoLISP n'offre pas de modification
;;; destructive de liste fiable, et il n'y a pas de gain de performance
;;; à en attendre ici. Chaque appel de la fonction fournie doit donc
;;; renvoyer une liste ; le résultat final est équivalent à celui de
;;; Common Lisp, simplement non destructif.
;;;
;;; API publique : mapc, mapc*, mapl, mapl*, maplist, maplist*, mapcan,
;;; mapcan*, mapcon, mapcon*.
;;;
;;; Chaque fonction est documentée par un bloc @Global/@Param/@Returns
;;; (voir AGENTS.md du dépôt schms pour la convention).

(setq mapc     'mapc)
(setq mapc*    'mapc*)
(setq mapl     'mapl)
(setq mapl*    'mapl*)
(setq maplist  'maplist)
(setq maplist* 'maplist*)
(setq mapcan   'mapcan)
(setq mapcan*  'mapcan*)
(setq mapcon   'mapcon)
(setq mapcon*  'mapcon*)

;|
  @Global
  (interne) Vrai tant qu'aucune des listes de lists n'est épuisée (nil).
  Utilisée par les variantes * de mapl, maplist et mapcon pour savoir
  quand arrêter d'itérer plusieurs listes de front.
  @Param lists list: liste de listes
  @Returns bool
|;
(defun map--all-non-nil-p (map--lists / map--rest map--ok)
  (setq map--rest map--lists
        map--ok   T)
  (while (and map--rest map--ok)
    (if (null (car map--rest))
      (setq map--ok nil))
    (setq map--rest (cdr map--rest)))
  map--ok)

;|
  @Global
  (interne) Renvoie la liste des cdr de chacune des listes de lists,
  dans le même ordre. Utilisée par les variantes * de mapl, maplist et
  mapcon pour avancer plusieurs listes de front.
  @Param lists list: liste de listes
  @Returns list: liste de listes, chacune amputée de son premier élément
|;
(defun map--cdrs (map--lists / map--rest map--acc)
  (setq map--rest map--lists
        map--acc  nil)
  (while map--rest
    (setq map--acc (cons (cdr (car map--rest)) map--acc))
    (setq map--rest (cdr map--rest)))
  (reverse map--acc))

;|
  @Global
  Applique fn à chaque élément de list, pour ses effets de bord.
  Contrairement à mapcar, les valeurs renvoyées par fn sont ignorées :
  mapc renvoie list elle-même (comme en Common Lisp).
  (mapc 'princ '(1 2 3)) affiche 123 et renvoie (1 2 3).
  @Param fn function: A -> any
  @Param list list: liste d'éléments de A
  @Returns list: list elle-même, inchangée
|;
(defun mapc (mapc-fn mapc-list)
  (mapcar mapc-fn mapc-list)
  mapc-list)

;|
  @Global
  Variante de mapc pour plusieurs listes : fn est appelée avec un
  argument par liste (les éléments de même rang), pour ses effets de
  bord. S'arrête à la fin de la liste la plus courte.
  (mapc* '+ (list '(1 2 3) '(10 20 30))) calcule (+ 1 10) (+ 2 20)
  (+ 3 30) pour rien (aucun effet de bord ici) et renvoie (1 2 3).
  @Param fn function: A1 * A2 * ... -> any: un argument par liste de lists, à la même position
  @Param lists list: liste de listes à parcourir de front
  @Returns list: la première liste de lists, inchangée
|;
(defun mapc* (mapc*-fn mapc*-lists)
  (apply 'mapcar (cons mapc*-fn mapc*-lists))
  (car mapc*-lists))

;|
  @Global
  Comme mapc, mais fn est appelée avec la sous-liste courante (le cdr
  successif de list) plutôt qu'avec son premier élément. Utilisée pour
  ses effets de bord ; renvoie list inchangée.
  (mapl 'princ '(1 2 3)) affiche successivement (1 2 3) (2 3) (3) et
  renvoie (1 2 3).
  @Param fn function: (A list) -> any
  @Param list list: liste de A à parcourir
  @Returns list: list elle-même, inchangée
|;
(defun mapl (mapl-fn mapl-list / mapl-tail)
  (setq mapl-tail mapl-list)
  (while mapl-tail
    (apply mapl-fn (list mapl-tail))
    (setq mapl-tail (cdr mapl-tail)))
  mapl-list)

;|
  @Global
  Variante de mapl pour plusieurs listes : fn est appelée avec une
  sous-liste courante par liste. S'arrête à la fin de la liste la plus
  courte.
  (mapl* 'princ (list '(1 2) '(A B))) affiche successivement
  (1 2) (A B), puis (2) (B).
  @Param fn function: (A1 list) * (A2 list) * ... -> any
  @Param lists list: liste de listes à parcourir de front
  @Returns list: la première liste de lists, inchangée
|;
(defun mapl* (mapl*-fn mapl*-lists / mapl*-tails)
  (setq mapl*-tails mapl*-lists)
  (while (map--all-non-nil-p mapl*-tails)
    (apply mapl*-fn mapl*-tails)
    (setq mapl*-tails (map--cdrs mapl*-tails)))
  (car mapl*-lists))

;|
  @Global
  Comme mapcar, mais fn est appelée avec la sous-liste courante (le
  cdr successif de list) plutôt qu'avec son premier élément ; les
  résultats successifs sont collectés dans une liste.
  (maplist 'reverse '(1 2 3)) => ((3 2 1) (3 2) (3))
  @Param fn function: (A list) -> R
  @Param list list: liste de A à parcourir
  @Returns list: liste de R, un résultat de fn par sous-liste
|;
(defun maplist (maplist-fn maplist-list / maplist-tail maplist-acc)
  (setq maplist-tail maplist-list
        maplist-acc  nil)
  (while maplist-tail
    (setq maplist-acc (cons (apply maplist-fn (list maplist-tail)) maplist-acc))
    (setq maplist-tail (cdr maplist-tail)))
  (reverse maplist-acc))

;|
  @Global
  Variante de maplist pour plusieurs listes : fn est appelée avec une
  sous-liste courante par liste. S'arrête à la fin de la liste la plus
  courte.
  (maplist* 'append (list '(0 1 2) '(A B C))) => ((0 1 2 A B C) (1 2 B C) (2 C))
  @Param fn function: (A1 list) * (A2 list) * ... -> R
  @Param lists list: liste de listes à parcourir de front
  @Returns list: liste de R, un résultat de fn par pas d'itération
|;
(defun maplist* (maplist*-fn maplist*-lists / maplist*-tails maplist*-acc)
  (setq maplist*-tails maplist*-lists
        maplist*-acc   nil)
  (while (map--all-non-nil-p maplist*-tails)
    (setq maplist*-acc (cons (apply maplist*-fn maplist*-tails) maplist*-acc))
    (setq maplist*-tails (map--cdrs maplist*-tails)))
  (reverse maplist*-acc))

;|
  @Global
  Comme mapcar, mais les listes renvoyées successivement par fn sont
  concaténées (via append) plutôt que collectées telles quelles.
  (mapcan (function (lambda (x) (list x x))) '(1 2 3)) => (1 1 2 2 3 3)
  @Param fn function: A -> R list
  @Param list list: liste de A à parcourir
  @Returns list: concaténation des listes de R renvoyées par fn
|;
(defun mapcan (mapcan-fn mapcan-list)
  (apply 'append (mapcar mapcan-fn mapcan-list)))

;|
  @Global
  Variante de mapcan pour plusieurs listes : fn est appelée avec un
  argument par liste (les éléments de même rang). S'arrête à la fin de
  la liste la plus courte.
  (mapcan* 'list (list '(1 2 3) '(A B C))) => (1 A 2 B 3 C)
  @Param fn function: A1 * A2 * ... -> R list
  @Param lists list: liste de listes à parcourir de front
  @Returns list: concaténation des listes de R renvoyées par fn
|;
(defun mapcan* (mapcan*-fn mapcan*-lists)
  (apply 'append (apply 'mapcar (cons mapcan*-fn mapcan*-lists))))

;|
  @Global
  Comme maplist, mais les listes renvoyées successivement par fn sont
  concaténées (via append) plutôt que collectées telles quelles.
  (mapcon 'reverse '(1 2 3)) => (3 2 1 3 2 3)
  @Param fn function: (A list) -> R list
  @Param list list: liste de A à parcourir
  @Returns list: concaténation des listes de R renvoyées par fn
|;
(defun mapcon (mapcon-fn mapcon-list)
  (apply 'append (maplist mapcon-fn mapcon-list)))

;|
  @Global
  Variante de mapcon pour plusieurs listes : fn est appelée avec une
  sous-liste courante par liste. S'arrête à la fin de la liste la plus
  courte.
  (mapcon* 'append (list '(0 1 2) '(A B C))) => (0 1 2 A B C 1 2 B C 2 C)
  @Param fn function: (A1 list) * (A2 list) * ... -> R list
  @Param lists list: liste de listes à parcourir de front
  @Returns list: concaténation des listes de R renvoyées par fn
|;
(defun mapcon* (mapcon*-fn mapcon*-lists)
  (apply 'append (maplist* mapcon*-fn mapcon*-lists)))
