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
  (step-index 0 :type (satisfies (unsigned-byte 8) (rcurry #'<= 88)))
  (padding 0 :type (unsigned-byte 8)))

(defbinstruct/me xwav-ima-adpcm-info ()
  (initial-context (make-xwav-ima-adpcm-context) :type xwav-ima-adpcm-context)
  (loop-context (make-xwav-ima-adpcm-context) :type xwav-ima-adpcm-context))

(define-nintendo-ware-reference xwav-codec-reference ()
  (#x0300 (xwav-dsp-adpcm-info))
  (#x0301 (xwav-ima-adpcm-info)))

(defbinalias/me (xwav-sample-array (:type array)) (codec count)
  (ecase codec
    (pcm-8 (simple-array (signed-byte 8) (count)))
    (pcm-16 (simple-array (signed-byte 16) (count)))
    (dsp-adpcm (simple-array (unsigned-byte 8) ((* 8 (ceiling count 14)))))
    (ima-adpcm (simple-array (unsigned-byte 4) (count)))))

(defbinstruct/me xwav-channel ()
  (%start 0 :type position)
  (data-reference #.(make-array 0 :element-type '(unsigned-byte 8))
                  :type (simple-array (unsigned-byte 8) (8)))
  (codec-info nil :type (xwav-codec-reference %start))
  (reserved 0 :type (unsigned-byte 32)))

(define-nintendo-ware-reference xwav-channel-reference ()
  (#x7100 (xwav-channel)))

(define-nintendo-ware-section (xwav-info (:magic "INFO"))
  (codec 'pcm-8 :type nintendo-ware-sound-sample-codec)
  (loop-p nil :type (boolean (unsigned-byte 8)))
  (padding 0 :type (unsigned-byte 16))
  (sample-rate 0 :type (unsigned-byte 32))
  (loop-start 0 :type (unsigned-byte 32))
  (loop-end 0 :type (unsigned-byte 32))
  (reserved 0 :type (unsigned-byte 32))
  (%channels-start 0 :type position)
  (channel-count 0 :type (satisfies (unsigned-byte 32) #'plusp))
  (channels #() :type (simple-array (xwav-channel-reference %channels-start) (channel-count))))

(define-nintendo-ware-section (xwav-data (:magic "DATA"))
  (%size 0 :type nintendo-ware-tail-size)
  (bytes #.(make-array 0 :element-type '(unsigned-byte 8))
         :type (simple-array (unsigned-byte 8) (%size))))

(define-nintendo-ware-file (xwav (:magic ("CWAV" "FWAV")))
  (info (make-xwav-info) :type xwav-info :tag #x7000)
  (data (make-xwav-data) :type xwav-data :tag #x7001))

(defun xwav-samples (wave &optional (channel-index 0))
  "Return the selected channel's native typed samples, using the WAV's BOM."
  (let* ((info (xwav-info-body (xwav-info wave)))
         (codec (xwav-info-body-codec info))
         (count (xwav-info-body-loop-end info))
         (reference (xwav-channel-data-reference (aref (xwav-info-body-channels info) channel-index)))
         (section (xwav-data wave))
         (data (when section (xwav-data-body-bytes (xwav-data-body section))))
         (size (ecase codec
                 (pcm-8 count) (pcm-16 (* 2 count))
                 (dsp-adpcm (* 8 (ceiling count 14)))
                 (ima-adpcm (ceiling count 2))))
         (bytes (ecase (nintendo-ware-file-endian wave)
                  (:little (nintendo-ware-parse (nintendo-ware-data-reference '(#x1f00) data size) reference))
                  (:big (nintendo-ware-parse (nintendo-ware-data-reference/be '(#x1f00) data size) reference)))))
    (when bytes
      (ecase (nintendo-ware-file-endian wave)
        (:little (nintendo-ware-parse (xwav-sample-array codec count) bytes))
        (:big (nintendo-ware-parse (xwav-sample-array/be codec count) bytes))))))

(defbinio xwav stream)

(defmethod read-file ((type (eql 'xwav)) (stream stream))
  (read-xwav stream))
