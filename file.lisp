(in-package #:nintendo-ware)

(defbinstruct (nintendo-ware-file-byte-order (:type (member :little :big)) (:constructor progn) (:conc-name nil) (:endian :big)) ()
  (%value #xfffe :type (satisfies (unsigned-byte 16) (lambda (value) (member value '(#xfffe #xfeff)))))
  (values :little :type (map null (lambda (ignored) (declare (ignore ignored))
                                   (ecase %value (#xfffe :little) (#xfeff :big))))))

(defbinstruct/me nintendo-ware-file-header (start magic endian)
  (start 0 :type (map null (constantly start)))
  (magic #.(coerce "" 'simple-base-string) :type (map null (constantly magic)))
  (endian :little :type (map null (constantly endian)))
  (header-size 20 :type (unsigned-byte 16))
  (version 0 :type (unsigned-byte 32))
  (file-size 20 :type (unsigned-byte 32))
  (block-count 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (references #() :type (simple-array nintendo-ware-sized-reference (block-count)))
  (%valid nil :type (map null (lambda (ignored) (declare (ignore ignored))
                                (validate-header references)))))

;; Explicit LE entry: embedded headers do not inherit their parent's endian.
(defbinalias nintendo-ware-file-header/le (start magic endian) (nintendo-ware-file-header start magic endian))

(defbinstruct (nintendo-ware-file-header-reader (:type nintendo-ware-file-header) (:constructor progn) (:conc-name nil)) ()
  (%start 0 :type position)
  (%magic #.(coerce "" 'simple-base-string) :type (simple-base-string 4))
  (%endian :little :type nintendo-ware-file-byte-order)
  (values nil :type (ecase %endian
                     (:little (nintendo-ware-file-header/le %start %magic %endian))
                     (:big (nintendo-ware-file-header/be %start %magic %endian)))))

(defun nintendo-ware-file-header-version-major (header)
  (mod (floor (nintendo-ware-file-header-version header) (if (char= (char (nintendo-ware-file-header-magic header) 0) #\C) #x1000000 #x10000)) 256))

(defun validate-header (references)
  (loop :for index :below (length references) :for current := (aref references index)
        :do (loop :for previous-index :below index :for previous := (aref references previous-index)
                  :do (when (= (nintendo-ware-sized-reference-type current) (nintendo-ware-sized-reference-type previous))
                        (fail-file "Duplicate block tag"))))
  nil)

(defun block-reference (header type &optional (required t))
  (or (find type (nintendo-ware-file-header-references header) :key #'nintendo-ware-sized-reference-type)
      (when required (fail-file "Missing block #x~X" type))))

(defun block-start (header type)
  (+ (nintendo-ware-file-header-start header) (nintendo-ware-sized-reference-offset (block-reference header type))))

(defbinstruct (nintendo-ware-file-position (:type non-negative-fixnum)
                                           (:constructor progn) (:conc-name nil)) ()
  ($nintendo-ware-file-start 0 :type position)
  (values 0 :type (map null (constantly $nintendo-ware-file-start))))

(defbinstruct nintendo-ware-file (expected-magic body/be body/le)
  ($nintendo-ware-file-start 0 :type position)
  (header (make-nintendo-ware-file-header)
          :type (satisfies nintendo-ware-file-header-reader
                           (lambda (header) (member (nintendo-ware-file-header-magic header) expected-magic :test #'string=))))
  (body nil :type (ecase (nintendo-ware-file-header-endian header)
                    (:big (inline body/be))
                    (:little (inline body/le))))
  ($nintendo-ware-file-end 0 :type position)
  (nil #.(make-array 0 :element-type '(unsigned-byte 8))
       :type (simple-array (unsigned-byte 8)
                ((- (nintendo-ware-file-header-file-size header)
                    (- $nintendo-ware-file-end (nintendo-ware-file-header-start header)))))))

(defmacro define-nintendo-ware-file (name-and-options &body sections)
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (let* ((magic (ensure-list (cadr (assoc :magic options))))
           (body (symbolicate name '-body)))
      `(progn
         (defbinstruct/me ,body ()
           (%header (make-nintendo-ware-file-header) :type nintendo-ware-file-header-at-start)
           ;; Embedded readers may change the native file anchor. Restore this
           ;; file's origin before each field, including after embedded files.
           ,@(loop for section in sections
                   append `((nil nil
                               :type (values (pointer nintendo-ware-file-position
                                              (map null (constantly (nintendo-ware-file-header-start %header))))))
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

