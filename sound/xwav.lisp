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

(define-nintendo-ware-reference xwav-samples-reference (codec sample-count)
  (#x1f00 (ecase codec
            (pcm-8 (simple-array (signed-byte 8) (sample-count)))
            (pcm-16 (simple-array (signed-byte 16) (sample-count)))
            (dsp-adpcm (simple-array (unsigned-byte 8) ((* 8 (ceiling sample-count 14)))))
            (ima-adpcm (simple-array (unsigned-byte 4) (sample-count))))))

(defbinstruct/me (xwav-samples-at-reference (:type (or null array))
                                          (:constructor progn) (:conc-name nil)) (source codec count)
  (%base 0 :type position)
  (values nil :type (values (pointer (xwav-samples-reference %base codec count)
                                    (map null (constantly source))))))

(defbinstruct/me xwav-channel (codec sample-count)
  (%start 0 :type position)
  (data #.(make-array 0 :element-type '(signed-byte 8))
        :type (pointer (xwav-samples-at-reference %start codec sample-count)
                       (map null (constantly 0)) $xwav-data-start))
  (nil #.(make-array 0 :element-type '(unsigned-byte 8))
       :type (simple-array (unsigned-byte 8) (8)))
  (codec-info nil :type (xwav-codec-reference %start))
  (reserved 0 :type (unsigned-byte 32)))

(define-nintendo-ware-reference xwav-channel-reference (codec sample-count)
  (#x7100 (xwav-channel codec sample-count)))

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
  (channels #() :type (simple-array (xwav-channel-reference %channels-start codec loop-end) (channel-count))))

;; Samples are read once through the channel references. DATA retains only its
;; section header, not a second copy of the complete encoded payload.
(define-nintendo-ware-section (xwav-data (:magic "DATA"))
  ($xwav-data-start 0 :type position))

(define-nintendo-ware-file (xwav (:magic ("CWAV" "FWAV")))
  (info (make-xwav-info) :type xwav-info :tag #x7000)
  (data (make-xwav-data) :type xwav-data :tag #x7001))

(defbinstruct (xwav-embedded (:type xwav) (:constructor progn) (:conc-name nil)) ()
  ;; Each WAR entry starts a fresh lifetime for its sample-data anchor.
  (%reset nil :type (map (null)
                        (constantly (setf (cdr (binstruct::pointer-base '$xwav-data-start)) nil))))
  (values nil :type xwav))

(defun xwav-channels (file)
  "Return channels in channel-index order."
  (xwav-info-channels (xwav-info file)))

(defun xwav-codec (file)
  "Return the sample codec."
  (xwav-info-codec (xwav-info file)))

(defun xwav-sample-rate (file)
  "Return the sample rate in Hz."
  (xwav-info-sample-rate (xwav-info file)))

(defun xwav-loop-p (file)
  "Return whether the wave loops."
  (xwav-info-loop-p (xwav-info file)))

(defun xwav-loop-start (file)
  "Return the loop start sample index."
  (xwav-info-loop-start (xwav-info file)))

(defun xwav-loop-end (file)
  "Return the exclusive end sample index, also the sample count."
  (xwav-info-loop-end (xwav-info file)))

(defbinio xwav stream)

(defmethod read-file ((type (eql 'xwav)) (stream stream))
  (read-xwav stream))
