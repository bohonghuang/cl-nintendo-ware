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
  "Define LE, an explicit /le alias and shared-type BE layouts."
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (let* ((defined-p body)
           (lambda-list (when (and body (not (member :type (first body)))) (pop body)))
           (type (or (cadr (assoc :type options)) name))
           (little (symbolicate name '#:/le))
           (big (symbolicate name '#:/be)))
      `(progn
         ,@(when defined-p
             `((defbinstruct (,name ,@options) ,lambda-list ,@body)
               (defbinalias (,little (:type ,type)) ,lambda-list
                 (,name ,@lambda-list))
               (defbinstruct/be (,big (:type ,type) (:endian :big)
                                     ,@(remove-if (lambda (option) (member (car option) '(:type :endian))) options))
                   ,lambda-list
                 ,@body)))
         (eval-when (:compile-toplevel :load-toplevel :execute)
           (setf (get ',name 'binstruct::expand-reader-type-expr)
                 (lambda (&rest arguments)
                   (apply #'binstruct::expand-reader-type-expr
                          (ecase (or (and (boundp '*endian*) *endian*) :little)
                            (:little ',little) (:big ',big))
                          arguments))))))))

