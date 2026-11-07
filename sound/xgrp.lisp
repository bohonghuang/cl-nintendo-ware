(in-package #:cl-nintendo-ware)

(defbinstruct/me xgrp-entry (data-start)
  (file-id 0 :type (unsigned-byte 32))
  (reference (make-sized-reference) :type sized-reference)
  (data nil :type (ecase (= (sized-reference-offset reference) -1)
                   ((t) null)
                   ((nil) (peek (simple-array (unsigned-byte 8) ((sized-reference-size reference)))
                                (sized-reference-target reference (+ data-start 8) #x1f00))))))

(defbinstruct/me xgrp-dependency ()
  (resource-id 0 :type (unsigned-byte 32)) (load-flags 0 :type (unsigned-byte 32)))

(define-nintendo-ware-section (xgrp-info (:magic "INFO"))
  (%data-start 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (if (block-reference %header #x7801 nil) (block-start %header #x7801) 0))))
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x7900 $table-start (xgrp-entry %data-start)) (count))))

(define-nintendo-ware-section (xgrp-infx (:magic "INFX"))
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x7901 $table-start (xgrp-dependency)) (count))))

(define-nintendo-ware-file (xgrp (:magic ("CGRP" "FGRP")))
  (info nil :type (peek xgrp-info (block-start header #x7800)))
  (infx nil :type (ecase (not (null (block-reference header #x7802 nil))) ((nil) null) ((t) (peek xgrp-infx (block-start header #x7802)))))
  (file nil :type (ecase (not (null (block-reference header #x7801 nil)))
                     ((nil) null)
                     ((t) (peek (raw-block "FILE")
                                (block-start header #x7801))))))

(defbinio xgrp stream)

(defmethod read-file ((type (eql 'xgrp)) (stream stream))
  (read-xgrp stream))
