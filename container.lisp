(in-package #:nintendo-ware)

(defbinstruct/me nintendo-ware-file (expected-magic)
  (header (make-header)
          :type (satisfies header
                           (lambda (header) (member (header-magic header) expected-magic :test #'string=)))))

(defmacro define-nintendo-ware-file (name-and-options &body sections)
  (destructuring-bind (name &rest options) (alexandria:ensure-list name-and-options)
    (let ((magic (alexandria:ensure-list (cadr (assoc :magic options)))))
      `(defbinstruct/me (,name (:include (nintendo-ware-file ',magic))
                              ,@(remove :magic options :key #'car))
           ()
         ;; Native embedded readers may change the file anchor. Re-establish
         ;; this file's origin before each subsequent field, not just once.
         ,@(loop for section in sections
                 append `(($nintendo-ware-file-start 0
                             :type (peek position (header-start header)))
                          ,section))))))

(export '(nintendo-ware-file nintendo-ware-file-header))
