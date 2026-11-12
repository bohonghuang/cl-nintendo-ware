(in-package #:nintendo-ware)

(defbinstruct (nintendo-ware-section-end-position (:type non-negative-fixnum)
                                               (:constructor progn) (:conc-name nil)) ()
  ($nintendo-ware-section-end 0 :type position)
  (values 0 :type (map null (constantly $nintendo-ware-section-end))))

(defbinstruct/me nintendo-ware-section (expected-magic content)
  ($nintendo-ware-section-start 0 :type position)
  (magic #.(coerce "" 'simple-base-string)
         :type (satisfies (simple-base-string 4) (rcurry #'string= expected-magic)))
  (size 8 :type (unsigned-byte 32))
  (%start 0 :type position)
  (%limit 0 :type (values (pointer nintendo-ware-section-end-position
                                  (map null (constantly (+ %start (- size 8)))))))
  (body nil :type (inline content))
  (%end 0 :type position)
  (nil #.(make-array 0 :element-type '(unsigned-byte 8))
       :type (simple-array (unsigned-byte 8) ((- size 8 (- %end %start))))))

;; Only uncounted tails need an endpoint; ordinary bodies have no header layer.
(defbinstruct/me (nintendo-ware-tail-size (:type (unsigned-byte 32))
                                        (:constructor progn) (:conc-name nil)) ()
  (%position 0 :type position)
  (%end 0 :type (values (pointer position (map null (constantly 0)) $nintendo-ware-section-end)))
  (values 0 :type (map null (constantly (- %end %position)))))

(defmacro define-nintendo-ware-section (name-and-options &body slots)
  (destructuring-bind (name &rest options) (ensure-list name-and-options)
    (let* ((magic (coerce (cadr (assoc :magic options)) 'simple-base-string))
           (options (remove :magic options :key #'car))
           (body (symbolicate name '-body)))
      `(progn
         (defbinstruct/me ,body () ,@slots)
         ;; INLINE arguments explicitly select their endian-specific body parser.
         (defbinstruct (,name (:include (nintendo-ware-section ,magic (,body))) ,@options) ())
         (defbinstruct/be (,(symbolicate name '/be)
                           (:type ,(or (cadr (assoc :type options)) name))
                           (:include (nintendo-ware-section ,magic (,(symbolicate body '/be))))
                           ,@(remove-if (lambda (option) (member (car option) '(:type :endian))) options)) ())
         (defbinstruct/me ,name)))))
