(in-package #:cl-nintendo-ware)

(defbinalias/me (nintendo-ware-reference-null (:type null)) ()
  (map (satisfies (signed-byte 32) (curry #'= -1))
       (constantly nil) (constantly -1)))

(defbinstruct/me (nintendo-ware-reference-target (:type t) (:constructor progn) (:conc-name nil)) (type base &optional (size -1))
  ($nintendo-ware-reference-start 0 :type position)
  ($nintendo-ware-reference-end 0 :type (ecase (<= base $nintendo-ware-reference-start)
                                          ((t) (pointer position (map null (constantly size)) $nintendo-ware-reference-start))
                                          ((nil) (map (null) (constantly (1- $nintendo-ware-reference-start)) (constantly nil)))))
  (values nil :type (ecase (<= base $nintendo-ware-reference-start)
                     ((t) (inline type))
                     ((nil) null)))
  ($nintendo-ware-reference-end 0 :type position))

(defbinstruct (nintendo-ware-reference-size (:type (unsigned-byte 32)) (:constructor progn) (:conc-name nil)) ()
  (%start 0 :type (values (pointer position (map null (constantly 0))
                                 $nintendo-ware-reference-start)))
  (%end 0 :type (values (pointer position (map null (constantly 0))
                               $nintendo-ware-reference-end)))
  (values 0 :type (map null (constantly (- %end %start)))))

(defbinstruct/me (nintendo-ware-reference (:type t)
                  (:constructor progn) (:conc-name nil)) (tag type base)
  (%tag 0 :type (unsigned-byte 16))
  (nil 0 :type (unsigned-byte 16))
  (values nil :type (pointer (nintendo-ware-reference-target (inline type) base)
                            (satisfies (signed-byte 32)
                              (lambda (offset)
                                (and (<= -1 offset) (or (= offset -1) (= %tag tag)))))
                            base)))

(defbinstruct/me (nintendo-ware-sized-reference (:type t)
                  (:constructor progn) (:conc-name nil)) (tag type base)
  (%tag 0 :type (unsigned-byte 16))
  (nil 0 :type (unsigned-byte 16))
  (values nil :type (pointer (nintendo-ware-reference-target (inline type) base %size)
                            (satisfies (signed-byte 32)
                              (lambda (offset)
                                (and (<= -1 offset) (or (= offset -1) (= %tag tag)))))
                            base))
  (%size 0 :type (unsigned-byte 32)))

(defbinstruct/me (nintendo-ware-reference-octets
                  (:type (simple-array (unsigned-byte 8) (*)))
                  (:constructor progn) (:conc-name nil)) ()
  (%size 0 :type nintendo-ware-reference-size)
  (values #.(make-array 0 :element-type '(unsigned-byte 8))
          :type (simple-array (unsigned-byte 8) (%size))))

(defbinstruct/me (nintendo-ware-reference-string (:type simple-base-string)
                  (:constructor progn) (:conc-name nil)) ()
  (%size 0 :type nintendo-ware-reference-size)
  (values #.(coerce "" 'simple-base-string) :type (simple-base-string %size)))

(defmacro define-nintendo-ware-reference (name-and-options lambda-list &body variants)
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (let ((reference (if (cadr (assoc :sized options))
                         'nintendo-ware-sized-reference
                         'nintendo-ware-reference)))
      (with-gensyms (base)
        `(defbinalias/me (,name (:type (or null ,@(remove-duplicates
                                                  (mapcar (lambda (variant)
                                                            (binstruct::lisp-type (second variant)))
                                                          variants)
                                                  :test #'equal))))
             (,base ,@lambda-list)
           (or ,@(loop for (tag type) in variants
                       collect `(,reference ,tag ,type ,base))))))))

(defmacro define-nintendo-ware-reference-array
    (name lambda-list (binding (function reference) &rest arguments))
  (ecase function
    ((function)
     (with-gensyms (%position %count)
       (let ((type (ecase binding
                     (curry `(,reference ,@arguments ,%position))
                     (rcurry `(,reference ,%position ,@arguments)))))
         `(defbinstruct/me (,name (:type (simple-array ,(binstruct::lisp-type reference) (*)))
                                 (:constructor progn) (:conc-name nil)) ,lambda-list
            (,%position 0 :type position)
            (,%count 0 :type (unsigned-byte 32))
            (values #() :type (simple-array ,type (,%count)))))))))
