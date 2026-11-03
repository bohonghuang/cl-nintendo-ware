(in-package #:cl-nintendo-ware)

(defbinstruct/me sound-stream-region-info ()
  (entry-size 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (data-reference (make-reference) :type reference))

(defbinstruct/me sound-stream-original-loop-info ()
  (start 0 :type (unsigned-byte 32))
  (end 0 :type (unsigned-byte 32)))

(defbinstruct/me sound-stream-secret-info ()
  (value 0 :type (unsigned-byte 32)))

(defbinstruct/me sound-stream-stream-info (major-version)
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
  (region-info nil :type (ecase (>= major-version 3) ((nil) null) ((t) sound-stream-region-info)))
  (original-loop-info nil :type (ecase (>= major-version 4) ((nil) null) ((t) sound-stream-original-loop-info)))
  (secret-info nil :type (ecase (>= major-version 6) ((nil) null) ((t) sound-stream-secret-info))))

(defbinstruct/me sound-stream-track ()
  ($track-start 0 :type position)
  (volume 0 :type (unsigned-byte 8)) (pan 0 :type (unsigned-byte 8))
  (surround-pan 0 :type (unsigned-byte 8)) (surround-mode 0 :type (unsigned-byte 8))
  (channels nil :type (reference-to #x0100 $track-start byte-table)))

(defbinstruct/me sound-stream-channel (encoding)
  (%start 0 :type position)
  (reference (make-reference) :type reference)
  (codec-info nil :type (ecase encoding
                          ((0 1) null)
                          (2 (peek dsp-adpcm-info (reference-target reference %start #x0300)))
                          (3 (peek ima-adpcm-info (reference-target reference %start #x0301))))))

(defbinstruct/me sound-stream-track-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4101 $table-start sound-stream-track) (count))))

(defbinstruct/me sound-stream-channel-table (encoding)
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4102 $table-start (sound-stream-channel encoding)) (count))))

(define-nintendo-ware-section (sound-stream-info (:magic "INFO"))
  (%major-version 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (header-version-major %header))))
  ($info-start 0 :type position)
  (stream nil :type (reference-to #x4100 $info-start (sound-stream-stream-info %major-version)))
  (tracks nil :type (reference-to #x0101 $info-start sound-stream-track-table))
  (channels nil :type (reference-to #x0101 $info-start (sound-stream-channel-table (sound-stream-stream-info-encoding stream)))))

(defbinstruct/me sound-stream-dsp-seek-context ()
  (history-1 0 :type (signed-byte 16)) (history-2 0 :type (signed-byte 16)))

(defbinstruct/me sound-stream-seek-entry (encoding stride)
  (context (make-sound-stream-dsp-seek-context) :type (ecase encoding (2 sound-stream-dsp-seek-context) (3 ima-adpcm-context)))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- stride 4)))))

(defbinstruct/me sound-stream-seek-row (encoding stride channels)
  (entries #() :type (simple-array (sound-stream-seek-entry encoding stride) (channels))))

(define-nintendo-ware-section (sound-stream-seek (:magic "SEEK"))
  ;; SEEK row counts come from INFO; only its trailing padding needs the tail.
  (%size 0 :type nintendo-ware-section-tail-size)
  (%information nil :type (peek (reference-to #x4100 (+ (block-start %header #x4000) 8)
                                  (sound-stream-stream-info (header-version-major %header)))
                                (+ (block-start %header #x4000) 8)))
  (%c-type-p nil :type (map null (lambda (ignored) (declare (ignore ignored)) (char= (char (header-magic %header) 0) #\C))))
  (%encoding 2 :type (map null (lambda (ignored) (declare (ignore ignored)) (sound-stream-stream-info-encoding %information))))
  (%stride 4 :type (map null (lambda (ignored) (declare (ignore ignored))
                             (let ((stride (sound-stream-stream-info-seek-entry-size %information)))
                               (unless (>= stride 4) (fail-file "Short SEEK context")) stride))))
  (%rows 0 :type (map null (lambda (ignored) (declare (ignore ignored))
                           (if (member %encoding '(2 3))
                               (let ((interval (sound-stream-stream-info-seek-interval-samples %information)))
                                 (unless (plusp interval) (fail-file "Zero SEEK interval"))
                                 (ceiling (sound-stream-stream-info-sample-count %information) interval)) 0))))
  (%bytes 0 :type (map null (lambda (ignored) (declare (ignore ignored))
                            (let ((bytes (* %rows %stride (sound-stream-stream-info-channel-count %information))))
                              (unless (<= bytes %size) (fail-file "SEEK table crosses block")) bytes))))
  (rows #() :type (ecase %c-type-p
                    ((t) (simple-array (sound-stream-seek-row/le %encoding %stride (sound-stream-stream-info-channel-count %information)) (%rows)))
                    ((nil) (simple-array (sound-stream-seek-row/be %encoding %stride (sound-stream-stream-info-channel-count %information)) (%rows)))))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- %size %bytes)))))

(defbinstruct/me sound-stream-region (channels stride)
  (start 0 :type (unsigned-byte 32)) (end 0 :type (unsigned-byte 32))
  (contexts #() :type (simple-array dsp-adpcm-context (channels)))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- stride 8 (* 6 channels))))))

(define-nintendo-ware-section (sound-stream-regions (:magic "REGN"))
  ($regions-start 0 :type position)
  (%information nil :type (peek (reference-to #x4100 (+ (block-start %header #x4000) 8)
                                  (sound-stream-stream-info (header-version-major %header)))
                                (+ (block-start %header #x4000) 8)))
  (%count 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (sound-stream-stream-info-region-count %information))))
  (%stride 0 :type (map null (lambda (ignored) (declare (ignore ignored))
                              (let ((stride (sound-stream-region-info-entry-size (sound-stream-stream-info-region-info %information))))
                                (unless (and (= (sound-stream-stream-info-encoding %information) 2)
                                             (>= stride (+ 8 (* 6 (sound-stream-stream-info-channel-count %information)))))
                                  (fail-file "Invalid REGN entry layout")) stride))))
  (entries #() :type (peek (simple-array (sound-stream-region (sound-stream-stream-info-channel-count %information) %stride) (%count))
                           (reference-target (sound-stream-region-info-data-reference (sound-stream-stream-info-region-info %information)) $regions-start #x1f00))))

(define-nintendo-ware-file (sound-stream (:magic ("CSTM" "FSTM")))
  (info nil :type (peek sound-stream-info (block-start header #x4000)))
  (seek nil :type (ecase (not (null (block-reference header #x4001 nil))) ((nil) null) ((t) (peek sound-stream-seek (block-start header #x4001)))))
  (data nil :type (peek (raw-block "DATA" (sized-reference-size (block-reference header #x4002)))
                        (block-start header #x4002)))
  (regions nil :type (ecase (not (null (block-reference header #x4003 nil))) ((nil) null) ((t) (peek sound-stream-regions (block-start header #x4003))))))

(export '(sound-stream sound-stream-header sound-stream-info sound-stream-seek sound-stream-data sound-stream-regions sound-stream-info-stream sound-stream-info-tracks sound-stream-info-channels
          sound-stream-stream-info sound-stream-stream-info-encoding sound-stream-stream-info-channel-count sound-stream-stream-info-region-count
          sound-stream-stream-info-sample-rate sound-stream-stream-info-sample-count sound-stream-stream-info-block-size sound-stream-stream-info-region-info
          sound-stream-stream-info-original-loop-info sound-stream-stream-info-secret-info sound-stream-original-loop-info-start sound-stream-original-loop-info-end
          sound-stream-secret-info-value sound-stream-track-table-entries sound-stream-channel-table-entries sound-stream-track sound-stream-track-channels sound-stream-channel sound-stream-channel-codec-info
          sound-stream-seek-rows sound-stream-seek-row-entries sound-stream-seek-entry-context sound-stream-dsp-seek-context-history-1 sound-stream-dsp-seek-context-history-2
          sound-stream-regions-entries sound-stream-region-start sound-stream-region-end sound-stream-region-contexts))
