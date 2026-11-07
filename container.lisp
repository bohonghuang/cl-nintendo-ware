(in-package #:nintendo-ware)

(defbinstruct (nintendo-ware-file-position (:type non-negative-fixnum)
                                           (:constructor progn) (:conc-name nil)) ()
  ($nintendo-ware-file-start 0 :type position)
  (values 0 :type (map null (constantly $nintendo-ware-file-start))))

(defbinstruct nintendo-ware-file (expected-magic body/be body/le)
  ($nintendo-ware-file-start 0 :type position)
  (header (make-header)
          :type (satisfies file-header
                           (lambda (header) (member (header-magic header) expected-magic :test #'string=))))
  (body nil :type (ecase (header-endian header)
                    (:big (inline body/be))
                    (:little (inline body/le))))
  ($nintendo-ware-file-end 0 :type position)
  (nil #.(make-array 0 :element-type '(unsigned-byte 8))
       :type (simple-array (unsigned-byte 8)
                ((- (header-file-size header)
                    (- $nintendo-ware-file-end (header-start header)))))))

(defmacro define-nintendo-ware-file (name-and-options &body sections)
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (let* ((magic (ensure-list (cadr (assoc :magic options))))
           (body (symbolicate name '-body)))
      `(progn
         (defbinstruct/me ,body ()
           (%header (make-header) :type nintendo-ware-file-header-at-start)
           ;; Embedded readers may change the native file anchor. Restore this
           ;; file's origin before each field, including after embedded files.
           ,@(loop for section in sections
                   append `((nil nil
                               :type (values (pointer nintendo-ware-file-position
                                              (map null (constantly (header-start %header))))))
                            ,section)))
         (defbinstruct (,name (:include (nintendo-ware-file ',magic
                                          (,(symbolicate body '/be))
                                          (,body)))
                             ,@(remove :magic options :key #'car)) ())
         ,@(with-gensyms (instance value)
             (loop for section in sections
                   for slot-name = (binstruct::slot-name section)
                   for accessor = (symbolicate name '- slot-name)
                   for inner = (symbolicate body '- slot-name)
                   unless (binstruct::slot-excluded-p section)
                     collect `(progn
                                (declaim (inline ,accessor (setf ,accessor)))
                                (defun ,accessor (,instance)
                                  (,inner (,(symbolicate name '-body) ,instance)))
                                (defun (setf ,accessor) (,value ,instance)
                                  (setf (,inner (,(symbolicate name '-body) ,instance)) ,value)))))))))

