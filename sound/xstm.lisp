(in-package #:cl-nintendo-ware)

(defbinstruct/me xstm-region (channels stride)
  (start 0 :type (unsigned-byte 32)) (end 0 :type (unsigned-byte 32))
  (contexts #() :type (simple-array xwav-dsp-adpcm-context (channels)))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8))
           :type (simple-array (unsigned-byte 8) ((- stride 8 (* 6 channels))))))

(defbinstruct/me (xstm-region-data (:type (simple-array xstm-region (*)))
                  (:constructor progn) (:conc-name nil)) (channels count)
  (%stride 0 :type (values (pointer (unsigned-byte 16) (map null (constantly 0))
                                   $xstm-region-info-start)))
  (values #() :type (simple-array (xstm-region channels %stride) (count))))
(define-nintendo-ware-reference xstm-region-data-reference (channels count)
  (#x1f00 (xstm-region-data channels count)))

(defbinstruct/me xstm-region-info (channels count)
  ($xstm-region-info-start 0 :type position)
  (entry-size 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (%base 0 :type (values (pointer position (map null (constantly 0)) $xstm-regions-start)))
  (data nil :type (xstm-region-data-reference %base channels count)))

(defbinalias/me (xstm-samples (:type (simple-array (unsigned-byte 8) (*)))) (count)
  (simple-array (unsigned-byte 8) (count)))
(define-nintendo-ware-reference xstm-samples-reference (count)
  (#x1f00 (xstm-samples count)))

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
  (%base 0 :type (values (pointer position (map null (constantly 0)) $xstm-data-start)))
  (sample-data nil :type (xstm-samples-reference %base
                         (* channel-count (+ (* (max 0 (1- block-count)) block-size)
                                             last-block-padded-size))))
  (region-info nil :type (ecase (>= major-version 3)
                          ((nil) null) ((t) (xstm-region-info channel-count region-count))))
  (original-loop-info nil :type (ecase (>= major-version 4) ((nil) null) ((t) xstm-original-loop-info)))
  (secret-info nil :type (ecase (>= major-version 6) ((nil) null) ((t) xstm-secret-info))))

(define-nintendo-ware-reference xstm-channel-indices-reference ()
  (#x0100 (nintendo-ware-sound-channel-indices)))

(defbinstruct/me xstm-track ()
  (%track-start 0 :type position)
  (volume 0 :type (unsigned-byte 8)) (pan 0 :type (unsigned-byte 8))
  (surround-pan 0 :type (unsigned-byte 8)) (surround-mode-p nil :type (boolean (unsigned-byte 8)))
  (channels nil :type (xstm-channel-indices-reference %track-start)))

(defbinstruct/me xstm-channel (encoding)
  (%start 0 :type position)
  (codec-info nil :type (xwav-codec-reference %start)))

(define-nintendo-ware-reference xstm-track-reference ()
  (#x4101 (xstm-track)))
(define-nintendo-ware-reference-array xstm-track-reference-array ()
  (rcurry #'xstm-track-reference))
(define-nintendo-ware-reference xstm-tracks-reference ()
  (#x0101 (xstm-track-reference-array)))
(define-nintendo-ware-reference xstm-channel-reference (encoding)
  (#x4102 (xstm-channel encoding)))
(define-nintendo-ware-reference-array xstm-channel-reference-array (encoding)
  (rcurry #'xstm-channel-reference encoding))
(define-nintendo-ware-reference xstm-channels-reference (encoding)
  (#x0101 (xstm-channel-reference-array encoding)))
(define-nintendo-ware-reference xstm-stream-reference (version)
  (#x4100 (xstm-stream-info version)))

(defbinstruct (xstm-data-position (:type non-negative-fixnum)
              (:constructor progn) (:conc-name nil)) ()
  ($xstm-data-start 0 :type position)
  (values 0 :type (map null (constantly $xstm-data-start))))
(defbinstruct (xstm-regions-position (:type non-negative-fixnum)
              (:constructor progn) (:conc-name nil)) ()
  ($xstm-regions-start 0 :type position)
  (values 0 :type (map null (constantly $xstm-regions-start))))

(define-nintendo-ware-section (xstm-info (:magic "INFO"))
  (%major-version 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (nintendo-ware-file-header-version-major %header))))
  (%info-start 0 :type position)
  (nil nil :type (values (pointer xstm-data-position (map null (constantly (+ 8 (block-start %header #x4002)))))))
  (nil nil :type (values (pointer xstm-regions-position
                         (map null (constantly (if (block-reference %header #x4003 nil)
                                                  (+ 8 (block-start %header #x4003)) 8))))))
  (stream nil :type (values (xstm-stream-reference %info-start %major-version)))
  (tracks nil :type (xstm-tracks-reference %info-start))
  (channels nil :type (xstm-channels-reference %info-start (xstm-stream-info-encoding stream))))

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
  (values (pointer (xstm-stream-reference (+ 8 (block-start header #x4000))
                                         (nintendo-ware-file-header-version-major header))
                   (map null (constantly (+ 8 (block-start header #x4000)))))))

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
  (entries #() :type (map null (constantly (xstm-region-info-data (xstm-stream-info-region-info %information))))))

(define-nintendo-ware-file (xstm (:magic ("CSTM" "FSTM")))
  (info nil :type (values (pointer xstm-info (map null (constantly (block-start %header #x4000))))))
  (seek nil :type (ecase (not (null (block-reference %header #x4001 nil))) ((nil) null) ((t) (values (pointer xstm-seek (map null (constantly (block-start %header #x4001))))))))
  (data nil :type (values (pointer (nintendo-ware-section-raw-block "DATA") (map null (constantly (block-start %header #x4002))))))
  (regions nil :type (ecase (not (null (block-reference %header #x4003 nil))) ((nil) null) ((t) (values (pointer xstm-regions (map null (constantly (block-start %header #x4003)))))))))

(defbinio xstm stream)

(defmethod read-file ((type (eql 'xstm)) (stream stream))
  (read-xstm stream))
