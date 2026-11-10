(in-package #:cl-nintendo-ware)

(defbinstruct (xwav-data-position (:type non-negative-fixnum)
                                       (:constructor progn) (:conc-name nil)) ()
  ($xwav-data-start 0 :type position)
  (values 0 :type (map null (constantly $xwav-data-start))))

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
  (step-index 0 :type (satisfies (unsigned-byte 8) (rcurry #'<= 88)))
  (padding 0 :type (unsigned-byte 8)))

(defbinstruct/me xwav-ima-adpcm-info ()
  (initial-context (make-xwav-ima-adpcm-context) :type xwav-ima-adpcm-context)
  (loop-context (make-xwav-ima-adpcm-context) :type xwav-ima-adpcm-context))

(define-nintendo-ware-reference xwav-codec-reference
  (#x0300 (xwav-dsp-adpcm-info))
  (#x0301 (xwav-ima-adpcm-info)))

(define-nintendo-ware-reference (xwav-samples-reference (:parameters (codec sample-count)))
  (#x1f00 (ecase codec
            (pcm-8 (simple-array (signed-byte 8) (sample-count)))
            (pcm-16 (simple-array (signed-byte 16) (sample-count)))
            (dsp-adpcm (simple-array (unsigned-byte 8) ((* 8 (ceiling sample-count 14)))))
            (ima-adpcm (simple-array (unsigned-byte 4) (sample-count))))))

(defbinstruct/me xwav-channel (codec sample-count)
  (%start 0 :type position)
  (%data-start 0 :type (values (pointer position (map null (constantly 0)) $xwav-data-start)))
  (data #.(make-array 0 :element-type '(signed-byte 8))
        :type (xwav-samples-reference %data-start codec sample-count))
  (codec-info nil :type (xwav-codec-reference %start))
  (reserved 0 :type (unsigned-byte 32)))

(define-nintendo-ware-reference (xwav-channel-reference (:parameters (codec sample-count)))
  (#x7100 (xwav-channel codec sample-count)))

(define-nintendo-ware-section (xwav-info (:magic "INFO"))
  (nil nil :type (values (pointer xwav-data-position
                         (map null (constantly (+ 8 (block-start %header #x7001)))))))
  (codec 'pcm-8 :type nintendo-ware-sound-sample-codec)
  (loop-p nil :type (boolean (unsigned-byte 8)))
  (padding 0 :type (unsigned-byte 16))
  (sample-rate 0 :type (unsigned-byte 32))
  (loop-start 0 :type (unsigned-byte 32))
  (loop-end 0 :type (unsigned-byte 32))
  (reserved 0 :type (unsigned-byte 32))
  (%channels-start 0 :type position)
  (channel-count 0 :type (satisfies (unsigned-byte 32) #'plusp))
  (channels #() :type (simple-array (xwav-channel-reference %channels-start codec loop-end) (channel-count))))

;; Samples are read once through the channel references. DATA retains only its
;; section header, not a second copy of the complete encoded payload.
(define-nintendo-ware-section (xwav-data (:magic "DATA")))

(define-nintendo-ware-file (xwav (:magic ("CWAV" "FWAV")))
  (info nil :type (values (pointer xwav-info (map null (constantly (block-start %header #x7000))))))
  (data nil :type (values (pointer xwav-data (map null (constantly (block-start %header #x7001)))))))

(defbinalias (xwav-embedded (:type xwav)) () xwav)

(defbinio xwav stream)

(defmethod read-file ((type (eql 'xwav)) (stream stream))
  (read-xwav stream))
