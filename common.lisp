(in-package #:cl-nintendo-ware)

(defgeneric read-file (type input)
  (:method (type (pathname pathname))
    (with-open-file (stream pathname :direction :input :element-type '(unsigned-byte 8))
      (read-file type stream)))
  (:method (type (vector vector))
    (read-file type (flexi-streams:make-in-memory-input-stream vector)))
  (:method (type (filename string))
    (read-file type (pathname filename))))

(defun valid-reference-offset-p (offset type expected-type)
  (or (= offset -1)
      (and (not (minusp offset)) (or (null expected-type) (= type expected-type)))))

(defbinstruct/me nintendo-ware-reference (&optional expected-type)
  (type 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (offset -1 :type (satisfies (signed-byte 32)
                              (rcurry #'valid-reference-offset-p type expected-type))))

(defbinstruct/me nintendo-ware-sized-reference ()
  (type 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (offset -1 :type (signed-byte 32))
  (size 0 :type (unsigned-byte 32)))

;; Native pointer offsets validate non-null references without allocating a
;; temporary REFERENCE. NULL-REFERENCE handles the separate -1 sentinel.
(defbinstruct/me (nintendo-ware-reference-offset-value (:type (signed-byte 32)) (:constructor progn) (:conc-name nil)) (tag)
  (%tag tag :type (unsigned-byte 16))
  (nil 0 :type (unsigned-byte 16))
  (values -1 :type (satisfies (signed-byte 32)
                             (lambda (offset) (and (not (minusp offset)) (= %tag tag))))))

(defbinstruct/me (nintendo-ware-null-reference (:type null) (:constructor progn) (:conc-name nil)) ()
  (nil 0 :type (unsigned-byte 16))
  (nil 0 :type (unsigned-byte 16))
  (nil -1 :type (satisfies (signed-byte 32) (curry #'= -1)))
  (values nil :type null))

(defbinstruct/me (nintendo-ware-reference-array (:type (simple-array * (*)))
                  (:constructor progn) (:conc-name nil)) (tag type)
  (%position 0 :type position)
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array
                     (or nintendo-ware-null-reference
                         (values (pointer (inline type)
                                          (nintendo-ware-reference-offset-value tag)
                                          %position))) (%count))))

(defun nintendo-ware-reference-target (reference base &optional expected-type)
  (let ((offset (nintendo-ware-reference-offset reference)))
    (unless (= offset -1)
      (when (and expected-type (/= expected-type (nintendo-ware-reference-type reference)))
        (error 'binstruct::deserialize-error
               :input nil :position nil
               :info (format nil "Reference tag #x~X; expected #x~X" (nintendo-ware-reference-type reference) expected-type)))
      (when (minusp offset) (error 'binstruct::deserialize-error
                                   :input nil :position nil
                                   :info (format nil "Invalid relative offset ~D" offset)))
      (+ base offset))))

(defun nintendo-ware-sized-reference-target (reference base &optional expected-type)
  (let ((offset (nintendo-ware-sized-reference-offset reference)))
    (unless (= offset -1)
      (when (and expected-type (/= expected-type (nintendo-ware-sized-reference-type reference)))
        (error 'binstruct::deserialize-error
               :input nil :position nil
               :info "Sized reference tag mismatch"))
      (when (minusp offset) (error 'binstruct::deserialize-error
                                   :input nil :position nil
                                   :info (format nil "Invalid sized relative offset ~D" offset)))
      (+ base offset))))

