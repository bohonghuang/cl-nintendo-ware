(in-package #:cl-nintendo-ware)

(defbinstruct/me dsp-adpcm-context ()
  (predictor-scale 0 :type (unsigned-byte 16))
  (history-1 0 :type (signed-byte 16))
  (history-2 0 :type (signed-byte 16)))

(defbinstruct/me dsp-adpcm-info ()
  (coefficients (make-array 16 :element-type '(signed-byte 16) :initial-element 0)
                :type (simple-array (signed-byte 16) (16)))
  (initial-context (make-dsp-adpcm-context) :type dsp-adpcm-context)
  (loop-context (make-dsp-adpcm-context) :type dsp-adpcm-context)
  (padding 0 :type (unsigned-byte 16)))

(defbinstruct/me ima-adpcm-context ()
  (predictor 0 :type (signed-byte 16))
  (step-index 0 :type (satisfies (unsigned-byte 8) (lambda (value) (<= value 88))))
  (padding 0 :type (unsigned-byte 8)))

(defbinstruct/me ima-adpcm-info ()
  (initial-context (make-ima-adpcm-context) :type ima-adpcm-context)
  (loop-context (make-ima-adpcm-context) :type ima-adpcm-context))

(defun sound-wave-encoded-size (codec sample-count)
  "The number of encoded bytes for one C/F wave channel, excluding alignment."
  (ecase codec
    (0 sample-count)
    (1 (* 2 sample-count))
    (2 (* 8 (ceiling sample-count 14)))
    (3 (ceiling sample-count 2))))

(defbinstruct/me sound-wave-channel (codec sample-count header)
  (%start 0 :type position)
  (%data-start 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (+ 8 (block-start header #x7001)))))
  (samples-reference (make-reference) :type reference)
  (codec-reference (make-reference) :type reference)
  (reserved 0 :type (unsigned-byte 32))
  (codec-info nil :type (ecase codec
                          ((0 1) null)
                          (2 (peek dsp-adpcm-info
                                   (reference-target codec-reference %start #x0300)))
                          (3 (peek ima-adpcm-info
                                   (reference-target codec-reference %start #x0301)))))
  (encoded-data #.(make-array 0 :element-type '(unsigned-byte 8))
                :type (peek (simple-array (unsigned-byte 8) ((sound-wave-encoded-size codec sample-count)))
                            (reference-target samples-reference %data-start #x1f00))))

(define-nintendo-ware-section (sound-wave-info (:magic "INFO"))
  (codec 0 :type (satisfies (unsigned-byte 8) (lambda (codec) (<= codec 3))))
  (loop 0 :type (unsigned-byte 8))
  (padding 0 :type (unsigned-byte 16))
  (sample-rate 0 :type (unsigned-byte 32))
  (loop-start 0 :type (unsigned-byte 32))
  (loop-end 0 :type (unsigned-byte 32))
  (reserved 0 :type (unsigned-byte 32))
  ($channels-start 0 :type position)
  (channel-count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (plusp count))))
  (channels #() :type (simple-array
                       (reference-to #x7100 $channels-start (sound-wave-channel codec loop-end %header)) (channel-count))))

(define-nintendo-ware-file (sound-wave (:magic ("CWAV" "FWAV")))
  (info nil :type (peek sound-wave-info (block-start header #x7000)))
  (data nil :type (peek (raw-block "DATA" (sized-reference-size (block-reference header #x7001)))
                        (block-start header #x7001))))

(defbinstruct (sized-wave (:type sound-wave) (:constructor progn) (:conc-name nil)
                          (:include (file-span size))) (size)
  (values nil :type (ecase %endian (:little sound-wave/le) (:big sound-wave/be))))

(export '(sound-wave sound-wave-header sound-wave-info sound-wave-data sound-wave-info-codec sound-wave-info-loop sound-wave-info-sample-rate
          sound-wave-info-loop-start sound-wave-info-loop-end sound-wave-info-channels sound-wave-channel sound-wave-channel-samples-reference
          sound-wave-channel-codec-reference sound-wave-channel-codec-info sound-wave-channel-encoded-data
          dsp-adpcm-info dsp-adpcm-info-coefficients dsp-adpcm-info-initial-context dsp-adpcm-info-loop-context
          dsp-adpcm-context dsp-adpcm-context-predictor-scale dsp-adpcm-context-history-1 dsp-adpcm-context-history-2
          ima-adpcm-info ima-adpcm-info-initial-context ima-adpcm-info-loop-context
          ima-adpcm-context ima-adpcm-context-predictor ima-adpcm-context-step-index))
