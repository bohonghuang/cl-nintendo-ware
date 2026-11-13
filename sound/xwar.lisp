(in-package #:cl-nintendo-ware)

(define-nintendo-ware-reference (xwar-wave-reference (:sized t)) ()
  (#x1f00 (xwav-embedded)))

(defbinstruct/me (xwar-waves-at-references (:type (simple-array t (*)))
                                         (:constructor progn) (:conc-name nil)) (source count)
  (%base 0 :type position)
  (values #() :type (values (pointer (simple-array (xwar-wave-reference %base) (count))
                                    (map null (constantly source))))))

(define-nintendo-ware-section (xwar-info (:magic "INFO"))
  (count 0 :type (unsigned-byte 32))
  (%references 0 :type position)
  (entries #() :type (ecase (zerop count)
                      ((t) (simple-array (xwar-wave-reference 0) (0)))
                      ((nil) (values (pointer (xwar-waves-at-references %references count)
                                               (map null (constantly 0)) $xwar-data-start)))))
  (nil #.(make-array 0 :element-type '(unsigned-byte 8))
       :type (simple-array (unsigned-byte 8) ((* count 12)))))

(define-nintendo-ware-section (xwar-file (:magic "FILE"))
  ($xwar-data-start 0 :type position))

(define-nintendo-ware-file (xwar (:magic ("CWAR" "FWAR")))
  (info (make-xwar-info) :type xwar-info :tag #x6800)
  (file (make-xwar-file) :type xwar-file :tag #x6801))

(defun xwar-waves (xwar)
  "Return WAV structures in wave-index order, preserving absent entries as NIL."
  (xwar-info-entries (xwar-info xwar)))

(defmethod read-file ((type (eql 'xwar)) (stream stream))
  (read-xwar stream))

(defbinio xwar stream)
