(in-package #:cl-nintendo-ware)

(define-condition nintendo-ware-invalid-file (error)
  ((reason :initarg :reason :reader nintendo-ware-invalid-file-reason))
  (:report (lambda (condition output) (write-string (nintendo-ware-invalid-file-reason condition) output))))

(defun fail-file (control &rest arguments)
  (error 'nintendo-ware-invalid-file :reason (apply #'format nil control arguments)))

(defgeneric read-file (type input)
  (:method (type (pathname pathname))
    (with-open-file (stream pathname :direction :input :element-type '(unsigned-byte 8))
      (read-file type stream)))
  (:method (type (vector vector))
    (read-file type (flexi-streams:make-in-memory-input-stream vector)))
  (:method (type (filename string))
    (read-file type (pathname filename)))
  (:method :around (type (stream stream))
    (handler-case (call-next-method)
      (binstruct::deserialize-error (condition) (fail-file "~A" condition)))))

(defun valid-reference-offset-p (offset type expected-type)
  (or (= offset -1)
      (and (not (minusp offset)) (or (null expected-type) (= type expected-type)))))

(defbinstruct/me nintendo-ware-reference (&optional expected-type)
  (type 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (offset -1 :type (satisfies (signed-byte 32)
                              (lambda (offset)
                                (valid-reference-offset-p offset type expected-type)))))

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

(defun nintendo-ware-reference-target (reference base &optional expected-type)
  (let ((offset (nintendo-ware-reference-offset reference)))
    (unless (= offset -1)
      (when (and expected-type (/= expected-type (nintendo-ware-reference-type reference)))
        (fail-file "Reference tag #x~X; expected #x~X" (nintendo-ware-reference-type reference) expected-type))
      (when (minusp offset) (fail-file "Invalid relative offset ~D" offset))
      (+ base offset))))

(defun nintendo-ware-sized-reference-target (reference base &optional expected-type)
  (let ((offset (nintendo-ware-sized-reference-offset reference)))
    (unless (= offset -1)
      (when (and expected-type (/= expected-type (nintendo-ware-sized-reference-type reference)))
        (fail-file "Sized reference tag mismatch"))
      (when (minusp offset) (fail-file "Invalid sized relative offset ~D" offset))
      (+ base offset))))

