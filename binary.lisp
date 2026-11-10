(in-package #:nintendo-ware)

(defvar *endian*)

(defmacro %defbinalias (defbinstruct name-and-options lambda-list parser)
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (destructuring-bind (&key (type name typep)) (mappend #'identity options)
      (unless typep
        (let ((inferred-type (binstruct::lisp-type parser)))
          (unless (eq inferred-type t) (setf type inferred-type))))
      `(,defbinstruct (,name (:type ,type) (:constructor progn) (:conc-name nil))
           ,lambda-list
         (values nil :type ,parser)))))

(defmacro defbinalias (name-and-options lambda-list parser)
  `(%defbinalias defbinstruct ,name-and-options ,lambda-list ,parser))

(defmacro defbinalias/me (name-and-options lambda-list parser)
  `(%defbinalias defbinstruct/me ,name-and-options ,lambda-list ,parser))

;; Expand here, not in the outer PROGN: the default definition and its Lisp
;; type have been registered before its big-endian reader is expanded.
(defmacro defbinstruct/be (name-and-options lambda-list &body slots)
  (let ((*endian* :big))
    (destructuring-bind (name &rest options) name-and-options
      ;; Binstruct's :include calls the ancestor parser directly rather than
      ;; going through a field's type hook.
      (let ((options (loop for (key value) in options
                           collect (if (eq key :include)
                                       (list key (binstruct::expand-reader-type value))
                                       (list key value)))))
        (macroexpand `(defbinstruct (,name ,@options) ,lambda-list ,@slots))))))

(defmacro defbinstruct/me (name-and-options &body body)
  "Define LE and shared-type BE layouts and property-based type expansion."
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (let* ((defined-p body)
           (lambda-list (when (and body (not (member :type (first body)))) (pop body)))
           (type (or (cadr (assoc :type options)) name))
           (inline-parameters
             (labels ((collect-parameters (form)
                        (when (consp form)
                          (if (eq (car form) 'inline)
                              (list (second form))
                              (mappend #'collect-parameters form)))))
               (collect-parameters body)))
           (big (symbolicate name '#:/be)))
      `(progn
         ,@(when defined-p
             `((defbinstruct (,name ,@options) ,lambda-list ,@body)
               (defbinstruct/be (,big (:type ,type) (:endian :big)
                                     ,@(remove-if (lambda (option) (member (car option) '(:type :endian))) options))
                   ,lambda-list
                 ,@body)))
         (eval-when (:compile-toplevel :load-toplevel :execute)
           (setf (get ',name 'binstruct::expand-reader-type-expr)
                 (lambda (&rest arguments)
                   (cons (ecase (or (and (boundp '*endian*) *endian*) :little)
                           (:little ',name) (:big ',big))
                         ,(if inline-parameters
                              `(mapcar (lambda (argument parameter)
                                         (if (member parameter ',inline-parameters)
                                             (let ((binstruct::*place* (binstruct::place-null))
                                                   (binstruct::*slots* nil))
                                               (binstruct::expand-reader-type-unit
                                                argument
                                                :endian (or (and (boundp '*endian*) *endian*) :little)
                                                :alignment binstruct::+alignment-default+))
                                             argument))
                                       arguments ',(parsonic::lambda-list-arguments lambda-list))
                              'arguments)))
                 (get ',name 'binstruct::expand-writer-type-expr)
                 (lambda (&rest arguments)
                   `(progn
                      ,(binstruct::finish-writer-partial-byte)
                      (,(ecase (or (and (boundp '*endian*) *endian*) :little)
                          (:little ',(binstruct::emitter-name-symbol name))
                          (:big ',(binstruct::emitter-name-symbol big)))
                       ,binstruct::*output* ,binstruct::*value* ,@arguments)))))))))

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

