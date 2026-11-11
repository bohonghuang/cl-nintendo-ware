(in-package #:nintendo-ware)

(defbinstruct (nintendo-ware-file-byte-order (:type (member :little :big)) (:constructor progn) (:conc-name nil) (:endian :big)) ()
  (%value #xfffe :type (satisfies (unsigned-byte 16) (rcurry #'member '(#xfffe #xfeff))))
  (values :little :type (map null (lambda (ignored) (declare (ignore ignored))
                                   (ecase %value (#xfffe :little) (#xfeff :big))))))

(defbinalias/me nintendo-ware-u16 () (unsigned-byte 16))
(defbinalias/me nintendo-ware-u32 () (unsigned-byte 32))
(defbinalias nintendo-ware-u16/le () nintendo-ware-u16)
(defbinalias nintendo-ware-u32/le () nintendo-ware-u32)

(defbinstruct (nintendo-ware-file-position (:type non-negative-fixnum)
                                           (:constructor progn) (:conc-name nil)) ()
  ($nintendo-ware-file-start 0 :type position)
  (values 0 :type (map null (constantly $nintendo-ware-file-start))))

(defbinstruct/me (nintendo-ware-file-reference (:type t)
                  (:constructor progn) (:conc-name nil)) (tag type)
  (%origin 0 :type (values (pointer position (map null (constantly 0)) $nintendo-ware-file-start)))
  (%position 0 :type position)
  (nil 0 :type (values (pointer (satisfies (unsigned-byte 16) (curry #'eql tag))
                               (map null (constantly 0)) %position)))
  (values nil :type (values (satisfies (nintendo-ware-reference tag (inline type) %origin t) #'identity)))
  (nil nil :type (values (pointer nintendo-ware-file-position (map null (constantly %origin))))))

(defmacro define-nintendo-ware-file-container ()
  (with-gensyms (%origin %header-size %file-size %block-count %padding)
    `(defbinstruct nintendo-ware-file (expected-magic sections/be sections/le)
       ($nintendo-ware-file-start 0 :type position)
       (,%origin 0 :type position)
       (magic #.(coerce "" 'simple-base-string)
              :type (satisfies (simple-base-string 4) (rcurry #'member expected-magic :test #'string=)))
       (endian :little :type nintendo-ware-file-byte-order)
       (,%header-size 20 :type (ecase endian (:little nintendo-ware-u16/le) (:big nintendo-ware-u16/be)))
       (version 0 :type (ecase endian (:little nintendo-ware-u32/le) (:big nintendo-ware-u32/be)))
       (,%file-size 20 :type (ecase endian (:little nintendo-ware-u32/le) (:big nintendo-ware-u32/be)))
       (,%block-count 0 :type (ecase endian (:little nintendo-ware-u16/le) (:big nintendo-ware-u16/be)))
       (,%padding 0 :type (ecase endian (:little nintendo-ware-u16/le) (:big nintendo-ware-u16/be)))
       (sections #() :type (ecase endian
                            (:big (simple-array (inline sections/be) (,%block-count)))
                            (:little (simple-array (inline sections/le) (,%block-count)))))
       ($nintendo-ware-file-end 0 :type position)
       (nil #.(make-array 0 :element-type '(unsigned-byte 8))
            :type (simple-array (unsigned-byte 8)
                     ((- ,%file-size (- $nintendo-ware-file-end ,%origin))))))))

(define-nintendo-ware-file-container)

(defmacro define-nintendo-ware-file (name-and-options &body sections)
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (let ((magic (ensure-list (cadr (assoc :magic options))))
          (union (symbolicate name '-sections)))
      `(progn
         (defbinalias/me (,union (:type t)) ()
           (or ,@(loop for declaration in sections
                       append (destructuring-bind (slot initform &key type tag) declaration
                                (declare (ignore slot initform))
                                (loop for value in (ensure-list tag)
                                      collect `(nintendo-ware-file-reference ,value ,type))))))
         (defbinstruct (,name (:include (nintendo-ware-file ',magic
                                          (,(symbolicate union '/be)) (,union)))
                             ,@(remove :magic options :key #'car)) ())
         ,@(loop for declaration in sections
                 collect (destructuring-bind (slot initform &key type tag) declaration
                           (declare (ignore initform tag))
                           (with-gensyms (file section)
                             `(defun ,(symbolicate name '- slot) (,file)
                                (find-if (lambda (,section)
                                           (typep ,section ',(binstruct::lisp-type type)))
                                         (nintendo-ware-file-sections ,file))))))))))
