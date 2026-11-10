(in-package #:nintendo-ware)

(defbinstruct (nintendo-ware-file-header-at-start (:type nintendo-ware-file-header) (:constructor progn) (:conc-name nil)) ()
  (values nil :type (pointer nintendo-ware-file-header-reader (map null (constantly 0)) $nintendo-ware-file-start)))

(defbinstruct/me nintendo-ware-section (expected-magic content)
  ($nintendo-ware-section-start 0 :type position)
  (magic #.(coerce "" 'simple-base-string)
         :type (satisfies (simple-base-string 4) (rcurry #'string= expected-magic)))
  (size 8 :type (unsigned-byte 32))
  (%start 0 :type (map null (constantly $nintendo-ware-section-start)))
  (body nil :type (inline content))
  ($nintendo-ware-section-end 0 :type position)
  (nil #.(make-array 0 :element-type '(unsigned-byte 8))
       :type (simple-array (unsigned-byte 8)
                ((- size (- $nintendo-ware-section-end %start))))))

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
  (%header (make-nintendo-ware-file-header) :type nintendo-ware-file-header-at-start))

(defmacro define-nintendo-ware-section (name-and-options &body slots)
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (let* ((magic (coerce (cadr (assoc :magic options)) 'simple-base-string))
           (options (remove :magic options :key #'car))
           (body (symbolicate name '-body)))
      `(progn
         (defbinstruct/me (,body (:include nintendo-ware-section-body)) () ,@slots)
         ;; INLINE receives a parser, not a schema type subject to ME dispatch.
         (defbinstruct (,name (:include (nintendo-ware-section ,magic (,body))) ,@options) ())
         (defbinstruct/be (,(symbolicate name '/be)
                           (:type ,(or (cadr (assoc :type options)) name))
                           (:include (nintendo-ware-section ,magic (,(symbolicate body '/be))))
                           ,@(remove-if (lambda (option) (member (car option) '(:type :endian))) options)) ())
         (defbinstruct/me ,name)
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


(defbinstruct/me nintendo-ware-section-raw-block (expected-magic)
  (magic #.(coerce "" 'simple-base-string) :type (satisfies (simple-base-string 4) (rcurry #'string= expected-magic)))
  (size 0 :type (unsigned-byte 32))
  (bytes #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- size 8)))))

