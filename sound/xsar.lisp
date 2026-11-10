(in-package #:cl-nintendo-ware)

(defbinstruct/me xsar-integer-table ()
  (count 0 :type (unsigned-byte 32))
  (entries #.(make-array 0 :element-type '(unsigned-byte 32)) :type (simple-array (unsigned-byte 32) (count))))

(defbinstruct/me xsar-resource-id-table ()
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array resource-id (count))))

(defbinstruct/me (xsar-packed-priority (:alignment 4)) ()
  (channel-priority 0 :type (unsigned-byte 8))
  (release-priority-p nil :type (boolean bit))
  (release-reserved 0 :type (unsigned-byte 7))
  (reserved 0 :type (unsigned-byte 16)))

(defbinstruct (xsar-data-position (:type non-negative-fixnum)
                                       (:constructor progn) (:conc-name nil)) ()
  ($xsar-data-start 0 :type position)
  (values 0 :type (map null (constantly $xsar-data-start))))

(defbinenum (xsar-pan-mode (:type (unsigned-byte 8))) ()
  (dual 0)
  (balance 1))

(defbinenum (xsar-pan-curve (:type (unsigned-byte 8))) ()
  (sqrt-negative-3 0)
  (sqrt-0 1)
  (sqrt-0-clamp 2)
  (sincos-negative-3 3)
  (sincos-0 4)
  (sincos-0-clamp 5)
  (linear-negative-6 6)
  (linear-0 7)
  (linear-0-clamp 8))

(defbinenum (xsar-attenuation-curve (:type (unsigned-byte 8))) ()
  (logarithmic 0)
  (linear 1))

(defbinenum (xsar-stream-file-type (:type (unsigned-byte 32))) ()
  (invalid 0)
  (binary 1)
  (adts 2)
  (opus 3))

(defbinstruct/me (xsar-front-bypass-info (:alignment 4)) ()
  (front-bypass-p nil :type (boolean bit))
  (reserved 0 :type (unsigned-byte 31)))

(defbinstruct/me (xsar-sound-3d-flag-set (:alignment 4)) ()
  (volume-p nil :type (boolean bit))
  (priority-p nil :type (boolean bit))
  (pan-p nil :type (boolean bit))
  (surround-pan-p nil :type (boolean bit))
  (filter-p nil :type (boolean bit))
  (reserved 0 :type (unsigned-byte 27)))

;; Optional parameter bits and their values follow ascending bit order.
(defbinstruct/me (xsar-sound-3d-option-flag-set (:alignment 4)) ()
  (reserved-0-31 0 :type (unsigned-byte 32)))

(defbinstruct/me (xsar-wave-sound-flag-set (:alignment 4)) ()
  (priority-p nil :type (boolean bit))
  (reserved-1-31 0 :type (unsigned-byte 31)))

(defbinstruct/me (xsar-stream-sound-flag-set (:alignment 4)) ()
  (file-type-p nil :type (boolean bit))
  (loop-start-frame-p nil :type (boolean bit))
  (loop-end-frame-p nil :type (boolean bit))
  (reserved-3-31 0 :type (unsigned-byte 29)))

(defbinstruct/me (xsar-wave-archive-flag-set (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (wave-count-p nil :type (boolean bit))
  (reserved-2-31 0 :type (unsigned-byte 30)))

(defbinstruct/me (xsar-group-flag-set (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (reserved-1-31 0 :type (unsigned-byte 31)))

(defbinstruct/me (xsar-player-flag-set (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (heap-size-p nil :type (boolean bit))
  (reserved-2-31 0 :type (unsigned-byte 30)))

(defbinstruct/me (xsar-sequence-flag-set (:alignment 4)) ()
  (start-offset-p nil :type (boolean bit))
  (priority-p nil :type (boolean bit))
  (reserved-2-31 0 :type (unsigned-byte 30)))

(defbinstruct/me (xsar-sound-flag-set (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (pan-mode-info-p nil :type (boolean bit))
  (player-info-p nil :type (boolean bit))
  (reserved-3-7 0 :type (unsigned-byte 5))
  (sound-3d-offset-p nil :type (boolean bit))
  (reserved-9-16 0 :type (unsigned-byte 8))
  (front-bypass-p nil :type (boolean bit))
  (reserved-18-27 0 :type (unsigned-byte 10))
  (user-parameter-3-p nil :type (boolean bit))
  (user-parameter-2-p nil :type (boolean bit))
  (user-parameter-1-p nil :type (boolean bit))
  (user-parameter-0-p nil :type (boolean bit)))

(defbinstruct/me (xsar-wave-sound-group-flag-set (:alignment 4)) ()
  (reserved-0-31 0 :type (unsigned-byte 32)))

(defbinstruct/me (xsar-sound-group-flag-set (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (reserved-1-31 0 :type (unsigned-byte 31)))

(defbinstruct/me (xsar-bank-flag-set (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (reserved-1-31 0 :type (unsigned-byte 31)))

(defbinstruct/me (xsar-file-flag-set (:alignment 4)) ()
  (reserved-0-31 0 :type (unsigned-byte 32)))

(defbinstruct/me (xsar-pan-mode-info (:alignment 4)) ()
  (mode 'dual :type xsar-pan-mode)
  (curve 'sqrt-negative-3 :type xsar-pan-curve)
  (reserved 0 :type (unsigned-byte 16)))

(defbinstruct/me (xsar-player-info (:alignment 4)) ()
  (priority 0 :type (signed-byte 8))
  (actor-player-id 0 :type (signed-byte 8))
  (reserved 0 :type (unsigned-byte 16)))


(defbinstruct/me xsar-patricia-node ()
  (leaf-p nil :type (boolean (unsigned-byte 16)))
  (bit-index 0 :type (unsigned-byte 16))
  (left-index 0 :type (unsigned-byte 32))
  (right-index 0 :type (unsigned-byte 32))
  (string-index 0 :type (unsigned-byte 32))
  (resource-id (make-resource-id) :type resource-id))

(defbinstruct/me xsar-sound-3d-info ()
  (flags (make-xsar-sound-3d-flag-set) :type xsar-sound-3d-flag-set)
  (attenuation-rate 0.0 :type single-float)
  (attenuation-curve 'logarithmic :type xsar-attenuation-curve)
  (doppler-factor 0 :type (unsigned-byte 8))
  (padding 0 :type (unsigned-byte 16))
  (options (make-xsar-sound-3d-option-flag-set) :type xsar-sound-3d-option-flag-set)
  (reserved-0-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sound-3d-option-flag-set-reserved-0-31 options))))))

(defbinstruct/me xsar-wave-sound-info ()
  (item-index 0 :type (unsigned-byte 32))
  (allocate-track-count 0 :type (unsigned-byte 32))
  (flags (make-xsar-wave-sound-flag-set) :type xsar-wave-sound-flag-set)
  (priority nil :type (ecase (xsar-wave-sound-flag-set-priority-p flags)
                        ((nil) null) ((t) xsar-packed-priority)))
  (reserved-1-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-wave-sound-flag-set-reserved-1-31 flags))))))

(defbinstruct/me xsar-stream-track ()
  ($track-start 0 :type position)
  (volume 0 :type (unsigned-byte 8))
  (pan 0 :type (unsigned-byte 8))
  (span 0 :type (unsigned-byte 8))
  (flags 0 :type (unsigned-byte 8))
  (channels nil :type (or null-reference
                          (values (pointer (map byte-table
                                                (the (function (t) (or null byte-table)) #'identity))
                                           (reference-offset-value #x0100)
                                           $track-start)))))

(defbinstruct/me xsar-stream-track-table ()
  ($xsar-stream-track-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map xsar-stream-track
                                                (the (function (t) (or null xsar-stream-track)) #'identity))
                                           (reference-offset-value #x220e)
                                           $xsar-stream-track-table-start))) (count))))

(defbinstruct/me xsar-stream-sound-info (tracks-p)
  (%stream-start 0 :type position)
  (allocate-track-flags 0 :type (unsigned-byte 16))
  (channel-count 0 :type (unsigned-byte 16))
  (tracks nil :type
          (ecase (plusp tracks-p)
            ((nil) null)
            ((t)
             (or null-reference
                 (values (pointer (map xsar-stream-track-table
                                       (the (function (t) (or null xsar-stream-track-table)) #'identity))
                                  (reference-offset-value #x0101)
                                  %stream-start))))))
  (pitch nil :type (ecase (= tracks-p 2) ((nil) null) ((t) single-float)))
  (sends-reference nil :type (ecase (= tracks-p 2) ((nil) null) ((t) reference)))
  (extension-reference nil :type (ecase (= tracks-p 2) ((nil) null) ((t) reference)))
  (prefetch-file-id nil :type (ecase (= tracks-p 2) ((nil) null) ((t) (unsigned-byte 32))))
  (flags (make-xsar-stream-sound-flag-set)
         :type (ecase (= tracks-p 2)
                 ((nil) xsar-stream-sound-flag-set)
                 ((t) (map null (lambda (ignored) (declare (ignore ignored))
                                  (make-xsar-stream-sound-flag-set))))))
  (file-type nil :type (ecase (xsar-stream-sound-flag-set-file-type-p flags)
                        ((nil) null) ((t) xsar-stream-file-type)))
  (loop-start-frame nil :type (ecase (xsar-stream-sound-flag-set-loop-start-frame-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (loop-end-frame nil :type (ecase (xsar-stream-sound-flag-set-loop-end-frame-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-3-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-stream-sound-flag-set-reserved-3-31 flags))))))

(defbinstruct/me xsar-wave-archive ()
  (file-id 0 :type (unsigned-byte 32))
  (load-individually-p nil :type (boolean (unsigned-byte 8)))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (3)))
  (flags (make-xsar-wave-archive-flag-set) :type xsar-wave-archive-flag-set)
  (string-index nil :type (ecase (xsar-wave-archive-flag-set-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (wave-count nil :type (ecase (xsar-wave-archive-flag-set-wave-count-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-2-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-wave-archive-flag-set-reserved-2-31 flags))))))

(defbinstruct/me xsar-group ()
  (file-id 0 :type (unsigned-byte 32))
  (flags (make-xsar-group-flag-set) :type xsar-group-flag-set)
  (string-index nil :type (ecase (xsar-group-flag-set-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-1-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-group-flag-set-reserved-1-31 flags))))))

(defbinstruct/me xsar-player ()
  (sound-limit 0 :type (unsigned-byte 32))
  (flags (make-xsar-player-flag-set) :type xsar-player-flag-set)
  (string-index nil :type (ecase (xsar-player-flag-set-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (heap-size nil :type (ecase (xsar-player-flag-set-heap-size-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-2-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-player-flag-set-reserved-2-31 flags))))))

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

(defbinstruct/me xsar-string ()
  (reference (make-sized-reference) :type sized-reference)
  (text #.(coerce "" 'simple-base-string)
        :type (values (pointer (simple-base-string (sized-reference-size reference))
                               (map null (constantly (sized-reference-target reference 0 #x1f01)))
                               $strings-start))))

(defbinstruct/me xsar-string-table ()
  ($strings-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array xsar-string (count))))

(define-nintendo-ware-section (xsar-strg (:magic "STRG"))
  ($strg-start 0 :type position)
  (strings nil :type (or null-reference
                         (values (pointer (map xsar-string-table
                                               (the (function (t) (or null xsar-string-table)) #'identity))
                                          (reference-offset-value #x2400)
                                          $strg-start))))
  (tree nil :type (or null-reference
                      (values (pointer (map xsar-patricia-tree
                                            (the (function (t) (or null xsar-patricia-tree)) #'identity))
                                       (reference-offset-value #x2401)
                                       $strg-start)))))

(defbinstruct/me xsar-sequence-info ()
  ($sequence-start 0 :type position)
  (banks nil :type (or null-reference
                       (values (pointer (map xsar-resource-id-table
                                             (the (function (t) (or null xsar-resource-id-table)) #'identity))
                                        (reference-offset-value #x0100)
                                        $sequence-start))))
  (allocate-track-flags 0 :type (unsigned-byte 32))
  (flags (make-xsar-sequence-flag-set) :type xsar-sequence-flag-set)
  (start-offset nil :type (ecase (xsar-sequence-flag-set-start-offset-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (priority nil :type (ecase (xsar-sequence-flag-set-priority-p flags)
                        ((nil) null) ((t) xsar-packed-priority)))
  (reserved-2-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sequence-flag-set-reserved-2-31 flags))))))

(defbinstruct/me xsar-sound (tracks-p)
  (%start 0 :type position)
  (file-id 0 :type (unsigned-byte 32)) (player-id (make-resource-id) :type resource-id)
  (volume 0 :type (unsigned-byte 8)) (remote-filter 0 :type (signed-byte 8))
  (padding 0 :type (unsigned-byte 16))
  (detail-reference (make-reference) :type reference)
  (flags (make-xsar-sound-flag-set) :type xsar-sound-flag-set)
  (string-index nil :type (ecase (xsar-sound-flag-set-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (pan-mode-info nil :type (ecase (xsar-sound-flag-set-pan-mode-info-p flags)
                        ((nil) null) ((t) xsar-pan-mode-info)))
  (player-info nil :type (ecase (xsar-sound-flag-set-player-info-p flags)
                        ((nil) null) ((t) xsar-player-info)))
  (reserved-3-7-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sound-flag-set-reserved-3-7 flags)))))
  (sound-3d-offset nil :type (ecase (xsar-sound-flag-set-sound-3d-offset-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-9-16-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sound-flag-set-reserved-9-16 flags)))))
  (front-bypass nil :type (ecase (xsar-sound-flag-set-front-bypass-p flags)
                        ((nil) null) ((t) xsar-front-bypass-info)))
  (reserved-18-27-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sound-flag-set-reserved-18-27 flags)))))
  (user-parameter-3 nil :type (ecase (xsar-sound-flag-set-user-parameter-3-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (user-parameter-2 nil :type (ecase (xsar-sound-flag-set-user-parameter-2-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (user-parameter-1 nil :type (ecase (xsar-sound-flag-set-user-parameter-1-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (user-parameter-0 nil :type (ecase (xsar-sound-flag-set-user-parameter-0-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (detail nil :type (ecase (reference-type detail-reference)
                      (#x2203 (values (pointer xsar-sequence-info (map null (constantly (reference-target detail-reference %start #x2203))))))
                      (#x2202 (values (pointer xsar-wave-sound-info (map null (constantly (reference-target detail-reference %start #x2202))))))
                      (#x2201 (values (pointer (xsar-stream-sound-info tracks-p) (map null (constantly (reference-target detail-reference %start #x2201))))))))
  (sound-3d-info nil :type (ecase (and sound-3d-offset (/= sound-3d-offset #xffffffff))
                        ((nil) null) ((t) (values (pointer xsar-sound-3d-info (map null (constantly (+ %start sound-3d-offset)))))))))

(defbinstruct/me xsar-wave-sound-group ()
  ($xsar-wave-sound-group-start 0 :type position)
  (wave-archives nil :type (or null-reference
                               (values (pointer (map xsar-resource-id-table
                                                     (the (function (t) (or null xsar-resource-id-table)) #'identity))
                                                (reference-offset-value #x0100)
                                                $xsar-wave-sound-group-start))))
  (flags (make-xsar-wave-sound-group-flag-set) :type xsar-wave-sound-group-flag-set)
  (reserved-0-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-wave-sound-group-flag-set-reserved-0-31 flags))))))

(defbinstruct/me xsar-sound-group ()
  ($xsar-sound-group-start 0 :type position)
  (first-id (make-resource-id) :type resource-id) (last-id (make-resource-id) :type resource-id)
  (files nil :type (or null-reference
                       (values (pointer (map xsar-integer-table
                                             (the (function (t) (or null xsar-integer-table)) #'identity))
                                        (reference-offset-value #x0100)
                                        $xsar-sound-group-start))))
  (wave-group nil :type (or null-reference
                            (values (pointer (map xsar-wave-sound-group
                                                  (the (function (t) (or null xsar-wave-sound-group)) #'identity))
                                             (reference-offset-value #x2205)
                                             $xsar-sound-group-start))))
  (flags (make-xsar-sound-group-flag-set) :type xsar-sound-group-flag-set)
  (string-index nil :type (ecase (xsar-sound-group-flag-set-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-1-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sound-group-flag-set-reserved-1-31 flags))))))

(defbinstruct/me xsar-bank ()
  ($xbnk-start 0 :type position)
  (file-id 0 :type (unsigned-byte 32))
  (wave-archives nil :type (or null-reference
                               (values (pointer (map xsar-resource-id-table
                                                     (the (function (t) (or null xsar-resource-id-table)) #'identity))
                                                (reference-offset-value #x0100)
                                                $xbnk-start))))
  (flags (make-xsar-bank-flag-set) :type xsar-bank-flag-set)
  (string-index nil :type (ecase (xsar-bank-flag-set-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-1-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-bank-flag-set-reserved-1-31 flags))))))

(defbinstruct/me xsar-external-file ()
  (text #.(coerce "" 'simple-base-string) :type simple-base-string))

(defbinstruct/me xsar-internal-file ()
  (reference (make-sized-reference)
             :type (satisfies sized-reference
                              (lambda (reference)
                                (member (sized-reference-type reference) '(0 #x1f00)))))
  (data nil :type (ecase (= (sized-reference-offset reference) -1)
                   ((t) null)
                   ((nil) (values (pointer (simple-array (unsigned-byte 8) ((sized-reference-size reference))) (map null (constantly (sized-reference-target reference 0))) $xsar-data-start))))))

(defbinstruct/me xsar-file ()
  (%start 0 :type position)
  (location-reference (make-reference) :type reference)
  (flags (make-xsar-file-flag-set) :type xsar-file-flag-set)
  (reserved-0-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-file-flag-set-reserved-0-31 flags)))))
  (location nil :type (ecase (= (reference-offset location-reference) -1)
                        ((t) null)
                        ((nil) (ecase (reference-type location-reference)
                                 (#x220c (values (pointer xsar-internal-file (map null (constantly (reference-target location-reference %start #x220c))))))
                                 (#x220d (values (pointer xsar-external-file (map null (constantly (reference-target location-reference %start #x220d)))))))))))

(defbinstruct/me xsar-sounds-table (tracks-p)
  ($xsar-sounds-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map (xsar-sound tracks-p)
                                                (the (function (t) (or null xsar-sound)) #'identity))
                                           (reference-offset-value #x2200)
                                           $xsar-sounds-table-start))) (count))))

(defbinstruct/me xsar-sound-groups-table ()
  ($xsar-sound-groups-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map xsar-sound-group
                                                (the (function (t) (or null xsar-sound-group)) #'identity))
                                           (reference-offset-value #x2204)
                                           $xsar-sound-groups-table-start))) (count))))

(defbinstruct/me xsar-banks-table ()
  ($xsar-banks-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map xsar-bank
                                                (the (function (t) (or null xsar-bank)) #'identity))
                                           (reference-offset-value #x2206)
                                           $xsar-banks-table-start))) (count))))

(defbinstruct/me xsar-wave-archives-table ()
  ($xsar-wave-archives-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map xsar-wave-archive
                                                (the (function (t) (or null xsar-wave-archive)) #'identity))
                                           (reference-offset-value #x2207)
                                           $xsar-wave-archives-table-start))) (count))))

(defbinstruct/me xsar-groups-table ()
  ($xsar-groups-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map xsar-group
                                                (the (function (t) (or null xsar-group)) #'identity))
                                           (reference-offset-value #x2208)
                                           $xsar-groups-table-start))) (count))))

(defbinstruct/me xsar-players-table ()
  ($xsar-players-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map xsar-player
                                                (the (function (t) (or null xsar-player)) #'identity))
                                           (reference-offset-value #x2209)
                                           $xsar-players-table-start))) (count))))

(defbinstruct/me xsar-files-table ()
  ($xsar-files-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map xsar-file
                                                (the (function (t) (or null xsar-file)) #'identity))
                                           (reference-offset-value #x220a)
                                           $xsar-files-table-start))) (count))))

(define-nintendo-ware-section (xsar-info (:magic "INFO"))
  (nil nil :type (values (pointer xsar-data-position (map null (constantly (if (block-reference %header #x2002 nil) (+ 8 (block-start %header #x2002)) 8))))))
  ($info-start 0 :type position)
  (sounds nil :type
          (or null-reference
              (values
               (pointer
                (map (xsar-sounds-table
                      (if (string= (header-magic %header) "CSAR")
                          (cond ((>= (header-version %header) #x02030200) 2)
                                ((>= (header-version %header) #x02030000) 1)
                                (t 0))
                          0))
                     (the (function (t) (or null xsar-sounds-table)) #'identity))
                (reference-offset-value #x2100)
                $info-start))))
  (sound-groups nil :type (or null-reference
                              (values (pointer (map xsar-sound-groups-table
                                                    (the (function (t) (or null xsar-sound-groups-table)) #'identity))
                                               (reference-offset-value #x2104)
                                               $info-start))))
  (banks nil :type (or null-reference
                       (values (pointer (map xsar-banks-table
                                             (the (function (t) (or null xsar-banks-table)) #'identity))
                                        (reference-offset-value #x2101)
                                        $info-start))))
  (wave-archives nil :type (or null-reference
                               (values (pointer (map xsar-wave-archives-table
                                                     (the (function (t) (or null xsar-wave-archives-table)) #'identity))
                                                (reference-offset-value #x2103)
                                                $info-start))))
  (groups nil :type (or null-reference
                        (values (pointer (map xsar-groups-table
                                              (the (function (t) (or null xsar-groups-table)) #'identity))
                                         (reference-offset-value #x2105)
                                         $info-start))))
  (players nil :type (or null-reference
                         (values (pointer (map xsar-players-table
                                               (the (function (t) (or null xsar-players-table)) #'identity))
                                          (reference-offset-value #x2102)
                                          $info-start))))
  (files nil :type (or null-reference
                       (values (pointer (map xsar-files-table
                                             (the (function (t) (or null xsar-files-table)) #'identity))
                                        (reference-offset-value #x2106)
                                        $info-start))))
  (project-info nil :type (or null-reference
                              (values (pointer (map xsar-project-info
                                                    (the (function (t) (or null xsar-project-info)) #'identity))
                                               (reference-offset-value #x220b)
                                               $info-start)))))

(define-nintendo-ware-file (xsar (:magic ("CSAR" "FSAR")))
  (strg nil :type (ecase (not (null (block-reference %header #x2000 nil))) ((nil) null) ((t) (values (pointer xsar-strg (map null (constantly (block-start %header #x2000))))))))
  (info nil :type (values (pointer xsar-info (map null (constantly (block-start %header #x2001))))))
  (file nil :type (ecase (not (null (block-reference %header #x2002 nil)))
                     ((nil) null)
                     ((t) (values (pointer (raw-block "FILE") (map null (constantly (block-start %header #x2002)))))))))

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
      (flet ((fill-names (entries file-id string-index)
               (when entries
                 (loop for entry across entries when entry do
                   (let ((index (funcall string-index entry)))
                     (when index
                       (setf (car (aref files (funcall file-id entry)))
                             (xsar-string-text (aref strings index)))))))))
        (fill-names (when (xsar-info-sounds info)
                      (xsar-sounds-table-entries (xsar-info-sounds info)))
                    #'xsar-sound-file-id #'xsar-sound-string-index)
        (fill-names (when (xsar-info-banks info)
                      (xsar-banks-table-entries (xsar-info-banks info)))
                    #'xsar-bank-file-id #'xsar-bank-string-index)
        (fill-names (when (xsar-info-wave-archives info)
                      (xsar-wave-archives-table-entries (xsar-info-wave-archives info)))
                    #'xsar-wave-archive-file-id #'xsar-wave-archive-string-index)
        (fill-names (when (xsar-info-groups info)
                      (xsar-groups-table-entries (xsar-info-groups info)))
                    #'xsar-group-file-id #'xsar-group-string-index)))
    files))

(setf (fdefinition 'xsar-file-name) (fdefinition 'car)
      (fdefinition 'xsar-file-data) (fdefinition 'cdr))

(defbinio xsar stream)

(defmethod read-file ((type (eql 'xsar)) (stream stream))
  (read-xsar stream))
