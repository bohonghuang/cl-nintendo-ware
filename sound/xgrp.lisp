(in-package #:cl-nintendo-ware)

(define-nintendo-ware-reference (xgrp-data-reference (:sized t)) ()
  (#x1f00 (nintendo-ware-reference-octets)))

(defbinstruct/me (xgrp-data-at-reference (:type (or null (simple-array (unsigned-byte 8) (*))))
                                       (:constructor progn) (:conc-name nil)) (source)
  (%base 0 :type position)
  (values nil :type (values (pointer (xgrp-data-reference %base) (map null (constantly source))))))

(defbinstruct/me xgrp-entry ()
  (file-id 0 :type (unsigned-byte 32))
  (%source 0 :type position)
  (%offset -1 :type (values (pointer (signed-byte 32) (map null (constantly 4)) %source)))
  (data nil :type (ecase (= %offset -1)
                   ((t) (xgrp-data-reference %source))
                   ((nil) (values (pointer (xgrp-data-at-reference %source)
                                            (map null (constantly 0)) $xgrp-data-start)))))
  (nil #.(make-array 0 :element-type '(unsigned-byte 8))
       :type (simple-array (unsigned-byte 8) ((if (= %offset -1) 0 12)))))

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

(define-nintendo-ware-section (xgrp-file (:magic "FILE"))
  ($xgrp-data-start 0 :type position))

(define-nintendo-ware-file (xgrp (:magic ("CGRP" "FGRP")))
  (info (make-xgrp-info) :type xgrp-info :tag #x7800)
  (infx (make-xgrp-infx) :type xgrp-infx :tag #x7802)
  (file (make-xgrp-file) :type xgrp-file :tag #x7801))

(defbinio xgrp stream)

(defmethod read-file ((type (eql 'xgrp)) (stream stream))
  (read-xgrp stream))
