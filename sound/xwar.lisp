(in-package #:cl-nintendo-ware)

(defbinstruct (xwar-data-position (:type non-negative-fixnum)
                                       (:constructor progn) (:conc-name nil)) ()
  ($xwar-data-start 0 :type position)
  (values 0 :type (map null (constantly $xwar-data-start))))

(define-nintendo-ware-reference (xwar-wave-reference (:sized t))
  (#x1f00 (xwav-embedded)))

(define-nintendo-ware-section (xwar-info (:magic "INFO"))
  (nil nil :type (values (pointer xwar-data-position (map null (constantly (+ 8 (block-start %header #x6801)))))))
  (%data-start 0 :type (values (pointer position (map null (constantly 0)) $xwar-data-start)))
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (xwar-wave-reference %data-start) (count))))

(define-nintendo-ware-file (xwar (:magic ("CWAR" "FWAR")))
  (info nil :type (values (pointer xwar-info (map null (constantly (block-start %header #x6800))))))
  (file nil :type (values (pointer (nintendo-ware-section-raw-block "FILE") (map null (constantly (block-start %header #x6801)))))))

(defun xwar-waves (xwar)
  "Return WAV structures in wave-index order, preserving absent entries as NIL."
  (xwar-info-entries (xwar-info xwar)))

(defmethod read-file ((type (eql 'xwar)) (stream stream))
  (read-xwar stream))

(defbinio xwar stream)
