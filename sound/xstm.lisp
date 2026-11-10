(in-package #:cl-nintendo-ware)

(defbinstruct/me xstm-region-info ()
  (entry-size 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (data-reference (make-nintendo-ware-reference) :type nintendo-ware-reference))

(defbinstruct/me xstm-original-loop-info ()
  (start 0 :type (unsigned-byte 32))
  (end 0 :type (unsigned-byte 32)))

(defbinstruct/me xstm-secret-info ()
  (value 0 :type (unsigned-byte 32)))

(defbinstruct/me xstm-stream-info (major-version)
  (encoding 'pcm-8 :type nintendo-ware-sound-sample-codec)
  (loop-p nil :type (boolean (unsigned-byte 8)))
  (channel-count 0 :type (unsigned-byte 8))
  (region-count 0 :type (unsigned-byte 8))
  (sample-rate 0 :type (unsigned-byte 32))
  (loop-start 0 :type (unsigned-byte 32))
  (sample-count 0 :type (unsigned-byte 32))
  (block-count 0 :type (unsigned-byte 32))
  (block-size 0 :type (unsigned-byte 32))
  (block-sample-count 0 :type (unsigned-byte 32))
  (last-block-size 0 :type (unsigned-byte 32))
  (last-block-sample-count 0 :type (unsigned-byte 32))
  (last-block-padded-size 0 :type (unsigned-byte 32))
  (seek-entry-size 0 :type (unsigned-byte 32))
  (seek-interval-samples 0 :type (unsigned-byte 32))
  (sample-data-reference (make-nintendo-ware-reference) :type nintendo-ware-reference)
  (region-info nil :type (ecase (>= major-version 3) ((nil) null) ((t) xstm-region-info)))
  (original-loop-info nil :type (ecase (>= major-version 4) ((nil) null) ((t) xstm-original-loop-info)))
  (secret-info nil :type (ecase (>= major-version 6) ((nil) null) ((t) xstm-secret-info))))

(defbinstruct/me xstm-track ()
  (%track-start 0 :type position)
  (volume 0 :type (unsigned-byte 8)) (pan 0 :type (unsigned-byte 8))
  (surround-pan 0 :type (unsigned-byte 8)) (surround-mode-p nil :type (boolean (unsigned-byte 8)))
  (channels nil :type (or nintendo-ware-null-reference
                          (values (pointer (map nintendo-ware-sound-channel-indices
                                                (the (function (t) (or null (simple-array (unsigned-byte 8) (*)))) #'identity))
                                           (nintendo-ware-reference-offset-value #x0100)
                                           %track-start)))))

(defbinstruct/me xstm-channel (encoding)
  (%start 0 :type position)
  (reference (make-nintendo-ware-reference) :type nintendo-ware-reference)
  (codec-info nil :type (ecase encoding
                          ((pcm-8 pcm-16) null)
                          (dsp-adpcm (values (pointer xwav-dsp-adpcm-info (map null (constantly (nintendo-ware-reference-target reference %start #x0300))))))
                          (ima-adpcm (values (pointer xwav-ima-adpcm-info (map null (constantly (nintendo-ware-reference-target reference %start #x0301)))))))))

(defbinalias/me (xstm-info-tracks (:type (simple-array (or null xstm-track) (*)))) ()
  (nintendo-ware-reference-array #x4101 (xstm-track)))

(defbinalias/me (xstm-info-channels (:type (simple-array (or null xstm-channel) (*)))) (encoding)
  (nintendo-ware-reference-array #x4102 (xstm-channel encoding)))

(define-nintendo-ware-section (xstm-info (:magic "INFO"))
  (%major-version 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (nintendo-ware-file-header-version-major %header))))
  (%info-start 0 :type position)
  (stream nil :type (or nintendo-ware-null-reference
                        (values (pointer (map (xstm-stream-info %major-version)
                                              (the (function (t) (or null xstm-stream-info)) #'identity))
                                         (nintendo-ware-reference-offset-value #x4100)
                                         %info-start))))
  (tracks nil :type (or nintendo-ware-null-reference
                        (values (pointer (map xstm-info-tracks
                                              (the (function (t) (or null (simple-array (or null xstm-track) (*)))) #'identity))
                                         (nintendo-ware-reference-offset-value #x0101)
                                         %info-start))))
  (channels nil :type (or nintendo-ware-null-reference
                          (values (pointer (map (xstm-info-channels (xstm-stream-info-encoding stream))
                                                (the (function (t) (or null (simple-array (or null xstm-channel) (*)))) #'identity))
                                           (nintendo-ware-reference-offset-value #x0101)
                                           %info-start)))))

(defbinstruct/me xstm-dsp-seek-context ()
  (history-1 0 :type (signed-byte 16)) (history-2 0 :type (signed-byte 16)))

(defbinstruct/me xstm-seek-entry (encoding stride)
  (context (make-xstm-dsp-seek-context) :type (ecase encoding (dsp-adpcm xstm-dsp-seek-context) (ima-adpcm xwav-ima-adpcm-context)))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- stride 4)))))

(defbinalias/me (xstm-seek-row (:type (simple-array xstm-seek-entry (*)))) (encoding stride channels)
  (simple-array (xstm-seek-entry encoding stride) (channels)))

;; CSTM SEEK payloads remain LE even inside a BE container.
(defbinalias xstm-seek-row/le (encoding stride channels) (xstm-seek-row encoding stride channels))

;; SEEK and REGN follow the same INFO reference without moving their cursor.
(defbinalias/me (xstm-referenced-stream-info (:type (or null xstm-stream-info))) (header)
  (values
   (pointer
    (or nintendo-ware-null-reference
        (values
         (pointer (map (xstm-stream-info (nintendo-ware-file-header-version-major header))
                       (the (function (t) (or null xstm-stream-info)) #'identity))
                  (nintendo-ware-reference-offset-value #x4100)
                  (+ (block-start header #x4000) 8))))
    (map null (constantly (+ (block-start header #x4000) 8))))))

(define-nintendo-ware-section (xstm-seek (:magic "SEEK"))
  ;; SEEK row counts come from INFO; only its trailing padding needs the tail.
  (%size 0 :type nintendo-ware-section-tail-size)
  (%information (make-xstm-stream-info) :type (xstm-referenced-stream-info %header))
  (%c-type-p nil :type (map null (lambda (ignored) (declare (ignore ignored)) (char= (char (nintendo-ware-file-header-magic %header) 0) #\C))))
  (%encoding 'dsp-adpcm :type (map null (lambda (ignored) (declare (ignore ignored)) (xstm-stream-info-encoding %information))))
  (%stride 4 :type (map null (lambda (ignored) (declare (ignore ignored))
                             (xstm-stream-info-seek-entry-size %information))))
  (%rows 0 :type (map null (lambda (ignored) (declare (ignore ignored))
                           (if (member %encoding '(dsp-adpcm ima-adpcm))
                               (let ((interval (xstm-stream-info-seek-interval-samples %information)))
                                 (unless (plusp interval) (error 'binstruct::deserialize-error
                                                                 :input nil :position nil
                                                                 :info "Zero SEEK interval"))
                                 (ceiling (xstm-stream-info-sample-count %information) interval)) 0))))
  (%bytes 0 :type (map null (lambda (ignored) (declare (ignore ignored))
                            (* %rows %stride (xstm-stream-info-channel-count %information)))))
  (rows #() :type (ecase %c-type-p
                    ((t) (simple-array (xstm-seek-row/le %encoding %stride (xstm-stream-info-channel-count %information)) (%rows)))
                    ((nil) (simple-array (xstm-seek-row/be %encoding %stride (xstm-stream-info-channel-count %information)) (%rows)))))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- %size %bytes)))))

(defbinstruct/me xstm-region (channels stride)
  (start 0 :type (unsigned-byte 32)) (end 0 :type (unsigned-byte 32))
  (contexts #() :type (simple-array xwav-dsp-adpcm-context (channels)))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- stride 8 (* 6 channels))))))

(define-nintendo-ware-section (xstm-regions (:magic "REGN"))
  (%regions-start 0 :type position)
  (%information (make-xstm-stream-info) :type (xstm-referenced-stream-info %header))
  (%count 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (xstm-stream-info-region-count %information))))
  (%stride 0 :type (map null (lambda (ignored) (declare (ignore ignored))
                              (let ((stride (xstm-region-info-entry-size (xstm-stream-info-region-info %information))))
                                (unless (eq (xstm-stream-info-encoding %information) 'dsp-adpcm)
                                  (error 'binstruct::deserialize-error
                                         :input nil :position nil
                                         :info "Invalid REGN entry layout")) stride))))
  (entries #() :type (values (pointer (simple-array (xstm-region (xstm-stream-info-channel-count %information) %stride) (%count)) (map null (constantly (nintendo-ware-reference-target (xstm-region-info-data-reference (xstm-stream-info-region-info %information)) %regions-start #x1f00)))))))

(define-nintendo-ware-file (xstm (:magic ("CSTM" "FSTM")))
  (info nil :type (values (pointer xstm-info (map null (constantly (block-start %header #x4000))))))
  (seek nil :type (ecase (not (null (block-reference %header #x4001 nil))) ((nil) null) ((t) (values (pointer xstm-seek (map null (constantly (block-start %header #x4001))))))))
  (data nil :type (values (pointer (nintendo-ware-section-raw-block "DATA") (map null (constantly (block-start %header #x4002))))))
  (regions nil :type (ecase (not (null (block-reference %header #x4003 nil))) ((nil) null) ((t) (values (pointer xstm-regions (map null (constantly (block-start %header #x4003)))))))))

(defbinio xstm stream)

(defmethod read-file ((type (eql 'xstm)) (stream stream))
  (read-xstm stream))
