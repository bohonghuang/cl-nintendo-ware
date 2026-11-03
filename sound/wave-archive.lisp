(in-package #:cl-nintendo-ware)

(defbinstruct/me wave-archive-entry (data-start)
  (reference (make-sized-reference) :type sized-reference)
  (content nil :type (ecase (= (sized-reference-offset reference) -1)
                      ((t) null)
                      ((nil) (peek (sized-wave (sized-reference-size reference))
                                   (sized-reference-target reference (+ data-start 8) #x1f00))))))

(define-nintendo-ware-section (wave-archive-info (:magic "INFO"))
  (%data-start 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (block-start %header #x6801))))
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (wave-archive-entry %data-start) (count))))

(define-nintendo-ware-file (wave-archive (:magic ("CWAR" "FWAR")))
  (info nil :type (peek wave-archive-info (block-start header #x6800)))
  (file nil :type (peek (raw-block "FILE" (sized-reference-size (block-reference header #x6801)))
                        (block-start header #x6801))))

(export '(wave-archive wave-archive-header wave-archive-info wave-archive-file wave-archive-info-entries wave-archive-entry wave-archive-entry-reference wave-archive-entry-content))
