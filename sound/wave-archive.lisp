(in-package #:cl-nintendo-ware)

(defbinstruct/me wave-archive-entry (upper data-lower data-upper)
  (reference (make-sized-reference) :type sized-reference)
  (content nil :type (ecase (= (sized-reference-offset reference) -1)
                      ((t) null)
                      ((nil) (peek (bounded-wave (+ (sized-reference-target reference (+ data-lower 8) (+ data-lower 8) data-upper #x1f00)
                                           (sized-reference-size reference)))
                                   (sized-reference-target reference (+ data-lower 8) (+ data-lower 8) data-upper #x1f00))))))

(define-nintendo-ware-section (wave-archive-info (:magic "INFO"))
  (%data-lower 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (block-start %header #x6801))))
  (%data-upper 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (block-end %header #x6801))))
  (%start 0 :type position)
  (count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (<= (+ %start 4 (* 12 count)) %upper))))
  (entries #() :type (simple-array (wave-archive-entry %upper %data-lower %data-upper) (count))))

(define-nintendo-ware-file (wave-archive (:magic ("CWAR" "FWAR")))
  (info nil :type (peek wave-archive-info (block-start header #x6800)))
  (file nil :type (peek (raw-block "FILE" (sized-reference-size (block-reference header #x6801)))
                        (block-start header #x6801))))

(export '(wave-archive wave-archive-header wave-archive-info wave-archive-file wave-archive-info-entries wave-archive-entry wave-archive-entry-reference wave-archive-entry-content))
