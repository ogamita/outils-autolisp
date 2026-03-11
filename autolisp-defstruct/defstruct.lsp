

Ok, let's see first how we want to implement them.

:type vector is not convenient since we don't have vectors.
(we could map it to :type list silently).

:type list could be implemented exactly as in CL.



:include inheritance -> I want to keep it.
:type                -> Let's keep it:
   :type list gives the simple list representation you want,
   :type vector maps to :type list for now,
   without :type, we implement a scheme that allows for mutable slots.

:named                -> let's keep it; It's a simple name tag to the list
:initial-offset       -> let's keep it, it can be useful.
:print-function       -> let's keep it. No reader yet, but it'll be useful.
:print-object         -> ok, no need to implement it, it's a CLOS thing.
:documentation        -> let's keep it (and ignore it, it's a source thing).
slot :type            -> let's keep it (and ignore it, it's a source thing).
slot :read-only       -> let's keep it: it's easy, don't provide the writer.
setf integration      -> yes, ignore it for now.
BOA constructors      -> we want them, but not only.
multiple constructors -> we want them.
custom low-level representation options -> yes, think it's useful.
Here what I propose:

So remains no :type. I think we should represent structure instances
with symbols. Then we have the value slot and the property slot we can
work with. For example, we could store the slots of the structure in
a list in the value slot, and meta information (the structure type) in
the property list.

(defstruct (point
            (:predicate pointp) ; default is point-p
            (:constructor make-point) ; not boa -> (&key x y)
            (:constructor point (x y))) ; boa -> (x y)
  x y)

(put 'point 'type 'structure)
(put 'point 'structure-slots '(x y))

(defun pointp (s) (and (symbolp s)
                       (equal (get s 'structure-type) 'point)))

(defun point-x (s) (car (eval s)))
(defun point-y (s) (car (cdr (eval s))))

(defun make-point (&rest kv) ; eventually we'll have a defun macro
                             ; implementing &key and other options in
                             ; lambda-lists. 
  ;; CL "pseudo code":
  (loop with slots = (get 'point 'slots)
        for (k v) on kv
        for i = (position k slots)
        if i collect (cons i v) into values
        else (error "Unknown slot keyword ~S" k)
        end
        finally (sort values (function <) ))
  )
…

(make-point :x 1 :y 2)
(let ((instance  (read "struct-13312")))
  (put instance 'structure-type 'point)
  (set instance (list 1 2)))

