(in-package #:cl-nintendo-ware)

(defbinstruct (xgrp-data-position (:type non-negative-fixnum)
                                       (:constructor progn) (:conc-name nil)) ()
  ($xgrp-data-start 0 :type position)
  (values 0 :type (map null (constantly $xgrp-data-start))))

(defbinstruct/me xgrp-entry ()
  (file-id 0 :type (unsigned-byte 32))
  (reference (make-sized-reference) :type sized-reference)
  (data nil :type (ecase (= (sized-reference-offset reference) -1)
                   ((t) null)
                   ((nil) (values (pointer (simple-array (unsigned-byte 8) ((sized-reference-size reference))) (map null (constantly (sized-reference-target reference 0 #x1f00))) $xgrp-data-start))))))

(defbinstruct/me xgrp-dependency ()
  (resource-id (make-resource-id) :type resource-id) (load-flags 0 :type (unsigned-byte 32)))

(define-nintendo-ware-section (xgrp-info (:magic "INFO"))
  (nil nil :type (values (pointer xgrp-data-position (map null (constantly (if (block-reference %header #x7801 nil) (+ 8 (block-start %header #x7801)) 8))))))
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x7900 $table-start xgrp-entry) (count))))

(define-nintendo-ware-section (xgrp-infx (:magic "INFX"))
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x7901 $table-start (xgrp-dependency)) (count))))

(define-nintendo-ware-file (xgrp (:magic ("CGRP" "FGRP")))
  (info nil :type (values (pointer xgrp-info (map null (constantly (block-start %header #x7800))))))
  (infx nil :type (ecase (not (null (block-reference %header #x7802 nil))) ((nil) null) ((t) (values (pointer xgrp-infx (map null (constantly (block-start %header #x7802))))))))
  (file nil :type (ecase (not (null (block-reference %header #x7801 nil)))
                     ((nil) null)
                     ((t) (values (pointer (raw-block "FILE") (map null (constantly (block-start %header #x7801)))))))))

(defbinio xgrp stream)

(defmethod read-file ((type (eql 'xgrp)) (stream stream))
  (read-xgrp stream))
