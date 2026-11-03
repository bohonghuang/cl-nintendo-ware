(in-package #:cl-nintendo-ware)

(defbinstruct/me sound-archive-patricia-node ()
  (leaf-flag 0 :type (unsigned-byte 16))
  (bit-index 0 :type (unsigned-byte 16))
  (left-index 0 :type (unsigned-byte 32))
  (right-index 0 :type (unsigned-byte 32))
  (string-index 0 :type (unsigned-byte 32))
  (resource-id 0 :type (unsigned-byte 32)))

(defbinstruct/me sound-archive-sound-3d-info ()
  (flags 0 :type (unsigned-byte 32))
  (attenuation-rate 0.0 :type single-float)
  (attenuation-curve 0 :type (unsigned-byte 8))
  (doppler-factor 0 :type (unsigned-byte 8))
  (padding 0 :type (unsigned-byte 16))
  (options (make-flag-values) :type flag-values))

(defbinstruct/me sound-archive-wave-sound-info ()
  (item-index 0 :type (unsigned-byte 32))
  (allocate-track-count 0 :type (unsigned-byte 32))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me sound-archive-stream-sound-info ()
  (allocate-track-flags 0 :type (unsigned-byte 16))
  (channel-count 0 :type (unsigned-byte 16))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me sound-archive-wave-archive ()
  (file-id 0 :type (unsigned-byte 32))
  (load-individually 0 :type (unsigned-byte 8))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (3)))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me sound-archive-group ()
  (file-id 0 :type (unsigned-byte 32))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me sound-archive-player ()
  (sound-limit 0 :type (unsigned-byte 32))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me sound-archive-project-info ()
  (maximum-sequences 0 :type (unsigned-byte 16))
  (maximum-sequence-tracks 0 :type (unsigned-byte 16))
  (maximum-stream-sounds 0 :type (unsigned-byte 16))
  (maximum-stream-tracks 0 :type (unsigned-byte 16))
  (maximum-stream-channels 0 :type (unsigned-byte 16))
  (maximum-wave-sounds 0 :type (unsigned-byte 16))
  (maximum-wave-tracks 0 :type (unsigned-byte 16))
  (stream-buffer-times 0 :type (unsigned-byte 8))
  (padding 0 :type (unsigned-byte 8))
  (options 0 :type (unsigned-byte 32)))

(defbinstruct/me sound-archive-patricia-tree ()
  (root-index 0 :type (unsigned-byte 32))
  (count 0 :type (unsigned-byte 32))
  (nodes #() :type (simple-array sound-archive-patricia-node (count))))

(defbinstruct/me sound-archive-string (base)
  (reference (make-sized-reference) :type sized-reference)
  (text #.(coerce "" 'simple-base-string)
        :type (peek (simple-base-string (sized-reference-size reference))
                    (sized-reference-target reference base #x1f01))))

(defbinstruct/me sound-archive-string-table ()
  ($strings-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (sound-archive-string $strings-start) (count))))

(define-nintendo-ware-section (sound-archive-strg (:magic "STRG"))
  ($strg-start 0 :type position)
  (strings nil :type (reference-to #x2400 $strg-start sound-archive-string-table))
  (tree nil :type (reference-to #x2401 $strg-start sound-archive-patricia-tree)))

(defbinstruct/me sound-archive-sequence-info ()
  ($sequence-start 0 :type position)
  (banks nil :type (reference-to #x0100 $sequence-start integer-table))
  (allocate-track-flags 0 :type (unsigned-byte 32))
  (%flags-start 0 :type position)
  (flags (make-flag-values) :type flag-values)
  (start-offset nil :type (ecase (logbitp 0 (flag-values-mask flags))
                            ((nil) null) ((t) (peek (unsigned-byte 32) (flag-position flags 0 %flags-start)))))
  (priority nil :type (ecase (logbitp 1 (flag-values-mask flags))
                        ((nil) null) ((t) (peek packed-priority
                                               (flag-position flags 1 %flags-start))))))

(defbinstruct/me sound-archive-sound ()
  (%start 0 :type position)
  (file-id 0 :type (unsigned-byte 32)) (player-id 0 :type (unsigned-byte 32))
  (volume 0 :type (unsigned-byte 8)) (remote-filter 0 :type (signed-byte 8))
  (padding 0 :type (unsigned-byte 16))
  (detail-reference (make-reference) :type reference)
  (flags (make-flag-values) :type flag-values)
  (detail nil :type (ecase (reference-type detail-reference)
                      (#x2203 (peek sound-archive-sequence-info
                                    (reference-target detail-reference %start #x2203)))
                      (#x2202 (peek sound-archive-wave-sound-info
                                    (reference-target detail-reference %start #x2202)))
                      (#x2201 (peek sound-archive-stream-sound-info
                                    (reference-target detail-reference %start #x2201)))))
  (sound-3d-info nil :type (ecase (not (null (flag-target flags 8 %start)))
                             ((nil) null) ((t) (peek sound-archive-sound-3d-info
                                                    (flag-target flags 8 %start))))))

(defbinstruct/me sound-archive-wave-sound-group ()
  ($group-start 0 :type position)
  (wave-archives nil :type (reference-to #x0100 $group-start integer-table))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me sound-archive-sound-group ()
  ($group-start 0 :type position)
  (first-id 0 :type (unsigned-byte 32)) (last-id 0 :type (unsigned-byte 32))
  (files nil :type (reference-to #x0100 $group-start integer-table))
  (wave-group nil :type (reference-to #x2205 $group-start sound-archive-wave-sound-group))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me sound-archive-bank ()
  ($bank-start 0 :type position)
  (file-id 0 :type (unsigned-byte 32))
  (wave-archives nil :type (reference-to #x0100 $bank-start integer-table))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me sound-archive-external-file ()
  (text #.(coerce "" 'simple-base-string) :type simple-base-string))

(defbinstruct/me sound-archive-internal-file (data-start)
  (reference (make-sized-reference) :type sized-reference)
  (content nil :type (ecase (= (sized-reference-offset reference) -1)
                      ((t) null)
                      ((nil) (peek (sized-file (sized-reference-size reference))
                                   (sized-reference-target reference (+ data-start 8) #x1f00))))))

(defbinstruct/me sound-archive-file (data-start)
  (%start 0 :type position)
  (location-reference (make-reference) :type reference)
  (flags (make-flag-values) :type flag-values)
  (location nil :type (ecase (= (reference-offset location-reference) -1)
                        ((t) null)
                        ((nil) (ecase (reference-type location-reference)
                                 (#x220c (peek (sound-archive-internal-file data-start)
                                               (reference-target location-reference %start #x220c)))
                                 (#x220d (peek sound-archive-external-file
                                               (reference-target location-reference %start #x220d))))))))

(defbinstruct/me sound-archive-sounds-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2200 $table-start sound-archive-sound) (count))))

(defbinstruct/me sound-archive-sound-groups-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2204 $table-start sound-archive-sound-group) (count))))

(defbinstruct/me sound-archive-banks-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2206 $table-start sound-archive-bank) (count))))

(defbinstruct/me sound-archive-wave-archives-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2207 $table-start sound-archive-wave-archive) (count))))

(defbinstruct/me sound-archive-groups-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2208 $table-start sound-archive-group) (count))))

(defbinstruct/me sound-archive-players-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2209 $table-start sound-archive-player) (count))))

(defbinstruct/me sound-archive-files-table (data-start)
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x220a $table-start (sound-archive-file data-start)) (count))))

(define-nintendo-ware-section (sound-archive-info (:magic "INFO"))
  (%data-start 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (if (block-reference %header #x2002 nil) (block-start %header #x2002) 0))))
  ($info-start 0 :type position)
  (sounds nil :type (reference-to #x2100 $info-start sound-archive-sounds-table))
  (sound-groups nil :type (reference-to #x2104 $info-start sound-archive-sound-groups-table))
  (banks nil :type (reference-to #x2101 $info-start sound-archive-banks-table))
  (wave-archives nil :type (reference-to #x2103 $info-start sound-archive-wave-archives-table))
  (groups nil :type (reference-to #x2105 $info-start sound-archive-groups-table))
  (players nil :type (reference-to #x2102 $info-start sound-archive-players-table))
  (files nil :type (reference-to #x2106 $info-start (sound-archive-files-table %data-start)))
  (project-info nil :type (reference-to #x2107 $info-start sound-archive-project-info)))

(define-nintendo-ware-file (sound-archive (:magic ("CSAR" "FSAR")))
  (strg nil :type (ecase (not (null (block-reference header #x2000 nil))) ((nil) null) ((t) (peek sound-archive-strg (block-start header #x2000)))))
  (info nil :type (peek sound-archive-info (block-start header #x2001)))
  (file nil :type (ecase (not (null (block-reference header #x2002 nil)))
                     ((nil) null)
                     ((t) (peek (raw-block "FILE" (sized-reference-size (block-reference header #x2002)))
                                (block-start header #x2002))))))

(export '(sound-archive sound-archive-header sound-archive-strg sound-archive-info sound-archive-file sound-archive-strg-strings sound-archive-strg-tree sound-archive-string-table-entries sound-archive-string-text
          sound-archive-patricia-tree-root-index sound-archive-patricia-tree-nodes sound-archive-patricia-node-resource-id sound-archive-patricia-node-string-index
          sound-archive-info-sounds sound-archive-info-sound-groups sound-archive-info-banks sound-archive-info-wave-archives sound-archive-info-groups sound-archive-info-players sound-archive-info-files sound-archive-info-project-info
          sound-archive-sounds-table-entries sound-archive-sound-groups-table-entries sound-archive-banks-table-entries sound-archive-wave-archives-table-entries
          sound-archive-groups-table-entries sound-archive-players-table-entries sound-archive-files-table-entries sound-archive-sound-file-id sound-archive-sound-player-id sound-archive-sound-detail
          sound-archive-sequence-info sound-archive-sequence-info-banks sound-archive-sequence-info-start-offset sound-archive-sequence-info-priority
          sound-archive-bank-file-id sound-archive-bank-wave-archives sound-archive-player-sound-limit sound-archive-file-location sound-archive-internal-file-reference sound-archive-internal-file-content
          sound-archive-external-file-text sound-archive-project-info-maximum-sequences))
