(in-package #:nintendo-ware)

(defvar *endian*)

;; Same alias definition as cl-nitro/common.lisp.
(defmacro defbinalias (name-and-options lambda-list parser)
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (destructuring-bind (&key (type name typep)) (mappend #'identity options)
      (unless typep
        (let ((inferred-type (binstruct::lisp-type parser)))
          (unless (eq inferred-type t) (setf type inferred-type))))
      `(defbinstruct (,name (:type ,type) (:constructor progn) (:conc-name nil))
           ,lambda-list
         (values nil :type ,parser)))))

(defmacro %define-endian-reader (name)
  (let ((little (symbolicate name '#:/le))
        (big (symbolicate name '#:/be)))
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

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun big-endian-bitfield-slots (slots)
    ;; Binstruct closes an integer group at each byte-aligned field boundary.
    ;; Reverse those groups, not their fields, for a numeric bitfield word.
    (let ((bits 0) (group nil) (groups nil))
      (dolist (slot slots)
        (let ((type (getf (cddr slot) :type)))
          (incf bits (cond ((equal type '(boolean bit)) 1)
                           ((eq type 'bit) 1)
                           (t (destructuring-bind (unsigned-byte width) type
                                (assert (eq unsigned-byte 'unsigned-byte))
                                width)))))
        (push slot group)
        (when (zerop (mod bits 8))
          (push (nreverse group) groups)
          (setf group nil)))
      (assert (and (= bits 32) (null group)))
      (mappend #'identity groups))))

(defmacro defbinstruct/me (name-and-options &body body)
  "Define default little-endian and /le, /be readers sharing one Lisp type.
An optional lambda list precedes the fields, as in DEFBINSTRUCT.
(:BITFIELD T) declares a numeric 32-bit native bitfield in low-bit-first order."
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (let* ((bitfield-p (cadr (assoc :bitfield options)))
           (options (remove :bitfield options :key #'car))
           (lambda-list (when (and body (not (member :type (first body)))) (pop body)))
           (type (or (cadr (assoc :type options)) name))
           (little (symbolicate name '#:/le))
           (big (symbolicate name '#:/be)))
      `(progn
         (defbinstruct (,name ,@options) ,lambda-list ,@body)
         (%defbinstruct/be (,big (:type ,type) (:endian :big)
                                ,@(remove-if (lambda (option) (member (car option) '(:type :endian))) options))
             ,lambda-list
           ,@(if bitfield-p (big-endian-bitfield-slots body) body))
         (defbinalias (,little (:type ,type)) ,lambda-list
           (,name ,@(parsonic::lambda-list-arguments lambda-list)))
         (%define-endian-reader ,name)))))

