(in-package #:cl-nintendo-ware)

(defbinstruct/me xgrp-entry ()
  (file-id 0 :type (unsigned-byte 32))
  (data-reference #.(make-array 0 :element-type '(unsigned-byte 8))
                  :type (simple-array (unsigned-byte 8) (12))))

(defbinstruct/me xgrp-dependency ()
  (resource-id (make-nintendo-ware-sound-resource-id) :type nintendo-ware-sound-resource-id) (load-flags 0 :type (unsigned-byte 32)))

(define-nintendo-ware-reference xgrp-entry-reference ()
  (#x7900 (xgrp-entry)))
(define-nintendo-ware-reference xgrp-dependency-reference ()
  (#x7901 (xgrp-dependency)))

(define-nintendo-ware-section (xgrp-info (:magic "INFO"))
  (%xgrp-info-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (xgrp-entry-reference %xgrp-info-start) (count))))

(define-nintendo-ware-section (xgrp-infx (:magic "INFX"))
  (%xgrp-infx-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (xgrp-dependency-reference %xgrp-infx-start) (count))))

(define-nintendo-ware-file (xgrp (:magic ("CGRP" "FGRP")))
  (info (make-xgrp-info) :type xgrp-info :tag #x7800)
  (file (make-nintendo-ware-section-raw-block) :type (nintendo-ware-section-raw-block "FILE") :tag #x7801)
  (infx (make-xgrp-infx) :type xgrp-infx :tag #x7802))

(defun xgrp-file-data (group file-id)
  "Return raw embedded bytes for FILE-ID, or NIL if unavailable."
  (let* ((info (xgrp-info-body (xgrp-info group)))
         (entry (find file-id (xgrp-info-body-entries info)
                      :test (lambda (id entry) (and entry (= id (xgrp-entry-file-id entry))))))
         (section (xgrp-file group)))
    (when (and entry section)
      (let ((data (nintendo-ware-section-octets-bytes (nintendo-ware-section-raw-block-body section)))
            (reference (xgrp-entry-data-reference entry)))
        (ecase (nintendo-ware-file-endian group)
          (:little (nintendo-ware-parse (nintendo-ware-data-reference '(#x1f00) data) reference))
          (:big (nintendo-ware-parse (nintendo-ware-data-reference/be '(#x1f00) data) reference)))))))

(defbinio xgrp stream)

(defmethod read-file ((type (eql 'xgrp)) (stream stream))
  (read-xgrp stream))
