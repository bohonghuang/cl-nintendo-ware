(in-package #:cl-nintendo-ware)

(defbinstruct/me xwav-dsp-adpcm-context ()
  (predictor-scale 0 :type (unsigned-byte 16))
  (history-1 0 :type (signed-byte 16))
  (history-2 0 :type (signed-byte 16)))

(defbinstruct/me xwav-dsp-adpcm-info ()
  (coefficients (make-array 16 :element-type '(signed-byte 16) :initial-element 0)
                :type (simple-array (signed-byte 16) (16)))
  (initial-context (make-xwav-dsp-adpcm-context) :type xwav-dsp-adpcm-context)
  (loop-context (make-xwav-dsp-adpcm-context) :type xwav-dsp-adpcm-context)
  (padding 0 :type (unsigned-byte 16)))

(defbinstruct/me xwav-ima-adpcm-context ()
  (predictor 0 :type (signed-byte 16))
  (step-index 0 :type (satisfies (unsigned-byte 8) (lambda (value) (<= value 88))))
  (padding 0 :type (unsigned-byte 8)))

(defbinstruct/me xwav-ima-adpcm-info ()
  (initial-context (make-xwav-ima-adpcm-context) :type xwav-ima-adpcm-context)
  (loop-context (make-xwav-ima-adpcm-context) :type xwav-ima-adpcm-context))

(defbinstruct/me xwav-channel (codec sample-count header)
  (%start 0 :type position)
  (%data-start 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (+ 8 (block-start header #x7001)))))
  (samples-reference (make-reference) :type reference)
  (codec-reference (make-reference) :type reference)
  (reserved 0 :type (unsigned-byte 32))
  (codec-info nil :type (ecase codec
                          ((pcm-8 pcm-16) null)
                          (dsp-adpcm (peek xwav-dsp-adpcm-info
                                           (reference-target codec-reference %start #x0300)))
                          (ima-adpcm (peek xwav-ima-adpcm-info
                                           (reference-target codec-reference %start #x0301)))))
  (data #.(make-array 0 :element-type '(signed-byte 8))
        :type (peek (ecase codec
                      (pcm-8 (simple-array (signed-byte 8) (sample-count)))
                      (pcm-16 (simple-array (signed-byte 16) (sample-count)))
                      (dsp-adpcm (simple-array (unsigned-byte 8) ((* 8 (ceiling sample-count 14)))))
                      (ima-adpcm (simple-array (unsigned-byte 4) (sample-count))))
                    (reference-target samples-reference %data-start #x1f00))))

(define-nintendo-ware-section (xwav-info (:magic "INFO"))
  (codec 'pcm-8 :type sample-codec)
  (loop-p nil :type (boolean (unsigned-byte 8)))
  (padding 0 :type (unsigned-byte 16))
  (sample-rate 0 :type (unsigned-byte 32))
  (loop-start 0 :type (unsigned-byte 32))
  (loop-end 0 :type (unsigned-byte 32))
  (reserved 0 :type (unsigned-byte 32))
  ($channels-start 0 :type position)
  (channel-count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (plusp count))))
  (channels #() :type (simple-array
                       (reference-to #x7100 $channels-start (xwav-channel codec loop-end %header)) (channel-count))))

;; Samples are read once through the channel references. DATA retains only its
;; section header, not a second copy of the complete encoded payload.
(define-nintendo-ware-section (xwav-data (:magic "DATA")))

(define-nintendo-ware-file (xwav (:magic ("CWAV" "FWAV")))
  (info nil :type (peek xwav-info (block-start header #x7000)))
  (data nil :type (peek xwav-data (block-start header #x7001))))

(defbinalias (xwav-embedded (:type xwav)) () xwav)

