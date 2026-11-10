(in-package #:cl-nintendo-ware)

(defgeneric read-file (type input)
  (:method (type (pathname pathname))
    (with-open-file (stream pathname :direction :input :element-type '(unsigned-byte 8))
      (read-file type stream)))
  (:method (type (vector vector))
    (read-file type (flexi-streams:make-in-memory-input-stream vector)))
  (:method (type (filename string))
    (read-file type (pathname filename))))

