(in-package #:cl-nintendo-ware)

(defbinstruct/me (xsar-sound-group-files (:type (simple-array (unsigned-byte 32) (*)))
                  (:constructor progn) (:conc-name nil)) ()
  (%count 0 :type (unsigned-byte 32))
  (values #.(make-array 0 :element-type '(unsigned-byte 32)) :type (simple-array (unsigned-byte 32) (%count))))

(defbinstruct/me (xsar-resource-ids (:type (simple-array nintendo-ware-sound-resource-id (*)))
                  (:constructor progn) (:conc-name nil)) ()
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array nintendo-ware-sound-resource-id (%count))))

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

(defbinstruct/me (xsar-sound-3d-flags (:alignment 4)) ()
  (volume-p nil :type (boolean bit))
  (priority-p nil :type (boolean bit))
  (pan-p nil :type (boolean bit))
  (surround-pan-p nil :type (boolean bit))
  (filter-p nil :type (boolean bit))
  (reserved 0 :type (unsigned-byte 27)))

;; Optional parameter bits and their values follow ascending bit order.
(defbinstruct/me (xsar-sound-3d-option-flags (:alignment 4)) ()
  (reserved-0-31 0 :type (unsigned-byte 32)))

(defbinstruct/me (xsar-wave-sound-flags (:alignment 4)) ()
  (priority-p nil :type (boolean bit))
  (reserved-1-31 0 :type (unsigned-byte 31)))

(defbinstruct/me (xsar-stream-sound-flags (:alignment 4)) ()
  (file-type-p nil :type (boolean bit))
  (loop-start-frame-p nil :type (boolean bit))
  (loop-end-frame-p nil :type (boolean bit))
  (reserved-3-31 0 :type (unsigned-byte 29)))

(defbinstruct/me (xsar-wave-archive-flags (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (wave-count-p nil :type (boolean bit))
  (reserved-2-31 0 :type (unsigned-byte 30)))

(defbinstruct/me (xsar-group-flags (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (reserved-1-31 0 :type (unsigned-byte 31)))

(defbinstruct/me (xsar-player-flags (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (heap-size-p nil :type (boolean bit))
  (reserved-2-31 0 :type (unsigned-byte 30)))

(defbinstruct/me (xsar-sequence-flags (:alignment 4)) ()
  (start-offset-p nil :type (boolean bit))
  (priority-p nil :type (boolean bit))
  (reserved-2-31 0 :type (unsigned-byte 30)))

(defbinstruct/me (xsar-sound-flags (:alignment 4)) ()
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

(defbinstruct/me (xsar-wave-sound-group-flags (:alignment 4)) ()
  (reserved-0-31 0 :type (unsigned-byte 32)))

(defbinstruct/me (xsar-sound-group-flags (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (reserved-1-31 0 :type (unsigned-byte 31)))

(defbinstruct/me (xsar-bank-flags (:alignment 4)) ()
  (string-index-p nil :type (boolean bit))
  (reserved-1-31 0 :type (unsigned-byte 31)))

(defbinstruct/me (xsar-file-flags (:alignment 4)) ()
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
  (resource-id (make-nintendo-ware-sound-resource-id) :type nintendo-ware-sound-resource-id))

(defbinstruct/me xsar-sound-3d-info ()
  (flags (make-xsar-sound-3d-flags) :type xsar-sound-3d-flags)
  (attenuation-rate 0.0 :type single-float)
  (attenuation-curve 'logarithmic :type xsar-attenuation-curve)
  (doppler-factor 0 :type (unsigned-byte 8))
  (padding 0 :type (unsigned-byte 16))
  (options (make-xsar-sound-3d-option-flags) :type xsar-sound-3d-option-flags)
  (reserved-0-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sound-3d-option-flags-reserved-0-31 options))))))

(defbinstruct/me xsar-wave-sound-info ()
  (item-index 0 :type (unsigned-byte 32))
  (allocate-track-count 0 :type (unsigned-byte 32))
  (flags (make-xsar-wave-sound-flags) :type xsar-wave-sound-flags)
  (priority nil :type (ecase (xsar-wave-sound-flags-priority-p flags)
                        ((nil) null) ((t) xsar-packed-priority)))
  (reserved-1-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-wave-sound-flags-reserved-1-31 flags))))))

(defbinstruct/me xsar-stream-track ()
  ($track-start 0 :type position)
  (volume 0 :type (unsigned-byte 8))
  (pan 0 :type (unsigned-byte 8))
  (span 0 :type (unsigned-byte 8))
  (flags 0 :type (unsigned-byte 8))
  (channels nil :type (or nintendo-ware-null-reference
                          (values (pointer (map nintendo-ware-sound-channel-indices
                                                (the (function (t) (or null (simple-array (unsigned-byte 8) (*)))) #'identity))
                                           (nintendo-ware-reference-offset-value #x0100)
                                           $track-start)))))

(defbinstruct/me (xsar-stream-sound-info-tracks (:type (simple-array (or null xsar-stream-track) (*)))
                  (:constructor progn) (:conc-name nil)) ()
  ($xsar-stream-sound-info-tracks-start 0 :type position)
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array
                     (or nintendo-ware-null-reference
                         (values (pointer (map xsar-stream-track
                                               (the (function (t) (or null xsar-stream-track)) #'identity))
                                          (nintendo-ware-reference-offset-value #x220e)
                                          $xsar-stream-sound-info-tracks-start))) (%count))))

(defbinstruct/me xsar-stream-sound-info (tracks-p)
  (%stream-start 0 :type position)
  (allocate-track-flags 0 :type (unsigned-byte 16))
  (channel-count 0 :type (unsigned-byte 16))
  (tracks nil :type
          (ecase (plusp tracks-p)
            ((nil) null)
            ((t)
             (or nintendo-ware-null-reference
                 (values (pointer (map xsar-stream-sound-info-tracks
                                       (the (function (t) (or null (simple-array (or null xsar-stream-track) (*)))) #'identity))
                                  (nintendo-ware-reference-offset-value #x0101)
                                  %stream-start))))))
  (pitch nil :type (ecase (= tracks-p 2) ((nil) null) ((t) single-float)))
  (sends-reference nil :type (ecase (= tracks-p 2) ((nil) null) ((t) nintendo-ware-reference)))
  (extension-reference nil :type (ecase (= tracks-p 2) ((nil) null) ((t) nintendo-ware-reference)))
  (prefetch-file-id nil :type (ecase (= tracks-p 2) ((nil) null) ((t) (unsigned-byte 32))))
  (flags (make-xsar-stream-sound-flags)
         :type (ecase (= tracks-p 2)
                 ((nil) xsar-stream-sound-flags)
                 ((t) (map null (lambda (ignored) (declare (ignore ignored))
                                  (make-xsar-stream-sound-flags))))))
  (file-type nil :type (ecase (xsar-stream-sound-flags-file-type-p flags)
                        ((nil) null) ((t) xsar-stream-file-type)))
  (loop-start-frame nil :type (ecase (xsar-stream-sound-flags-loop-start-frame-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (loop-end-frame nil :type (ecase (xsar-stream-sound-flags-loop-end-frame-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-3-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-stream-sound-flags-reserved-3-31 flags))))))

(defbinstruct/me xsar-wave-archive ()
  (file-id 0 :type (unsigned-byte 32))
  (load-individually-p nil :type (boolean (unsigned-byte 8)))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (3)))
  (flags (make-xsar-wave-archive-flags) :type xsar-wave-archive-flags)
  (string-index nil :type (ecase (xsar-wave-archive-flags-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (wave-count nil :type (ecase (xsar-wave-archive-flags-wave-count-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-2-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-wave-archive-flags-reserved-2-31 flags))))))

(defbinstruct/me xsar-group ()
  (file-id 0 :type (unsigned-byte 32))
  (flags (make-xsar-group-flags) :type xsar-group-flags)
  (string-index nil :type (ecase (xsar-group-flags-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-1-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-group-flags-reserved-1-31 flags))))))

(defbinstruct/me xsar-player ()
  (sound-limit 0 :type (unsigned-byte 32))
  (flags (make-xsar-player-flags) :type xsar-player-flags)
  (string-index nil :type (ecase (xsar-player-flags-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (heap-size nil :type (ecase (xsar-player-flags-heap-size-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-2-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-player-flags-reserved-2-31 flags))))))

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
  (reference (make-nintendo-ware-sized-reference) :type nintendo-ware-sized-reference)
  (text #.(coerce "" 'simple-base-string)
        :type (values (pointer (simple-base-string (nintendo-ware-sized-reference-size reference))
                               (map null (constantly (nintendo-ware-sized-reference-target reference 0 #x1f01)))
                               $strings-start))))

(defbinstruct/me (xsar-strg-strings (:type (simple-array xsar-string (*)))
                  (:constructor progn) (:conc-name nil)) ()
  ($strings-start 0 :type position)
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array xsar-string (%count))))

(define-nintendo-ware-section (xsar-strg (:magic "STRG"))
  ($strg-start 0 :type position)
  (strings nil :type (or nintendo-ware-null-reference
                         (values (pointer (map xsar-strg-strings
                                               (the (function (t) (or null (simple-array xsar-string (*)))) #'identity))
                                          (nintendo-ware-reference-offset-value #x2400)
                                          $strg-start))))
  (tree nil :type (or nintendo-ware-null-reference
                      (values (pointer (map xsar-patricia-tree
                                            (the (function (t) (or null xsar-patricia-tree)) #'identity))
                                       (nintendo-ware-reference-offset-value #x2401)
                                       $strg-start)))))

(defbinstruct/me xsar-sequence-info ()
  ($sequence-start 0 :type position)
  (banks nil :type (or nintendo-ware-null-reference
                       (values (pointer (map xsar-resource-ids
                                             (the (function (t) (or null (simple-array nintendo-ware-sound-resource-id (*)))) #'identity))
                                        (nintendo-ware-reference-offset-value #x0100)
                                        $sequence-start))))
  (allocate-track-flags 0 :type (unsigned-byte 32))
  (flags (make-xsar-sequence-flags) :type xsar-sequence-flags)
  (start-offset nil :type (ecase (xsar-sequence-flags-start-offset-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (priority nil :type (ecase (xsar-sequence-flags-priority-p flags)
                        ((nil) null) ((t) xsar-packed-priority)))
  (reserved-2-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sequence-flags-reserved-2-31 flags))))))

(defbinstruct/me xsar-sound (tracks-p)
  (%start 0 :type position)
  (file-id 0 :type (unsigned-byte 32)) (player-id (make-nintendo-ware-sound-resource-id) :type nintendo-ware-sound-resource-id)
  (volume 0 :type (unsigned-byte 8)) (remote-filter 0 :type (signed-byte 8))
  (padding 0 :type (unsigned-byte 16))
  (detail-reference (make-nintendo-ware-reference) :type nintendo-ware-reference)
  (flags (make-xsar-sound-flags) :type xsar-sound-flags)
  (string-index nil :type (ecase (xsar-sound-flags-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (pan-mode-info nil :type (ecase (xsar-sound-flags-pan-mode-info-p flags)
                        ((nil) null) ((t) xsar-pan-mode-info)))
  (player-info nil :type (ecase (xsar-sound-flags-player-info-p flags)
                        ((nil) null) ((t) xsar-player-info)))
  (reserved-3-7-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sound-flags-reserved-3-7 flags)))))
  (sound-3d-offset nil :type (ecase (xsar-sound-flags-sound-3d-offset-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-9-16-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sound-flags-reserved-9-16 flags)))))
  (front-bypass nil :type (ecase (xsar-sound-flags-front-bypass-p flags)
                        ((nil) null) ((t) xsar-front-bypass-info)))
  (reserved-18-27-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sound-flags-reserved-18-27 flags)))))
  (user-parameter-3 nil :type (ecase (xsar-sound-flags-user-parameter-3-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (user-parameter-2 nil :type (ecase (xsar-sound-flags-user-parameter-2-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (user-parameter-1 nil :type (ecase (xsar-sound-flags-user-parameter-1-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (user-parameter-0 nil :type (ecase (xsar-sound-flags-user-parameter-0-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (detail nil :type (ecase (nintendo-ware-reference-type detail-reference)
                      (#x2203 (values (pointer xsar-sequence-info (map null (constantly (nintendo-ware-reference-target detail-reference %start #x2203))))))
                      (#x2202 (values (pointer xsar-wave-sound-info (map null (constantly (nintendo-ware-reference-target detail-reference %start #x2202))))))
                      (#x2201 (values (pointer (xsar-stream-sound-info tracks-p) (map null (constantly (nintendo-ware-reference-target detail-reference %start #x2201))))))))
  (sound-3d-info nil :type (ecase (and sound-3d-offset (/= sound-3d-offset #xffffffff))
                        ((nil) null) ((t) (values (pointer xsar-sound-3d-info (map null (constantly (+ %start sound-3d-offset)))))))))

(defbinstruct/me xsar-wave-sound-group ()
  ($xsar-wave-sound-group-start 0 :type position)
  (wave-archives nil :type (or nintendo-ware-null-reference
                               (values (pointer (map xsar-resource-ids
                                                     (the (function (t) (or null (simple-array nintendo-ware-sound-resource-id (*)))) #'identity))
                                                (nintendo-ware-reference-offset-value #x0100)
                                                $xsar-wave-sound-group-start))))
  (flags (make-xsar-wave-sound-group-flags) :type xsar-wave-sound-group-flags)
  (reserved-0-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-wave-sound-group-flags-reserved-0-31 flags))))))

(defbinstruct/me xsar-sound-group ()
  ($xsar-sound-group-start 0 :type position)
  (first-id (make-nintendo-ware-sound-resource-id) :type nintendo-ware-sound-resource-id) (last-id (make-nintendo-ware-sound-resource-id) :type nintendo-ware-sound-resource-id)
  (files nil :type (or nintendo-ware-null-reference
                       (values (pointer (map xsar-sound-group-files
                                             (the (function (t) (or null (simple-array (unsigned-byte 32) (*)))) #'identity))
                                        (nintendo-ware-reference-offset-value #x0100)
                                        $xsar-sound-group-start))))
  (wave-group nil :type (or nintendo-ware-null-reference
                            (values (pointer (map xsar-wave-sound-group
                                                  (the (function (t) (or null xsar-wave-sound-group)) #'identity))
                                             (nintendo-ware-reference-offset-value #x2205)
                                             $xsar-sound-group-start))))
  (flags (make-xsar-sound-group-flags) :type xsar-sound-group-flags)
  (string-index nil :type (ecase (xsar-sound-group-flags-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-1-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-sound-group-flags-reserved-1-31 flags))))))

(defbinstruct/me xsar-bank ()
  ($xbnk-start 0 :type position)
  (file-id 0 :type (unsigned-byte 32))
  (wave-archives nil :type (or nintendo-ware-null-reference
                               (values (pointer (map xsar-resource-ids
                                                     (the (function (t) (or null (simple-array nintendo-ware-sound-resource-id (*)))) #'identity))
                                                (nintendo-ware-reference-offset-value #x0100)
                                                $xbnk-start))))
  (flags (make-xsar-bank-flags) :type xsar-bank-flags)
  (string-index nil :type (ecase (xsar-bank-flags-string-index-p flags)
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-1-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-bank-flags-reserved-1-31 flags))))))

(defbinstruct/me xsar-external-file ()
  (text #.(coerce "" 'simple-base-string) :type simple-base-string))

(defbinstruct/me xsar-internal-file ()
  (reference (make-nintendo-ware-sized-reference)
             :type (satisfies nintendo-ware-sized-reference
                              (lambda (reference)
                                (member (nintendo-ware-sized-reference-type reference) '(0 #x1f00)))))
  (data nil :type (ecase (= (nintendo-ware-sized-reference-offset reference) -1)
                   ((t) null)
                   ((nil) (values (pointer (simple-array (unsigned-byte 8) ((nintendo-ware-sized-reference-size reference))) (map null (constantly (nintendo-ware-sized-reference-target reference 0))) $xsar-data-start))))))

(defbinstruct/me xsar-file ()
  (%start 0 :type position)
  (location-reference (make-nintendo-ware-reference) :type nintendo-ware-reference)
  (flags (make-xsar-file-flags) :type xsar-file-flags)
  (reserved-0-31-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32) ((logcount (xsar-file-flags-reserved-0-31 flags)))))
  (location nil :type (ecase (= (nintendo-ware-reference-offset location-reference) -1)
                        ((t) null)
                        ((nil) (ecase (nintendo-ware-reference-type location-reference)
                                 (#x220c (values (pointer xsar-internal-file (map null (constantly (nintendo-ware-reference-target location-reference %start #x220c))))))
                                 (#x220d (values (pointer xsar-external-file (map null (constantly (nintendo-ware-reference-target location-reference %start #x220d)))))))))))

(defbinstruct/me (xsar-info-sounds (:type (simple-array (or null xsar-sound) (*)))
                  (:constructor progn) (:conc-name nil)) (tracks-p)
  ($xsar-info-sounds-start 0 :type position)
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array
                     (or nintendo-ware-null-reference
                         (values (pointer (map (xsar-sound tracks-p)
                                               (the (function (t) (or null xsar-sound)) #'identity))
                                          (nintendo-ware-reference-offset-value #x2200)
                                          $xsar-info-sounds-start))) (%count))))

(defbinstruct/me (xsar-info-sound-groups (:type (simple-array (or null xsar-sound-group) (*)))
                  (:constructor progn) (:conc-name nil)) ()
  ($xsar-info-sound-groups-start 0 :type position)
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array
                     (or nintendo-ware-null-reference
                         (values (pointer (map xsar-sound-group
                                               (the (function (t) (or null xsar-sound-group)) #'identity))
                                          (nintendo-ware-reference-offset-value #x2204)
                                          $xsar-info-sound-groups-start))) (%count))))

(defbinstruct/me (xsar-info-banks (:type (simple-array (or null xsar-bank) (*)))
                  (:constructor progn) (:conc-name nil)) ()
  ($xsar-info-banks-start 0 :type position)
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array
                     (or nintendo-ware-null-reference
                         (values (pointer (map xsar-bank
                                               (the (function (t) (or null xsar-bank)) #'identity))
                                          (nintendo-ware-reference-offset-value #x2206)
                                          $xsar-info-banks-start))) (%count))))

(defbinstruct/me (xsar-info-wave-archives (:type (simple-array (or null xsar-wave-archive) (*)))
                  (:constructor progn) (:conc-name nil)) ()
  ($xsar-info-wave-archives-start 0 :type position)
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array
                     (or nintendo-ware-null-reference
                         (values (pointer (map xsar-wave-archive
                                               (the (function (t) (or null xsar-wave-archive)) #'identity))
                                          (nintendo-ware-reference-offset-value #x2207)
                                          $xsar-info-wave-archives-start))) (%count))))

(defbinstruct/me (xsar-info-groups (:type (simple-array (or null xsar-group) (*)))
                  (:constructor progn) (:conc-name nil)) ()
  ($xsar-info-groups-start 0 :type position)
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array
                     (or nintendo-ware-null-reference
                         (values (pointer (map xsar-group
                                               (the (function (t) (or null xsar-group)) #'identity))
                                          (nintendo-ware-reference-offset-value #x2208)
                                          $xsar-info-groups-start))) (%count))))

(defbinstruct/me (xsar-info-players (:type (simple-array (or null xsar-player) (*)))
                  (:constructor progn) (:conc-name nil)) ()
  ($xsar-info-players-start 0 :type position)
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array
                     (or nintendo-ware-null-reference
                         (values (pointer (map xsar-player
                                               (the (function (t) (or null xsar-player)) #'identity))
                                          (nintendo-ware-reference-offset-value #x2209)
                                          $xsar-info-players-start))) (%count))))

(defbinstruct/me (xsar-info-files (:type (simple-array (or null xsar-file) (*)))
                  (:constructor progn) (:conc-name nil)) ()
  ($xsar-info-files-start 0 :type position)
  (%count 0 :type (unsigned-byte 32))
  (values #() :type (simple-array
                     (or nintendo-ware-null-reference
                         (values (pointer (map xsar-file
                                               (the (function (t) (or null xsar-file)) #'identity))
                                          (nintendo-ware-reference-offset-value #x220a)
                                          $xsar-info-files-start))) (%count))))

(define-nintendo-ware-section (xsar-info (:magic "INFO"))
  (nil nil :type (values (pointer xsar-data-position (map null (constantly (if (block-reference %header #x2002 nil) (+ 8 (block-start %header #x2002)) 8))))))
  ($info-start 0 :type position)
  (sounds nil :type
          (or nintendo-ware-null-reference
              (values
               (pointer
                (map (xsar-info-sounds
                      (if (string= (nintendo-ware-file-header-magic %header) "CSAR")
                          (cond ((>= (nintendo-ware-file-header-version %header) #x02030200) 2)
                                ((>= (nintendo-ware-file-header-version %header) #x02030000) 1)
                                (t 0))
                          0))
                     (the (function (t) (or null (simple-array (or null xsar-sound) (*)))) #'identity))
                (nintendo-ware-reference-offset-value #x2100)
                $info-start))))
  (sound-groups nil :type (or nintendo-ware-null-reference
                              (values (pointer (map xsar-info-sound-groups
                                                    (the (function (t) (or null (simple-array (or null xsar-sound-group) (*)))) #'identity))
                                               (nintendo-ware-reference-offset-value #x2104)
                                               $info-start))))
  (banks nil :type (or nintendo-ware-null-reference
                       (values (pointer (map xsar-info-banks
                                             (the (function (t) (or null (simple-array (or null xsar-bank) (*)))) #'identity))
                                        (nintendo-ware-reference-offset-value #x2101)
                                        $info-start))))
  (wave-archives nil :type (or nintendo-ware-null-reference
                               (values (pointer (map xsar-info-wave-archives
                                                     (the (function (t) (or null (simple-array (or null xsar-wave-archive) (*)))) #'identity))
                                                (nintendo-ware-reference-offset-value #x2103)
                                                $info-start))))
  (groups nil :type (or nintendo-ware-null-reference
                        (values (pointer (map xsar-info-groups
                                              (the (function (t) (or null (simple-array (or null xsar-group) (*)))) #'identity))
                                         (nintendo-ware-reference-offset-value #x2105)
                                         $info-start))))
  (players nil :type (or nintendo-ware-null-reference
                         (values (pointer (map xsar-info-players
                                               (the (function (t) (or null (simple-array (or null xsar-player) (*)))) #'identity))
                                          (nintendo-ware-reference-offset-value #x2102)
                                          $info-start))))
  (files nil :type (or nintendo-ware-null-reference
                       (values (pointer (map xsar-info-files
                                             (the (function (t) (or null (simple-array (or null xsar-file) (*)))) #'identity))
                                        (nintendo-ware-reference-offset-value #x2106)
                                        $info-start))))
  (project-info nil :type (or nintendo-ware-null-reference
                              (values (pointer (map xsar-project-info
                                                    (the (function (t) (or null xsar-project-info)) #'identity))
                                               (nintendo-ware-reference-offset-value #x220b)
                                               $info-start)))))

(define-nintendo-ware-file (xsar (:magic ("CSAR" "FSAR")))
  (strg nil :type (ecase (not (null (block-reference %header #x2000 nil))) ((nil) null) ((t) (values (pointer xsar-strg (map null (constantly (block-start %header #x2000))))))))
  (info nil :type (values (pointer xsar-info (map null (constantly (block-start %header #x2001))))))
  (file nil :type (ecase (not (null (block-reference %header #x2002 nil)))
                     ((nil) null)
                     ((t) (values (pointer (nintendo-ware-section-raw-block "FILE") (map null (constantly (block-start %header #x2002)))))))))

(defun xsar-files (xsar)
  "Return a simple vector of (NAME . DATA) conses indexed by file ID.
DATA is an octet vector for internal files and NIL for absent/external files.
Names come from resource metadata; later named aliases overwrite earlier ones,
as in cl-nitro: sounds, banks, wave archives, then groups. No files are parsed."
  (let* ((info (xsar-info xsar))
         (files (map 'simple-vector
                     (lambda (entry)
                       (cons nil
                             (when entry
                               (let ((location (xsar-file-location entry)))
                                 (when (typep location 'xsar-internal-file)
                                   (xsar-internal-file-data location))))))
                     (xsar-info-files info)))
         (strg (xsar-strg xsar))
         (strings (when strg (xsar-strg-strings strg))))
    (when strings
      (flet ((fill-names (entries file-id string-index)
               (when entries
                 (loop for entry across entries when entry do
                   (let ((index (funcall string-index entry)))
                     (when index
                       (setf (car (aref files (funcall file-id entry)))
                             (xsar-string-text (aref strings index)))))))))
        (fill-names (xsar-info-sounds info)
                    #'xsar-sound-file-id #'xsar-sound-string-index)
        (fill-names (xsar-info-banks info)
                    #'xsar-bank-file-id #'xsar-bank-string-index)
        (fill-names (xsar-info-wave-archives info)
                    #'xsar-wave-archive-file-id #'xsar-wave-archive-string-index)
        (fill-names (xsar-info-groups info)
                    #'xsar-group-file-id #'xsar-group-string-index)))
    files))

(setf (fdefinition 'xsar-file-name) (fdefinition 'car)
      (fdefinition 'xsar-file-data) (fdefinition 'cdr))

(defbinio xsar stream)

(defmethod read-file ((type (eql 'xsar)) (stream stream))
  (read-xsar stream))
