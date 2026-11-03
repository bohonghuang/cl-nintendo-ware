(in-package #:nintendo-ware)

(defbinstruct/me nintendo-ware-section (expected-magic upper)
  ($nintendo-ware-section-start 0 :type position)
  (magic #.(coerce "" 'simple-base-string)
         :type (satisfies (simple-base-string 4) (lambda (magic) (string= magic expected-magic))))
  (size 8 :type (satisfies (unsigned-byte 32) (lambda (size) (= size (- upper $nintendo-ware-section-start))))))

(defmacro define-nintendo-ware-section (name-and-options &body body)
  (destructuring-bind (name &rest options) (alexandria:ensure-list name-and-options)
    (let ((magic (coerce (cadr (assoc :magic options)) 'simple-base-string))
          (lambda-list (pop body)))
      `(defbinstruct/me (,name (:include (nintendo-ware-section ,magic upper))
                              ,@(remove :magic options :key #'car))
           ,lambda-list
         ,@body))))

(export '(nintendo-ware-section nintendo-ware-section-magic nintendo-ware-section-size))
