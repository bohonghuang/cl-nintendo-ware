(in-package #:nintendo-ware)

(defvar *endian*)

;; Same alias definition as cl-nitro/common.lisp.
(defmacro defbinalias (name-and-options lambda-list parser)
  (destructuring-bind (name &rest options) (alexandria:ensure-list name-and-options)
    (destructuring-bind (&key (type name typep)) (alexandria:mappend #'identity options)
      (unless typep
        (let ((inferred-type (binstruct::lisp-type parser)))
          (unless (eq inferred-type t) (setf type inferred-type))))
      `(defbinstruct (,name (:type ,type) (:constructor progn) (:conc-name nil))
           ,lambda-list
         (values nil :type ,parser)))))

(defmacro %define-endian-reader (name)
  (let ((little (alexandria:symbolicate name '#:/le))
        (big (alexandria:symbolicate name '#:/be)))
    `(eval-when (:compile-toplevel :load-toplevel :execute)
       (defmethod binstruct::expand-reader-type-expr ((name (eql ',name)) &rest arguments)
         (if (boundp '*endian*)
             (cons (ecase *endian* (:little ',little) (:big ',big)) arguments)
             (call-next-method))))))

;; Expand here, not in the outer PROGN: the default definition and its Lisp
;; type have been registered before its big-endian reader is expanded.
(defmacro %defbinstruct/be (name-and-options lambda-list &body slots)
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
  "Define default little-endian and /le, /be readers sharing one Lisp type.
An optional lambda list precedes the fields, as in DEFBINSTRUCT."
  (destructuring-bind (name &rest options) (alexandria:ensure-list name-and-options)
    (let* ((lambda-list (when (and body (not (member :type (first body)))) (pop body)))
           (type (or (cadr (assoc :type options)) name))
           (little (alexandria:symbolicate name '#:/le))
           (big (alexandria:symbolicate name '#:/be)))
      `(progn
         (defbinstruct ,name-and-options ,lambda-list ,@body)
         (%defbinstruct/be (,big (:type ,type) (:endian :big)
                                ,@(remove-if (lambda (option) (member (car option) '(:type :endian))) options))
             ,lambda-list
           ,@body)
         (defbinalias (,little (:type ,type)) ,lambda-list
           (,name ,@(parsonic::lambda-list-arguments lambda-list)))
         (%define-endian-reader ,name)))))

(export '(defbinstruct/me *endian* define-nintendo-ware-file define-nintendo-ware-section))
