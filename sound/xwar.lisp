(in-package #:cl-nintendo-ware)

(defbinstruct/me xwar-entry (data-start)
  (reference (make-sized-reference) :type sized-reference)
  (content nil :type (ecase (= (sized-reference-offset reference) -1)
                      ((t) null)
                      ((nil) (peek xwav-embedded
                                   (sized-reference-target reference (+ data-start 8) #x1f00))))))

(define-nintendo-ware-section (xwar-info (:magic "INFO"))
  (%data-start 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (block-start %header #x6801))))
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (xwar-entry %data-start) (count))))

(define-nintendo-ware-file (xwar (:magic ("CWAR" "FWAR")))
  (info nil :type (peek xwar-info (block-start header #x6800)))
  (file nil :type (peek (raw-block "FILE")
                        (block-start header #x6801))))

(defun xwar-waves (xwar)
  "Return WAV structures in wave-index order, preserving absent entries as NIL."
  (map 'simple-vector #'xwar-entry-content (xwar-info-entries (xwar-info xwar))))

