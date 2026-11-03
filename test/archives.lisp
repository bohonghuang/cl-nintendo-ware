(in-package #:cl-nintendo-ware.test)

(defun layout-fixture (specifications)
  (let ((positions (make-hash-table)) (position 0) (planning-p t))
    (labels ((address (name)
               (if planning-p 0 (or (gethash name positions) (error "Unknown fixture label ~S" name))))
             (emit (specification)
               (destructuring-bind (name type constructor &rest arguments) specification
                 (declare (ignore name))
                 (apply #'encode-record type (funcall constructor #'address) arguments))))
      (dolist (specification specifications)
        (setf (gethash (first specification) positions) position)
        (incf position (length (emit specification))))
      (setf planning-p nil)
      (apply #'octets-join (mapcar #'emit specifications)))))

(defun fixture-reference (address type target base)
  (cl-nintendo-ware.test::make-reference :type type :offset (- (funcall address target) (funcall address base))))

(defun flags (mask &rest values)
  (cl-nintendo-ware.test::make-flag-values :mask mask
                          :values (make-array (length values) :element-type '(unsigned-byte 32) :initial-contents values)))

(defun wave-sound-data-fixture ()
  (let ((body
          (layout-fixture
           (list
            (list 'info 'cl-nintendo-ware.test::reference-pair
                  (lambda (address)
                    (cl-nintendo-ware.test::make-reference-pair
                     :first (fixture-reference address #x0100 'waves 'info)
                     :second (fixture-reference address #x0101 'items 'info))))
            (list 'waves 'cl-nintendo-ware.test::wave-id-table
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-wave-id-table :count 1 :entries (vector (cl-nintendo-ware.test::make-wave-id :archive-id #x05000002 :index 9)))))
            (list 'items 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x4900 'item 'items)))))
            (list 'item 'cl-nintendo-ware.test::reference-triple
                  (lambda (address)
                    (cl-nintendo-ware.test::make-reference-triple
                     :first (fixture-reference address #x4901 'parameters 'item)
                     :second (fixture-reference address #x0101 'tracks 'item)
                     :third (fixture-reference address #x0101 'notes 'item))))
            (list 'parameters 'cl-nintendo-ware.test::flag-values
                  (lambda (address) (declare (ignore address)) (flags 7 #x2040 #x3fc00000 #x030201)))
            (list 'tracks 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x4903 'track 'tracks)))))
            (list 'track 'cl-nintendo-ware.test::reference (lambda (address) (fixture-reference address 0 'events 'track)))
            (list 'events 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x4904 'event 'events)))))
            (list 'event 'cl-nintendo-ware.test::wave-sound-data-event
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-wave-sound-data-event :position 0.5f0 :length 2.0f0 :note-index 0)))
            (list 'notes 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x4902 'note 'notes)))))
            (list 'note 'cl-nintendo-ware.test::wave-sound-data-note-record
                  (lambda (address)
                    (cl-nintendo-ware.test::make-wave-sound-data-note-record :wave-index 0
                     :flags (flags #x20f 64 127 #x3048 #x3f400000 (- (funcall address 'envelope-reference) (funcall address 'note))))))
            (list 'envelope-reference 'cl-nintendo-ware.test::reference
                  (lambda (address) (fixture-reference address 0 'envelope 'envelope-reference)))
            (list 'envelope 'cl-nintendo-ware.test::wave-sound-data-envelope
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-wave-sound-data-envelope :attack 11 :decay 22 :sustain 33 :hold 44 :release 55)))))))
    (container-fixture "CWSD" (list (list #x6800 "INFO" body)))))

(defun sound-group-fixture (embedded)
  (let ((info
          (layout-fixture
           (list
            (list 'table 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x7900 'entry 'table)))))
            (list 'entry 'cl-nintendo-ware.test::sound-group-file-record
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-sound-group-file-record :file-id 7
                     :file-reference (cl-nintendo-ware.test::make-sized-reference :type #x1f00 :offset 0 :size (length embedded))))))))
        (extra
          (layout-fixture
           (list
            (list 'table 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x7901 'entry 'table)))))
            (list 'entry 'cl-nintendo-ware.test::sound-group-dependency
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-sound-group-dependency :resource-id #x03000000 :load-flags 3)))))))
    (container-fixture "CGRP"
                       (list (list #x7800 "INFO" info) (list #x7801 "FILE" embedded) (list #x7802 "INFX" extra)))))

(defun sound-archive-fixture (embedded)
  (let ((strings
          (layout-fixture
           (list
            (list 'info 'cl-nintendo-ware.test::reference-pair
                  (lambda (address)
                    (cl-nintendo-ware.test::make-reference-pair :first (fixture-reference address #x2400 'table 'info)
                                                 :second (fixture-reference address #x2401 'tree 'info))))
            (list 'table 'cl-nintendo-ware.test::sized-reference-table
                  (lambda (address)
                    (cl-nintendo-ware.test::make-sized-reference-table :count 1
                     :entries (vector (cl-nintendo-ware.test::make-sized-reference :type #x1f01
                                       :offset (- (funcall address 'name) (funcall address 'table)) :size 5)))))
            (list 'name 'cl-nintendo-ware.test::fixed-text
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-fixed-text :text (coerce (concatenate 'string "song" (string #\Null)) 'simple-base-string))) 5)
            (list 'padding 'cl-nintendo-ware.test::byte-payload
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-byte-payload :bytes (make-array 3 :element-type '(unsigned-byte 8) :initial-element 0))) 3)
            (list 'tree 'cl-nintendo-ware.test::sound-archive-patricia-tree
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-sound-archive-patricia-tree :root-index 0 :count 1
                     :nodes (vector (cl-nintendo-ware.test::make-sound-archive-patricia-node :leaf-flag 1 :string-index 0 :resource-id #x01000000))))))))
        (info
          (layout-fixture
           (list
            (list 'info 'cl-nintendo-ware.test::sound-archive-info-references
                  (lambda (address)
                    (cl-nintendo-ware.test::make-sound-archive-info-references
                     :sounds (fixture-reference address #x2100 'sounds 'info)
                     :banks (fixture-reference address #x2101 'banks 'info)
                     :players (fixture-reference address #x2102 'players 'info)
                     :files (fixture-reference address #x2106 'files 'info))))
            (list 'sounds 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x2200 'sound 'sounds)))))
            (list 'banks 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x2206 'bank 'banks)))))
            (list 'players 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x2209 'player 'players)))))
            (list 'files 'cl-nintendo-ware.test::reference-table
                  (lambda (address)
                    (cl-nintendo-ware.test::make-reference-table :count 2
                     :entries (vector (fixture-reference address #x220a 'internal 'files)
                                      (fixture-reference address #x220a 'external 'files)))))
            (list 'sound 'cl-nintendo-ware.test::sound-archive-sound-record
                  (lambda (address)
                    (cl-nintendo-ware.test::make-sound-archive-sound-record :file-id 0 :player-id #x04000000 :volume 100
                     :detail-reference (fixture-reference address #x2203 'sequence 'sound) :flags (flags 1 0))))
            (list 'sequence 'cl-nintendo-ware.test::sound-archive-sequence-record
                  (lambda (address)
                    (cl-nintendo-ware.test::make-sound-archive-sequence-record :banks-reference (fixture-reference address #x0100 'bank-ids 'sequence)
                     :allocate-track-flags 3 :flags (flags 3 4 #x0150))))
            (list 'bank-ids 'cl-nintendo-ware.test::integer-table
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-integer-table :count 1 :entries (make-array 1 :element-type '(unsigned-byte 32) :initial-element #x03000000))))
            (list 'bank 'cl-nintendo-ware.test::sound-archive-bank-record
                  (lambda (address) (cl-nintendo-ware.test::make-sound-archive-bank-record :file-id 1
                                     :wave-archives-reference (fixture-reference address #x0100 'wave-ids 'bank) :flags (flags 0))))
            (list 'wave-ids 'cl-nintendo-ware.test::integer-table
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-integer-table :count 1 :entries (make-array 1 :element-type '(unsigned-byte 32) :initial-element #x05000002))))
            (list 'player 'cl-nintendo-ware.test::sound-archive-player-record
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-sound-archive-player-record :sound-limit 4 :flags (flags 0))))
            (list 'internal 'cl-nintendo-ware.test::sound-archive-file-record
                  (lambda (address) (cl-nintendo-ware.test::make-sound-archive-file-record
                                     :location-reference (fixture-reference address #x220c 'file-data 'internal) :flags (flags 0))))
            (list 'file-data 'cl-nintendo-ware.test::sized-reference
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-sized-reference :type #x1f00 :offset 0 :size (length embedded))))
            (list 'external 'cl-nintendo-ware.test::sound-archive-file-record
                  (lambda (address) (cl-nintendo-ware.test::make-sound-archive-file-record
                                     :location-reference (fixture-reference address #x220d 'path 'external) :flags (flags 0))))
            (list 'path 'cl-nintendo-ware.test::terminated-text
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-terminated-text :text #.(coerce "audio/example.bcstm" 'simple-base-string))))))))
    (container-fixture "CSAR"
                       (list (list #x2000 "STRG" strings) (list #x2001 "INFO" info) (list #x2002 "FILE" embedded)))))

(defun sound-stream-fixture (&optional (major-version 2))
  (let* ((codec-info (cl-nintendo-ware.test::make-dsp-adpcm-info
                      :coefficients (make-array 16 :element-type '(signed-byte 16) :initial-element 123)
                      :initial-context (cl-nintendo-ware.test::make-dsp-adpcm-context :history-1 -111)
                      :loop-context (cl-nintendo-ware.test::make-dsp-adpcm-context :history-2 -222)))
         (extensions
           (octets-join
            (if (>= major-version 3)
                (encode-record 'cl-nintendo-ware.test::sound-stream-region-info
                               (cl-nintendo-ware.test::make-sound-stream-region-info :entry-size 20
                                :data-reference (cl-nintendo-ware.test::make-reference :type #x1f00 :offset 0))) #())
            (if (>= major-version 4)
                (encode-record 'cl-nintendo-ware.test::sound-stream-original-loop-info
                               (cl-nintendo-ware.test::make-sound-stream-original-loop-info :start 1 :end 28)) #())
            (if (>= major-version 6)
                (encode-record 'cl-nintendo-ware.test::sound-stream-secret-info (cl-nintendo-ware.test::make-sound-stream-secret-info :value 42)) #())))
         (info
           (layout-fixture
            (list
             (list 'info 'cl-nintendo-ware.test::reference-triple
                   (lambda (address)
                     (cl-nintendo-ware.test::make-reference-triple :first (fixture-reference address #x4100 'stream 'info)
                      :second (fixture-reference address #x0101 'tracks 'info)
                      :third (fixture-reference address #x0101 'channels 'info))))
             (list 'stream 'cl-nintendo-ware.test::sound-stream-stream-info
                   (lambda (address) (declare (ignore address))
                     (cl-nintendo-ware.test::make-sound-stream-stream-info :encoding 2 :loop-flag 1 :channel-count 2 :sample-rate 32000
                      :region-count (if (>= major-version 3) 1 0)
                      :loop-start 0 :sample-count 28 :block-count 2 :block-size 8 :block-sample-count 14
                      :last-block-size 8 :last-block-sample-count 14 :last-block-padded-size 8
                      :seek-entry-size 4 :seek-interval-samples 14 :sample-data-reference (cl-nintendo-ware.test::make-reference :type #x1f00 :offset 0))))
             (list 'extensions 'cl-nintendo-ware.test::byte-payload
                   (lambda (address) (declare (ignore address))
                     (cl-nintendo-ware.test::make-byte-payload :bytes extensions)) (length extensions))
             (list 'tracks 'cl-nintendo-ware.test::reference-table
                   (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x4101 'track 'tracks)))))
             (list 'channels 'cl-nintendo-ware.test::reference-table
                   (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 2
                                      :entries (vector (fixture-reference address #x4102 'channel-1 'channels)
                                                       (fixture-reference address #x4102 'channel-2 'channels)))))
             (list 'track 'cl-nintendo-ware.test::sound-stream-track-record
                   (lambda (address) (cl-nintendo-ware.test::make-sound-stream-track-record :volume 100 :pan 64
                                      :channels-reference (fixture-reference address #x0100 'indices 'track))))
             (list 'indices 'cl-nintendo-ware.test::stream-byte-table
                   (lambda (address) (declare (ignore address))
                     (cl-nintendo-ware.test::make-stream-byte-table :count 2 :entries (make-array 2 :element-type '(unsigned-byte 8) :initial-contents '(0 1)))))
             (list 'channel-1 'cl-nintendo-ware.test::reference (lambda (address) (fixture-reference address #x0300 'codec-1 'channel-1)))
             (list 'channel-2 'cl-nintendo-ware.test::reference (lambda (address) (fixture-reference address #x0300 'codec-2 'channel-2)))
             (list 'codec-1 'cl-nintendo-ware.test::dsp-adpcm-info (lambda (address) (declare (ignore address)) codec-info))
             (list 'codec-2 'cl-nintendo-ware.test::dsp-adpcm-info (lambda (address) (declare (ignore address)) codec-info)))))
         (seek (let ((*fixture-endian* (if (eq *fixture-family* :c) :little :big)))
                 (apply #'octets-join
                      (loop :for value :from 1 :to 4
                            :collect (encode-record 'cl-nintendo-ware.test::sound-stream-dsp-seek-context
                                      (cl-nintendo-ware.test::make-sound-stream-dsp-seek-context :history-1 (- value) :history-2 (* value 100)))))))
         (payload (apply #'octets-join (loop :for value :from 1 :to 4 :collect (make-array 8 :initial-element value)))))
    (container-fixture "CSTM"
                       (append (list (list #x4000 "INFO" info) (list #x4001 "SEEK" seek) (list #x4002 "DATA" payload))
                               (when (>= major-version 3)
                                 (list (list #x4003 "REGN"
                                             (encode-record 'cl-nintendo-ware.test::sound-stream-region-record
                                              (cl-nintendo-ware.test::make-sound-stream-region-record :start 1 :end 20
                                               :contexts (vector (cl-nintendo-ware.test::make-dsp-adpcm-context :history-1 -321)
                                                                 (cl-nintendo-ware.test::make-dsp-adpcm-context :history-2 456))) 2)))))
                       :version (* major-version #x1000000))))

(defun run-archive-tests ()
  (let* ((sound (nintendo-ware:read-file :wave-sound-data (wave-sound-data-fixture)))
         (information (nintendo-ware:wave-sound-data-info sound))
         (item (aref (nintendo-ware:wave-sound-data-item-table-entries (nintendo-ware:wave-sound-data-info-items information)) 0))
         (parameters (nintendo-ware:wave-sound-data-item-parameters item))
         (pan (nintendo-ware:wave-sound-data-parameters-pan-info parameters))
         (filter (nintendo-ware:wave-sound-data-parameters-filter-info parameters))
         (track (aref (nintendo-ware:wave-sound-data-track-table-entries (nintendo-ware:wave-sound-data-item-tracks item)) 0))
         (event (aref (nintendo-ware:wave-sound-data-event-table-entries (nintendo-ware:wave-sound-data-track-events track)) 0))
         (note (aref (nintendo-ware:wave-sound-data-note-table-entries (nintendo-ware:wave-sound-data-item-notes item)) (nintendo-ware:wave-sound-data-event-note-index event))))
    (assert (= 9 (nintendo-ware:wave-id-index (aref (nintendo-ware:wave-id-table-entries (nintendo-ware:wave-sound-data-info-waves information)) 0))))
    (assert (= 0.5f0 (nintendo-ware:wave-sound-data-event-position event)))
    (assert (= 2.0f0 (nintendo-ware:wave-sound-data-event-length event)))
    (assert (= 64 (nintendo-ware::packed-pan-pan pan)))
    (assert (= 32 (nintendo-ware::packed-pan-surround-pan pan)))
    (assert (= 1.5f0 (nintendo-ware:wave-sound-data-parameters-pitch parameters)))
    (assert (= 1 (nintendo-ware::packed-filter-low-pass filter)))
    (assert (= 2 (nintendo-ware::packed-filter-biquad-type filter)))
    (assert (= 3 (nintendo-ware::packed-filter-biquad-value filter)))
    (assert (= 0 (nintendo-ware:wave-sound-data-note-wave-index note)))
    (assert (= 0.75f0 (nintendo-ware:wave-sound-data-parameters-pitch (nintendo-ware:wave-sound-data-note-parameters note))))
    (assert (= 55 (nintendo-ware:wave-sound-data-envelope-release (nintendo-ware:wave-sound-data-parameters-envelope (nintendo-ware:wave-sound-data-note-parameters note))))))
  (let* ((embedded (sequence-fixture #(#xff)))
         (group (nintendo-ware:read-file :sound-group (sound-group-fixture embedded)))
         (archive (nintendo-ware:read-file :sound-archive (sound-archive-fixture embedded)))
         (information (nintendo-ware:sound-archive-info archive))
         (strings (nintendo-ware:sound-archive-strg-strings (nintendo-ware:sound-archive-strg archive)))
         (sound (aref (nintendo-ware:sound-archive-sounds-table-entries (nintendo-ware:sound-archive-info-sounds information)) 0))
         (sequence (nintendo-ware:sound-archive-sound-detail sound))
         (priority (nintendo-ware:sound-archive-sequence-info-priority sequence))
         (file (aref (nintendo-ware:sound-archive-files-table-entries (nintendo-ware:sound-archive-info-files information)) 0))
         (external (aref (nintendo-ware:sound-archive-files-table-entries (nintendo-ware:sound-archive-info-files information)) 1)))
    (assert (= 7 (nintendo-ware:sound-group-entry-file-id (aref (nintendo-ware:sound-group-info-entries (nintendo-ware:sound-group-info group)) 0))))
    (assert (typep (nintendo-ware:sound-group-entry-content (aref (nintendo-ware:sound-group-info-entries (nintendo-ware:sound-group-info group)) 0)) 'nintendo-ware:sound-sequence))
    (assert (= #x03000000 (nintendo-ware:sound-group-dependency-resource-id (aref (nintendo-ware:sound-group-infx-entries (nintendo-ware:sound-group-infx group)) 0))))
    (assert (string= "song" (nintendo-ware:sound-archive-string-text (aref (nintendo-ware:sound-archive-string-table-entries strings) 0))))
    (assert (= #x01000000 (nintendo-ware:sound-archive-patricia-node-resource-id (aref (nintendo-ware:sound-archive-patricia-tree-nodes (nintendo-ware:sound-archive-strg-tree (nintendo-ware:sound-archive-strg archive))) 0))))
    (assert (= 4 (nintendo-ware:sound-archive-sequence-info-start-offset sequence)))
    (assert (= 80 (nintendo-ware::packed-priority-channel-priority priority)))
    (assert (= 1 (nintendo-ware::packed-priority-release-priority priority)))
    (assert (= #x03000000 (aref (nintendo-ware:integer-table-entries (nintendo-ware:sound-archive-sequence-info-banks sequence)) 0)))
    (assert (= #x05000002 (aref (nintendo-ware:integer-table-entries (nintendo-ware:sound-archive-bank-wave-archives (aref (nintendo-ware:sound-archive-banks-table-entries (nintendo-ware:sound-archive-info-banks information)) 0))) 0)))
    (assert (= 4 (nintendo-ware:sound-archive-player-sound-limit (aref (nintendo-ware:sound-archive-players-table-entries (nintendo-ware:sound-archive-info-players information)) 0))))
    (assert (typep (nintendo-ware:sound-archive-internal-file-content (nintendo-ware:sound-archive-file-location file)) 'nintendo-ware:sound-sequence))
    (assert (string= "audio/example.bcstm" (nintendo-ware:sound-archive-external-file-text (nintendo-ware:sound-archive-file-location external)))))
  (dolist (major '(2 3 4 6))
    (let* ((stream (nintendo-ware:read-file :sound-stream (sound-stream-fixture major)))
           (information (nintendo-ware:sound-stream-info stream))
           (metadata (nintendo-ware:sound-stream-info-stream information))
           (seek (nintendo-ware:sound-stream-seek-entry-context (aref (nintendo-ware:sound-stream-seek-row-entries (aref (nintendo-ware:sound-stream-seek-rows (nintendo-ware:sound-stream-seek stream)) 1)) 1)))
           (channel (aref (nintendo-ware:sound-stream-channel-table-entries (nintendo-ware:sound-stream-info-channels information)) 1))
           (track (aref (nintendo-ware:sound-stream-track-table-entries (nintendo-ware:sound-stream-info-tracks information)) 0)))
      (assert (equalp #(0 1) (nintendo-ware:byte-table-entries (nintendo-ware:sound-stream-track-channels track))))
      (assert (= -4 (nintendo-ware:sound-stream-dsp-seek-context-history-1 seek)))
      (assert (= 400 (nintendo-ware:sound-stream-dsp-seek-context-history-2 seek)))
      (assert (equalp #(4 4 4 4 4 4 4 4) (subseq (nintendo-ware:raw-block-bytes (nintendo-ware:sound-stream-data stream)) 24 32)))
      (assert (= -222 (nintendo-ware:dsp-adpcm-context-history-2 (nintendo-ware:dsp-adpcm-info-loop-context (nintendo-ware:sound-stream-channel-codec-info channel)))))
      (when (>= major 3)
        (let ((region (aref (nintendo-ware:sound-stream-regions-entries (nintendo-ware:sound-stream-regions stream)) 0)))
          (assert (= 1 (nintendo-ware:sound-stream-region-start region)))
          (assert (= 20 (nintendo-ware:sound-stream-region-end region)))
          (assert (= -321 (nintendo-ware:dsp-adpcm-context-history-1 (aref (nintendo-ware:sound-stream-region-contexts region) 0))))))
      (when (>= major 4) (assert (= 28 (nintendo-ware:sound-stream-original-loop-info-end (nintendo-ware:sound-stream-stream-info-original-loop-info metadata)))))
      (when (>= major 6) (assert (= 42 (nintendo-ware:sound-stream-secret-info-value (nintendo-ware:sound-stream-stream-info-secret-info metadata)))))))
  (format t "Direct SAR/GRP/WSD/STM graph scenarios passed.~%"))
