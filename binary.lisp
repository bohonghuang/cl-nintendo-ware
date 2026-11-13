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
    (macroexpand `(defbinstruct ,name-and-options ,lambda-list ,@slots))))

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
             `((eval-when (:compile-toplevel :load-toplevel :execute)
                 (remprop ',name 'binstruct::expand-reader-type-expr)
                 (remprop ',name 'binstruct::expand-writer-type-expr))
               (defbinstruct (,name ,@options) ,lambda-list ,@body)
               (defbinalias (,little (:type ,type)) ,lambda-list
                 (,name . ,(loop :with inline-args
                                   := (labels ((traverse (object)
                                                 (when (consp object)
                                                   (if (eq (car object) 'inline)
                                                       (list (cadr object))
                                                       (nconc (traverse (car object)) (traverse (cdr object)))))))
                                        (delete-duplicates (traverse body)))
                                 :for arg :in (parsonic::lambda-list-arguments lambda-list)
                                 :if (member arg inline-args)
                                   :collect `(inline ,arg)
                                 :else
                                   :collect arg)))
               (defbinstruct/be (,big (:type ,type) (:endian :big)
                                     ,@(loop :for option :in options
                                             :nconc
                                             (case (car option)
                                               ((:type :endian))
                                               (:include
                                                (destructuring-bind (ancestor &rest arguments) (ensure-list (cadr option))
                                                  (let ((big-ancestor
                                                          (find-symbol (concatenate 'string (symbol-name ancestor) "/BE")
                                                                       (symbol-package ancestor))))
                                                    (unless big-ancestor
                                                      (error "No big-endian include layout for ~S." ancestor))
                                                    (list `(:include (,big-ancestor ,@arguments))))))
                                               (otherwise (list option)))))
                   ,lambda-list
                 ,@body)))
         ,(with-gensyms (args)
            `(eval-when (:compile-toplevel :load-toplevel :execute)
               (setf (get ',name 'binstruct::expand-reader-type-expr)
                     (lambda (&rest ,args)
                       (apply #'binstruct::expand-reader-type-expr
                              (ecase (or (when (boundp '*endian*) *endian*) :little)
                                (:little ',little)
                                (:big ',big))
                              ,args))
                     (get ',name 'binstruct::expand-writer-type-expr)
                     (lambda (&rest ,args)
                       (apply #'binstruct::expand-writer-type-expr
                              (ecase (or (when (boundp '*endian*) *endian*) :little)
                                (:little ',little)
                                (:big ',big))
                              ,args)))))))))
