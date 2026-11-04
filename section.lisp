(in-package #:nintendo-ware)

(defbinstruct (nintendo-ware-file-header-at-start (:type header) (:constructor progn) (:conc-name nil)) ()
  (values nil :type (pointer file-header (map null (constantly 0)) $nintendo-ware-file-start)))

(defbinstruct/me nintendo-ware-section (expected-magic content)
  ($nintendo-ware-section-start 0 :type position)
  (magic #.(coerce "" 'simple-base-string)
         :type (satisfies (simple-base-string 4) (lambda (magic) (string= magic expected-magic))))
  (size 8 :type (unsigned-byte 32))
  (body nil :type (inline content)))

(defbinstruct/me (nintendo-ware-section-start-magic-size (:type list)
                                                      (:constructor progn) (:conc-name nil)) ()
  (values nil :type (pointer (list position (simple-base-string 4) (unsigned-byte 32))
                            (map null (constantly 0) (constantly nil)) $nintendo-ware-section-start)))

;; Like Nitro: observe the section header and current position without
;; consuming input. Only layouts with an uncounted tail need this type.
(defbinstruct/me (nintendo-ware-section-tail-size (:type (unsigned-byte 32))
                                                (:constructor progn) (:conc-name nil)) ()
  (%position 0 :type position)
  (%header (list 0 #.(coerce "" 'simple-base-string) 0)
           :type nintendo-ware-section-start-magic-size)
  (values 0 :type (map null (lambda (ignored) (declare (ignore ignored))
                             (- (third %header) (- %position (first %header)))))))

(defbinstruct/me nintendo-ware-section-body ()
  (%header (make-header) :type nintendo-ware-file-header-at-start))

(defmacro define-nintendo-ware-section (name-and-options &body slots)
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (let* ((magic (coerce (cadr (assoc :magic options)) 'simple-base-string))
           (options (remove :magic options :key #'car))
           (body (symbolicate name '-body))
           (little (symbolicate name '/le))
           (big (symbolicate name '/be)))
      `(progn
         (defbinstruct/me (,body (:include nintendo-ware-section-body)) () ,@slots)
         (defbinstruct (,name (:include (nintendo-ware-section ,magic (,body))) ,@options) ())
         (%defbinstruct/be (,big (:type ,name) (:endian :big)
                                (:include (nintendo-ware-section ,magic (,(symbolicate body '/be))))
                                ,@options) ())
         (defbinalias (,little (:type ,name)) () (,name))
         (%define-endian-reader ,name)
         ,@(with-gensyms (instance value)
             (loop for slot in (remove-duplicates slots :key #'car)
                   for slot-name = (binstruct::slot-name slot)
                   for accessor = (symbolicate name '- slot-name)
                   for inner = (symbolicate body '- slot-name)
                   unless (binstruct::slot-excluded-p slot)
                     collect `(progn
                                (declaim (inline ,accessor (setf ,accessor)))
                                (defun ,accessor (,instance)
                                  (,inner (,(symbolicate name '-body) ,instance)))
                                (defun (setf ,accessor) (,value ,instance)
                                  (setf (,inner (,(symbolicate name '-body) ,instance)) ,value)))))))))

