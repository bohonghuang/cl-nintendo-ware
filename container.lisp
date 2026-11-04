(in-package #:nintendo-ware)

(defbinstruct nintendo-ware-file (expected-magic body/be body/le)
  (header (make-header)
          :type (satisfies file-header
                           (lambda (header) (member (header-magic header) expected-magic :test #'string=))))
  (body nil :type (ecase (header-endian header)
                    (:big (inline (parser-call body/be header)))
                    (:little (inline (parser-call body/le header))))))

;; INLINE normally receives a ready parser. Here its factory needs the header
;; parsed by the container; adapt the corresponding emitter arguments too.
(defmethod binstruct::expand-writer-type-expr ((name (eql 'nintendo-ware-file)) &rest arguments)
  (destructuring-bind (magic body/be body/le) arguments
    (flet ((factory (body)
             (alexandria:with-gensyms (output value)
               `(lambda (header)
                  (lambda (,output ,value)
                    (,(binstruct::emitter-name-symbol (second body)) ,output ,value header))))))
      `(,(binstruct::emitter-name-symbol name) ,binstruct::*output* ,binstruct::*value*
        ,magic ,(factory body/be) ,(factory body/le)))))

(defmacro define-nintendo-ware-file (name-and-options &body sections)
  (destructuring-bind (name &rest options) (alexandria:ensure-list name-and-options)
    (let* ((magic (alexandria:ensure-list (cadr (assoc :magic options))))
           (body (alexandria:symbolicate name '-body)))
      `(progn
         (defbinstruct/me ,body (header)
           ;; Embedded readers may change the native file anchor. Restore this
           ;; file's origin before each field, including after embedded files.
           ,@(loop for section in sections
                   append `(($nintendo-ware-file-start 0
                               :type (peek position (header-start header)))
                            ,section)))
         (defbinstruct (,name (:include (nintendo-ware-file ',magic
                                          #',(alexandria:symbolicate body '/be)
                                          #',(alexandria:symbolicate body '/le)))
                             ,@(remove :magic options :key #'car)) ())
         ,@(alexandria:with-gensyms (instance value)
             (loop for section in sections
                   for slot-name = (binstruct::slot-name section)
                   for accessor = (alexandria:symbolicate name '- slot-name)
                   for inner = (alexandria:symbolicate body '- slot-name)
                   unless (binstruct::slot-excluded-p section)
                     collect `(progn
                                (declaim (inline ,accessor (setf ,accessor)))
                                (defun ,accessor (,instance)
                                  (,inner (,(alexandria:symbolicate name '-body) ,instance)))
                                (defun (setf ,accessor) (,value ,instance)
                                  (setf (,inner (,(alexandria:symbolicate name '-body) ,instance)) ,value)))))))))

