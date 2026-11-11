(in-package #:cl-nintendo-ware)

(define-nintendo-ware-section (xwar-info (:magic "INFO"))
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (simple-array (unsigned-byte 8) (12)) (count))))

(define-nintendo-ware-file (xwar (:magic ("CWAR" "FWAR")))
  (info (make-xwar-info) :type xwar-info :tag #x6800)
  (file (make-nintendo-ware-section-raw-block) :type (nintendo-ware-section-raw-block "FILE") :tag #x6801))

(defun xwar-waves (archive)
  "Parse WAVs on demand in wave-ID order, preserving null references as NIL."
  (let* ((info (xwar-info-body (xwar-info archive)))
         (section (xwar-file archive))
         (data (when section
                 (nintendo-ware-section-octets-bytes (nintendo-ware-section-raw-block-body section)))))
    (map 'simple-vector
         (lambda (reference)
           (let ((bytes (ecase (nintendo-ware-file-endian archive)
                          (:little (nintendo-ware-parse (nintendo-ware-data-reference '(#x1f00) data) reference))
                          (:big (nintendo-ware-parse (nintendo-ware-data-reference/be '(#x1f00) data) reference)))))
             (when bytes (read-file 'xwav bytes))))
         (xwar-info-body-entries info))))

(defmethod read-file ((type (eql 'xwar)) (stream stream))
  (read-xwar stream))

(defbinio xwar stream)
