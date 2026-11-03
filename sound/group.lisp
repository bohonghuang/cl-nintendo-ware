(in-package #:cl-nintendo-ware)

(defbinstruct/me sound-group-entry (data-start)
  (file-id 0 :type (unsigned-byte 32))
  (reference (make-sized-reference) :type sized-reference)
  (content nil :type (ecase (= (sized-reference-offset reference) -1)
                      ((t) null)
                      ((nil) (peek (sized-file (sized-reference-size reference))
                                   (sized-reference-target reference (+ data-start 8) #x1f00))))))

(defbinstruct/me sound-group-dependency ()
  (resource-id 0 :type (unsigned-byte 32)) (load-flags 0 :type (unsigned-byte 32)))

(define-nintendo-ware-section (sound-group-info (:magic "INFO"))
  (%data-start 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (if (block-reference %header #x7801 nil) (block-start %header #x7801) 0))))
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x7900 $table-start (sound-group-entry %data-start)) (count))))

(define-nintendo-ware-section (sound-group-infx (:magic "INFX"))
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x7901 $table-start (sound-group-dependency)) (count))))

(define-nintendo-ware-file (sound-group (:magic ("CGRP" "FGRP")))
  (info nil :type (peek sound-group-info (block-start header #x7800)))
  (infx nil :type (ecase (not (null (block-reference header #x7802 nil))) ((nil) null) ((t) (peek sound-group-infx (block-start header #x7802)))))
  (file nil :type (ecase (not (null (block-reference header #x7801 nil)))
                     ((nil) null)
                     ((t) (peek (raw-block "FILE" (sized-reference-size (block-reference header #x7801)))
                                (block-start header #x7801))))))

(export '(sound-group sound-group-header sound-group-info sound-group-infx sound-group-file sound-group-info-entries sound-group-infx-entries sound-group-entry-file-id sound-group-entry-reference sound-group-entry-content
          sound-group-dependency-resource-id sound-group-dependency-load-flags))
