(in-package #:cl-nintendo-ware)

(defbinstruct/me xsar-patricia-node ()
  (leaf-flag 0 :type (unsigned-byte 16))
  (bit-index 0 :type (unsigned-byte 16))
  (left-index 0 :type (unsigned-byte 32))
  (right-index 0 :type (unsigned-byte 32))
  (string-index 0 :type (unsigned-byte 32))
  (resource-id 0 :type (unsigned-byte 32)))

(defbinstruct/me xsar-sound-3d-info ()
  (flags 0 :type (unsigned-byte 32))
  (attenuation-rate 0.0 :type single-float)
  (attenuation-curve 0 :type (unsigned-byte 8))
  (doppler-factor 0 :type (unsigned-byte 8))
  (padding 0 :type (unsigned-byte 16))
  (options (make-flag-values) :type flag-values))

(defbinstruct/me xsar-wave-sound-info ()
  (item-index 0 :type (unsigned-byte 32))
  (allocate-track-count 0 :type (unsigned-byte 32))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me xsar-stream-sound-info ()
  (allocate-track-flags 0 :type (unsigned-byte 16))
  (channel-count 0 :type (unsigned-byte 16))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me xsar-wave-archive ()
  (file-id 0 :type (unsigned-byte 32))
  (load-individually 0 :type (unsigned-byte 8))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (3)))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me xsar-group ()
  (file-id 0 :type (unsigned-byte 32))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me xsar-player ()
  (sound-limit 0 :type (unsigned-byte 32))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me xsar-project-info ()
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

(defbinstruct/me xsar-patricia-tree ()
  (root-index 0 :type (unsigned-byte 32))
  (count 0 :type (unsigned-byte 32))
  (nodes #() :type (simple-array xsar-patricia-node (count))))

(defbinstruct/me xsar-string (base)
  (reference (make-sized-reference) :type sized-reference)
  (text #.(coerce "" 'simple-base-string)
        :type (peek (simple-base-string (sized-reference-size reference))
                    (sized-reference-target reference base #x1f01))))

(defbinstruct/me xsar-string-table ()
  ($strings-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (xsar-string $strings-start) (count))))

(define-nintendo-ware-section (xsar-strg (:magic "STRG"))
  ($strg-start 0 :type position)
  (strings nil :type (reference-to #x2400 $strg-start xsar-string-table))
  (tree nil :type (reference-to #x2401 $strg-start xsar-patricia-tree)))

(defbinstruct/me xsar-sequence-info ()
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

(defbinstruct/me xsar-sound ()
  (%start 0 :type position)
  (file-id 0 :type (unsigned-byte 32)) (player-id 0 :type (unsigned-byte 32))
  (volume 0 :type (unsigned-byte 8)) (remote-filter 0 :type (signed-byte 8))
  (padding 0 :type (unsigned-byte 16))
  (detail-reference (make-reference) :type reference)
  (flags (make-flag-values) :type flag-values)
  (detail nil :type (ecase (reference-type detail-reference)
                      (#x2203 (peek xsar-sequence-info
                                    (reference-target detail-reference %start #x2203)))
                      (#x2202 (peek xsar-wave-sound-info
                                    (reference-target detail-reference %start #x2202)))
                      (#x2201 (peek xsar-stream-sound-info
                                    (reference-target detail-reference %start #x2201)))))
  (sound-3d-info nil :type (ecase (not (null (flag-target flags 8 %start)))
                             ((nil) null) ((t) (peek xsar-sound-3d-info
                                                    (flag-target flags 8 %start))))))

(defbinstruct/me xsar-wave-sound-group ()
  ($group-start 0 :type position)
  (wave-archives nil :type (reference-to #x0100 $group-start integer-table))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me xsar-sound-group ()
  ($group-start 0 :type position)
  (first-id 0 :type (unsigned-byte 32)) (last-id 0 :type (unsigned-byte 32))
  (files nil :type (reference-to #x0100 $group-start integer-table))
  (wave-group nil :type (reference-to #x2205 $group-start xsar-wave-sound-group))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me xsar-bank ()
  ($xbnk-start 0 :type position)
  (file-id 0 :type (unsigned-byte 32))
  (wave-archives nil :type (reference-to #x0100 $xbnk-start integer-table))
  (flags (make-flag-values) :type flag-values))

(defbinstruct/me xsar-external-file ()
  (text #.(coerce "" 'simple-base-string) :type simple-base-string))

(defbinstruct/me xsar-internal-file (data-start)
  (reference (make-sized-reference) :type sized-reference)
  (data nil :type (ecase (= (sized-reference-offset reference) -1)
                   ((t) null)
                   ((nil) (peek (simple-array (unsigned-byte 8) ((sized-reference-size reference)))
                                (sized-reference-target reference (+ data-start 8) #x1f00))))))

(defbinstruct/me xsar-file (data-start)
  (%start 0 :type position)
  (location-reference (make-reference) :type reference)
  (flags (make-flag-values) :type flag-values)
  (location nil :type (ecase (= (reference-offset location-reference) -1)
                        ((t) null)
                        ((nil) (ecase (reference-type location-reference)
                                 (#x220c (peek (xsar-internal-file data-start)
                                               (reference-target location-reference %start #x220c)))
                                 (#x220d (peek xsar-external-file
                                               (reference-target location-reference %start #x220d))))))))

(defbinstruct/me xsar-sounds-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2200 $table-start xsar-sound) (count))))

(defbinstruct/me xsar-sound-groups-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2204 $table-start xsar-sound-group) (count))))

(defbinstruct/me xsar-banks-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2206 $table-start xsar-bank) (count))))

(defbinstruct/me xsar-wave-archives-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2207 $table-start xsar-wave-archive) (count))))

(defbinstruct/me xsar-groups-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2208 $table-start xsar-group) (count))))

(defbinstruct/me xsar-players-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x2209 $table-start xsar-player) (count))))

(defbinstruct/me xsar-files-table (data-start)
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x220a $table-start (xsar-file data-start)) (count))))

(define-nintendo-ware-section (xsar-info (:magic "INFO"))
  (%data-start 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (if (block-reference %header #x2002 nil) (block-start %header #x2002) 0))))
  ($info-start 0 :type position)
  (sounds nil :type (reference-to #x2100 $info-start xsar-sounds-table))
  (sound-groups nil :type (reference-to #x2104 $info-start xsar-sound-groups-table))
  (banks nil :type (reference-to #x2101 $info-start xsar-banks-table))
  (wave-archives nil :type (reference-to #x2103 $info-start xsar-wave-archives-table))
  (groups nil :type (reference-to #x2105 $info-start xsar-groups-table))
  (players nil :type (reference-to #x2102 $info-start xsar-players-table))
  (files nil :type (reference-to #x2106 $info-start (xsar-files-table %data-start)))
  (project-info nil :type (reference-to #x220b $info-start xsar-project-info)))

(define-nintendo-ware-file (xsar (:magic ("CSAR" "FSAR")))
  (strg nil :type (ecase (not (null (block-reference header #x2000 nil))) ((nil) null) ((t) (peek xsar-strg (block-start header #x2000)))))
  (info nil :type (peek xsar-info (block-start header #x2001)))
  (file nil :type (ecase (not (null (block-reference header #x2002 nil)))
                     ((nil) null)
                     ((t) (peek (raw-block "FILE")
                                (block-start header #x2002))))))

(defun xsar-files (xsar)
  "Return a simple vector of (NAME . DATA) conses indexed by file ID.
DATA is an octet vector for internal files and NIL for absent/external files.
Names come from resource metadata; later named aliases overwrite earlier ones,
as in cl-nitro: sounds, banks, wave archives, then groups. No files are parsed."
  (let* ((info (xsar-info xsar))
         (table (xsar-info-files info))
         (files (map 'simple-vector
                     (lambda (entry)
                       (cons nil
                             (when entry
                               (let ((location (xsar-file-location entry)))
                                 (when (typep location 'xsar-internal-file)
                                   (xsar-internal-file-data location))))))
                     (when table (xsar-files-table-entries table))))
         (strg (xsar-strg xsar))
         (string-table (when strg (xsar-strg-strings strg)))
         (strings (when string-table (xsar-string-table-entries string-table))))
    (when strings
      (flet ((fill-names (entries file-id flags)
               (when entries
                 (loop for entry across entries when entry do
                   (let ((index (flag-value (funcall flags entry) 0)))
                     (when index
                       (setf (car (aref files (funcall file-id entry)))
                             (xsar-string-text (aref strings index)))))))))
        (fill-names (when (xsar-info-sounds info)
                      (xsar-sounds-table-entries (xsar-info-sounds info)))
                    #'xsar-sound-file-id #'xsar-sound-flags)
        (fill-names (when (xsar-info-banks info)
                      (xsar-banks-table-entries (xsar-info-banks info)))
                    #'xsar-bank-file-id #'xsar-bank-flags)
        (fill-names (when (xsar-info-wave-archives info)
                      (xsar-wave-archives-table-entries (xsar-info-wave-archives info)))
                    #'xsar-wave-archive-file-id #'xsar-wave-archive-flags)
        (fill-names (when (xsar-info-groups info)
                      (xsar-groups-table-entries (xsar-info-groups info)))
                    #'xsar-group-file-id #'xsar-group-flags)))
    files))

(setf (fdefinition 'xsar-file-name) (fdefinition 'car)
      (fdefinition 'xsar-file-data) (fdefinition 'cdr))

