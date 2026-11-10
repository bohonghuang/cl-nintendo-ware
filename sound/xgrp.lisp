(in-package #:cl-nintendo-ware)

(defbinstruct (xgrp-data-position (:type non-negative-fixnum)
                                       (:constructor progn) (:conc-name nil)) ()
  ($xgrp-data-start 0 :type position)
  (values 0 :type (map null (constantly $xgrp-data-start))))

(define-nintendo-ware-reference (xgrp-data-reference (:sized t)) ()
  (#x1f00 (nintendo-ware-reference-octets)))

(defbinstruct/me xgrp-entry ()
  (file-id 0 :type (unsigned-byte 32))
  (%data-start 0 :type (values (pointer position (map null (constantly 0)) $xgrp-data-start)))
  (data nil :type (xgrp-data-reference %data-start)))

(defbinstruct/me xgrp-dependency ()
  (resource-id (make-nintendo-ware-sound-resource-id) :type nintendo-ware-sound-resource-id) (load-flags 0 :type (unsigned-byte 32)))

(define-nintendo-ware-reference xgrp-entry-reference ()
  (#x7900 (xgrp-entry)))
(define-nintendo-ware-reference xgrp-dependency-reference ()
  (#x7901 (xgrp-dependency)))

(define-nintendo-ware-section (xgrp-info (:magic "INFO"))
  (nil nil :type (values (pointer xgrp-data-position (map null (constantly (if (block-reference %header #x7801 nil) (+ 8 (block-start %header #x7801)) 8))))))
  (%xgrp-info-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (xgrp-entry-reference %xgrp-info-start) (count))))

(define-nintendo-ware-section (xgrp-infx (:magic "INFX"))
  (%xgrp-infx-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (xgrp-dependency-reference %xgrp-infx-start) (count))))

(define-nintendo-ware-file (xgrp (:magic ("CGRP" "FGRP")))
  (info nil :type (values (pointer xgrp-info (map null (constantly (block-start %header #x7800))))))
  (infx nil :type (ecase (not (null (block-reference %header #x7802 nil))) ((nil) null) ((t) (values (pointer xgrp-infx (map null (constantly (block-start %header #x7802))))))))
  (file nil :type (ecase (not (null (block-reference %header #x7801 nil)))
                     ((nil) null)
                     ((t) (values (pointer (nintendo-ware-section-raw-block "FILE") (map null (constantly (block-start %header #x7801)))))))))

(defbinio xgrp stream)

(defmethod read-file ((type (eql 'xgrp)) (stream stream))
  (read-xgrp stream))
