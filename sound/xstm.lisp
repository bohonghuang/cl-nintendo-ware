(in-package #:cl-nintendo-ware)

(defbinstruct/me xstm-region-info ()
  (entry-size 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (data-reference (make-reference) :type reference))

(defbinstruct/me xstm-original-loop-info ()
  (start 0 :type (unsigned-byte 32))
  (end 0 :type (unsigned-byte 32)))

(defbinstruct/me xstm-secret-info ()
  (value 0 :type (unsigned-byte 32)))

(defbinstruct/me xstm-stream-info (major-version)
  (encoding 0 :type (satisfies (unsigned-byte 8)
                             (lambda (encoding) (<= encoding 3))))
  (loop-flag 0 :type (unsigned-byte 8))
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
  (sample-data-reference (make-reference) :type reference)
  (region-info nil :type (ecase (>= major-version 3) ((nil) null) ((t) xstm-region-info)))
  (original-loop-info nil :type (ecase (>= major-version 4) ((nil) null) ((t) xstm-original-loop-info)))
  (secret-info nil :type (ecase (>= major-version 6) ((nil) null) ((t) xstm-secret-info))))

(defbinstruct/me xstm-track ()
  ($track-start 0 :type position)
  (volume 0 :type (unsigned-byte 8)) (pan 0 :type (unsigned-byte 8))
  (surround-pan 0 :type (unsigned-byte 8)) (surround-mode 0 :type (unsigned-byte 8))
  (channels nil :type (reference-to #x0100 $track-start byte-table)))

(defbinstruct/me xstm-channel (encoding)
  (%start 0 :type position)
  (reference (make-reference) :type reference)
  (codec-info nil :type (ecase encoding
                          ((0 1) null)
                          (2 (peek xwav-dsp-adpcm-info (reference-target reference %start #x0300)))
                          (3 (peek xwav-ima-adpcm-info (reference-target reference %start #x0301))))))

(defbinstruct/me xstm-track-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4101 $table-start xstm-track) (count))))

(defbinstruct/me xstm-channel-table (encoding)
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4102 $table-start (xstm-channel encoding)) (count))))

(define-nintendo-ware-section (xstm-info (:magic "INFO"))
  (%major-version 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (header-version-major %header))))
  ($info-start 0 :type position)
  (stream nil :type (reference-to #x4100 $info-start (xstm-stream-info %major-version)))
  (tracks nil :type (reference-to #x0101 $info-start xstm-track-table))
  (channels nil :type (reference-to #x0101 $info-start (xstm-channel-table (xstm-stream-info-encoding stream)))))

(defbinstruct/me xstm-dsp-seek-context ()
  (history-1 0 :type (signed-byte 16)) (history-2 0 :type (signed-byte 16)))

(defbinstruct/me xstm-seek-entry (encoding stride)
  (context (make-xstm-dsp-seek-context) :type (ecase encoding (2 xstm-dsp-seek-context) (3 xwav-ima-adpcm-context)))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- stride 4)))))

(defbinstruct/me xstm-seek-row (encoding stride channels)
  (entries #() :type (simple-array (xstm-seek-entry encoding stride) (channels))))

(define-nintendo-ware-section (xstm-seek (:magic "SEEK"))
  ;; SEEK row counts come from INFO; only its trailing padding needs the tail.
  (%size 0 :type nintendo-ware-section-tail-size)
  (%information nil :type (peek (reference-to #x4100 (+ (block-start %header #x4000) 8)
                                  (xstm-stream-info (header-version-major %header)))
                                (+ (block-start %header #x4000) 8)))
  (%c-type-p nil :type (map null (lambda (ignored) (declare (ignore ignored)) (char= (char (header-magic %header) 0) #\C))))
  (%encoding 2 :type (map null (lambda (ignored) (declare (ignore ignored)) (xstm-stream-info-encoding %information))))
  (%stride 4 :type (map null (lambda (ignored) (declare (ignore ignored))
                             (xstm-stream-info-seek-entry-size %information))))
  (%rows 0 :type (map null (lambda (ignored) (declare (ignore ignored))
                           (if (member %encoding '(2 3))
                               (let ((interval (xstm-stream-info-seek-interval-samples %information)))
                                 (unless (plusp interval) (fail-file "Zero SEEK interval"))
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
  ($regions-start 0 :type position)
  (%information nil :type (peek (reference-to #x4100 (+ (block-start %header #x4000) 8)
                                  (xstm-stream-info (header-version-major %header)))
                                (+ (block-start %header #x4000) 8)))
  (%count 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (xstm-stream-info-region-count %information))))
  (%stride 0 :type (map null (lambda (ignored) (declare (ignore ignored))
                              (let ((stride (xstm-region-info-entry-size (xstm-stream-info-region-info %information))))
                                (unless (= (xstm-stream-info-encoding %information) 2)
                                  (fail-file "Invalid REGN entry layout")) stride))))
  (entries #() :type (peek (simple-array (xstm-region (xstm-stream-info-channel-count %information) %stride) (%count))
                           (reference-target (xstm-region-info-data-reference (xstm-stream-info-region-info %information)) $regions-start #x1f00))))

(define-nintendo-ware-file (xstm (:magic ("CSTM" "FSTM")))
  (info nil :type (peek xstm-info (block-start header #x4000)))
  (seek nil :type (ecase (not (null (block-reference header #x4001 nil))) ((nil) null) ((t) (peek xstm-seek (block-start header #x4001)))))
  (data nil :type (peek (raw-block "DATA")
                        (block-start header #x4002)))
  (regions nil :type (ecase (not (null (block-reference header #x4003 nil))) ((nil) null) ((t) (peek xstm-regions (block-start header #x4003))))))

(export '(xstm xstm-header xstm-info xstm-seek xstm-data xstm-regions xstm-info-stream xstm-info-tracks xstm-info-channels
          xstm-stream-info xstm-stream-info-encoding xstm-stream-info-channel-count xstm-stream-info-region-count
          xstm-stream-info-sample-rate xstm-stream-info-sample-count xstm-stream-info-block-size xstm-stream-info-region-info
          xstm-stream-info-original-loop-info xstm-stream-info-secret-info xstm-original-loop-info-start xstm-original-loop-info-end
          xstm-secret-info-value xstm-track-table-entries xstm-channel-table-entries xstm-track xstm-track-channels xstm-channel xstm-channel-codec-info
          xstm-seek-rows xstm-seek-row-entries xstm-seek-entry-context xstm-dsp-seek-context-history-1 xstm-dsp-seek-context-history-2
          xstm-regions-entries xstm-region-start xstm-region-end xstm-region-contexts))
