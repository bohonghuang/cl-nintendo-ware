(in-package #:cl-nintendo-ware)

(defbinalias/me (nintendo-ware-reference-null (:type null)) ()
  (map (satisfies (signed-byte 32) (curry #'= -1))
       (constantly nil) (constantly -1)))

(defbinstruct/me (nintendo-ware-reference-target (:type t)
                  (:constructor progn) (:conc-name nil)) (type base size-base)
  (%start 0 :type position)
  (values nil :type (ecase (<= base %start)
                     ((t) (inline type))
                     ((nil) null)))
  (%end 0 :type position)
  (nil nil :type (ecase (null size-base)
                   ((t) (null))
                   ((nil) (binstruct::peek
                           (map (unsigned-byte 32) #'identity
                                (constantly (- %end %start)))
                           size-base)))))

;; Only sized targets may query this anchor; capture it before reading children.
(defbinalias/me nintendo-ware-reference-size ()
  (pointer (unsigned-byte 32) (map (null) (constantly 0) (constantly nil))
           $nintendo-ware-reference-size))

(defbinstruct/me (nintendo-ware-reference-value (:type t)
                  (:constructor progn) (:conc-name nil)) (tag type base &optional sized)
  (%tag 0 :type (unsigned-byte 16))
  (nil 0 :type (unsigned-byte 16))
  (values nil :type (pointer (nintendo-ware-reference-target
                             (inline type) base (when %size $nintendo-ware-reference-size))
                            (satisfies (signed-byte 32)
                              (lambda (offset) (and (<= 0 offset) (= %tag tag))))
                            base))
  ($nintendo-ware-reference-size 0 :type position)
  (%size (when sized 0) :type (ecase sized
                                ((t) (unsigned-byte 32))
                                ((nil) (null)))))

;; A null at a zero-based detached body must not seek to position -1.
(defbinstruct/me (nintendo-ware-null-reference (:type null)
                  (:constructor progn) (:conc-name nil)) (sized)
  (nil 0 :type (unsigned-byte 16))
  (nil 0 :type (unsigned-byte 16))
  (values nil :type nintendo-ware-reference-null)
  (nil 0 :type (ecase sized ((t) (unsigned-byte 32)) ((nil) null))))

(defbinalias/me (nintendo-ware-reference (:type t)) (tag type base &optional sized)
  (or (nintendo-ware-null-reference sized)
      (nintendo-ware-reference-value tag (inline type) base sized)))

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
    (let ((sized (cadr (assoc :sized options))))
      (with-gensyms (base)
        `(defbinalias/me (,name (:type (or null ,@(remove-duplicates
                                                  (mapcar (lambda (variant)
                                                            (binstruct::lisp-type (second variant)))
                                                          variants)
                                                  :test #'equal))))
             (,base ,@lambda-list)
           (or ,@(loop for (tag type) in variants
                       collect `(nintendo-ware-reference ,tag ,type ,base ,sized))))))))

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

(defbinstruct/me (nintendo-ware-data-reference
                  (:type (or null (simple-array (unsigned-byte 8) (*))))
                  (:constructor progn) (:conc-name nil)) (tags data &optional size)
  (%tag 0 :type (unsigned-byte 16))
  (nil 0 :type (unsigned-byte 16))
  (%offset -1 :type (satisfies (signed-byte 32)
                     (lambda (offset)
                       (and (<= -1 offset)
                            (or (= -1 offset) (member %tag tags))))))
  (%size 0 :type (ecase (null size)
                  ((nil) (map null (constantly size)))
                  ((t) (unsigned-byte 32))))
  (values nil :type (map null
                     (lambda (ignored)
                       (declare (ignore ignored))
                       (unless (= %offset -1)
                         (unless data
                           (error 'binstruct::deserialize-error
                                  :input nil :position nil :info "Missing data section"))
                         (nintendo-ware-parse
                          (values (pointer (simple-array (unsigned-byte 8) (%size))
                                           (map null (constantly %offset))))
                          data))))))
