(in-package #:nintendo-ware)

(defbinstruct/me (nintendo-ware-file-header-at-start (:type header) (:constructor progn) (:conc-name nil)) ()
  (values nil :type (pointer header (map null (constantly 0)) $nintendo-ware-file-start)))

(defbinstruct/me nintendo-ware-section (expected-magic content)
  (magic #.(coerce "" 'simple-base-string)
         :type (satisfies (simple-base-string 4) (lambda (magic) (string= magic expected-magic))))
  (size 8 :type (satisfies (unsigned-byte 32) (lambda (size) (>= size 8))))
  (body nil :type (inline content)))

;; Like Nitro's tail-size alias, obtain container context through native
;; positional references, not arguments on each concrete section reader.
(defbinstruct/me nintendo-ware-section-body ()
  (%header (make-header) :type nintendo-ware-file-header-at-start)
  (%section-start 0 :type (map position (lambda (position) (- position 8))))
  (%size 8 :type (peek (unsigned-byte 32) (+ %section-start 4)))
  (%upper 0 :type (map null (lambda (ignored) (declare (ignore ignored))
                             (+ %section-start %size))))
  (%valid nil :type (map null (lambda (ignored) (declare (ignore ignored))
                               (unless (find-if
                                        (lambda (reference)
                                          (and (= %section-start
                                                  (+ (header-start %header) (sized-reference-offset reference)))
                                               (= %size (sized-reference-size reference))))
                                        (header-references %header))
                                 (fail-file "Section span differs from file directory"))))))

(defmacro define-nintendo-ware-section (name-and-options &body slots)
  (destructuring-bind (name &rest options) (alexandria:ensure-list name-and-options)
    (let* ((magic (coerce (cadr (assoc :magic options)) 'simple-base-string))
           (options (remove :magic options :key #'car))
           (body (alexandria:symbolicate name '-body))
           (little (alexandria:symbolicate name '/le))
           (big (alexandria:symbolicate name '/be)))
      `(progn
         (defbinstruct/me (,body (:include nintendo-ware-section-body)) () ,@slots)
         (defbinstruct (,name (:include (nintendo-ware-section ,magic (,body))) ,@options) ())
         (%defbinstruct/be (,big (:type ,name) (:endian :big)
                                (:include (nintendo-ware-section ,magic (,(alexandria:symbolicate body '/be))))
                                ,@options) ())
         (defbinalias (,little (:type ,name)) () (,name))
         (%define-endian-reader ,name)
         ,@(alexandria:with-gensyms (instance value)
             (loop for slot in (remove-duplicates slots :key #'car)
                   for slot-name = (binstruct::slot-name slot)
                   for accessor = (alexandria:symbolicate name '- slot-name)
                   for inner = (alexandria:symbolicate body '- slot-name)
                   unless (binstruct::slot-excluded-p slot)
                     collect `(progn
                                (declaim (inline ,accessor (setf ,accessor)))
                                (defun ,accessor (,instance)
                                  (,inner (,(alexandria:symbolicate name '-body) ,instance)))
                                (defun (setf ,accessor) (,value ,instance)
                                  (setf (,inner (,(alexandria:symbolicate name '-body) ,instance)) ,value)))))))))

(export '(nintendo-ware-section nintendo-ware-section-magic nintendo-ware-section-size))
