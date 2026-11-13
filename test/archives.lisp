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
  (cl-nintendo-ware.test::make-fixture-parameter-words :mask mask
                          :values (make-array (length values) :element-type '(unsigned-byte 32) :initial-contents values)))

(defun xwsd-fixture (&key item-flags note-flags (events :single))
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
            (list 'parameters 'cl-nintendo-ware.test::fixture-parameter-words
                  (lambda (address)
                    (or item-flags
                        (flags #x307 #x2040 #x3fc00000 #x030201
                               (- (funcall address 'item-sends) (funcall address 'parameters))
                               (- (funcall address 'item-envelope-reference) (funcall address 'parameters))))))
            (list 'item-sends 'cl-nintendo-ware.test::xwsd-send-values
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-xwsd-send-values
                     :main-send 93 :count 2
                     :auxiliary-sends (make-array 2 :element-type '(unsigned-byte 8) :initial-contents '(17 29)))))
            (list 'item-envelope-reference 'cl-nintendo-ware.test::reference
                  (lambda (address) (fixture-reference address 0 'item-envelope 'item-envelope-reference)))
            (list 'item-envelope 'cl-nintendo-ware.test::xwsd-envelope
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-xwsd-envelope :attack 6 :decay 7 :sustain 8 :hold 9 :release 10)))
            (list 'item-padding 'cl-nintendo-ware.test::byte-payload
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-byte-payload :bytes (make-array 3 :element-type '(unsigned-byte 8) :initial-element 0))) 3)
            (list 'tracks 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x4903 'track 'tracks)))))
            (list 'track 'cl-nintendo-ware.test::reference
                  (lambda (address)
                    (if (eq events :absent)
                        (make-reference :type #xbeef :offset -1)
                        (fixture-reference address 0 'events 'track))))
            (list 'events 'cl-nintendo-ware.test::reference-table
                  (lambda (address)
                    (let ((entries
                            (ecase events
                              ((:single :absent) (vector (fixture-reference address #x4904 'event 'events)))
                              (:empty #())
                              (:sparse (vector (make-reference :type #xbeef :offset -1)
                                               (fixture-reference address #x4904 'event 'events)
                                               (make-reference :type 0 :offset -1))))))
                      (make-reference-table :count (length entries) :entries entries))))
            (list 'event 'cl-nintendo-ware.test::xwsd-event
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-xwsd-event :position 0.5f0 :length 2.0f0 :note-index 0)))
            (list 'notes 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x4902 'note 'notes)))))
            (list 'note 'cl-nintendo-ware.test::xwsd-note-record
                  (lambda (address)
                    (cl-nintendo-ware.test::make-xwsd-note-record :wave-index 0
                     :flags (or note-flags (flags #x20f 64 127 #x3048 #x3f400000 (- (funcall address 'envelope-reference) (funcall address 'note)))))))
            (list 'envelope-reference 'cl-nintendo-ware.test::reference
                  (lambda (address) (fixture-reference address 0 'envelope 'envelope-reference)))
            (list 'envelope 'cl-nintendo-ware.test::xwsd-envelope
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-xwsd-envelope :attack 11 :decay 22 :sustain 33 :hold 44 :release 55)))))))
    (container-fixture "CWSD" (list (list #x6800 "INFO" body)))))

(defun xgrp-fixture (embedded &key (file-id 7) (available-p t) (resource-id #x03000000))
  (let ((info
          (layout-fixture
           (list
            (list 'table 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x7900 'entry 'table)))))
            (list 'entry 'cl-nintendo-ware.test::xgrp-file-record
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-xgrp-file-record :file-id file-id
                     :file-reference (cl-nintendo-ware.test::make-sized-reference :type #x1f00 :offset (if available-p 0 -1) :size (length embedded))))))))
        (extra
          (layout-fixture
           (list
            (list 'table 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x7901 'entry 'table)))))
            (list 'entry 'cl-nintendo-ware.test::xgrp-dependency
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-xgrp-dependency :resource-id resource-id :load-flags 3)))))))
    (container-fixture "CGRP"
                       (list (list #x7800 "INFO" info) (list #x7801 "FILE" embedded) (list #x7802 "INFX" extra)))))

(defun xsar-fixture (embedded &key (named-p t) (available-p t) sound-flags sequence-flags)
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
            (list 'tree 'cl-nintendo-ware.test::xsar-patricia-tree
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-xsar-patricia-tree :root-index 0 :count 1
                     :nodes (vector (cl-nintendo-ware.test::make-xsar-patricia-node :leaf-flag 1 :string-index 0 :resource-id #x01000000))))))))
        (info
          (layout-fixture
           (list
            (list 'info 'cl-nintendo-ware.test::xsar-info-references
                  (lambda (address)
                    (cl-nintendo-ware.test::make-xsar-info-references
                     :sounds (fixture-reference address #x2100 'sounds 'info)
                     :banks (fixture-reference address #x2101 'banks 'info)
                     :players (fixture-reference address #x2102 'players 'info)
                     :files (fixture-reference address #x2106 'files 'info)
                     :project-info (fixture-reference address #x220b 'project 'info))))
            (list 'sounds 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x2200 'sound 'sounds)))))
            (list 'banks 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x2206 'xbnk 'banks)))))
            (list 'players 'cl-nintendo-ware.test::reference-table
                  (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x2209 'player 'players)))))
            (list 'files 'cl-nintendo-ware.test::reference-table
                  (lambda (address)
                    (cl-nintendo-ware.test::make-reference-table :count 2
                     :entries (vector (fixture-reference address #x220a 'internal 'files)
                                      (fixture-reference address #x220a 'external 'files)))))
            (list 'sound 'cl-nintendo-ware.test::xsar-sound-record
                  (lambda (address)
                    (cl-nintendo-ware.test::make-xsar-sound-record :file-id 0 :player-id #x04000000 :volume 100
                     :detail-reference (fixture-reference address #x2203 'sequence 'sound) :flags (or sound-flags (flags 1 0)))))
            (list 'sequence 'cl-nintendo-ware.test::xsar-sequence-record
                  (lambda (address)
                    (cl-nintendo-ware.test::make-xsar-sequence-record :banks-reference (fixture-reference address #x0100 'xbnk-ids 'sequence)
                     :allocate-track-flags 3 :flags (or sequence-flags (flags 3 4 #x0150)))))
            (list 'xbnk-ids 'cl-nintendo-ware.test::integer-table
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-integer-table :count 1 :entries (make-array 1 :element-type '(unsigned-byte 32) :initial-element #x03000000))))
            (list 'xbnk 'cl-nintendo-ware.test::xsar-bank-record
                  (lambda (address) (cl-nintendo-ware.test::make-xsar-bank-record :file-id 1
                                     :wave-archives-reference (fixture-reference address #x0100 'wave-ids 'xbnk) :flags (flags 0))))
            (list 'wave-ids 'cl-nintendo-ware.test::integer-table
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-integer-table :count 1 :entries (make-array 1 :element-type '(unsigned-byte 32) :initial-element #x05000002))))
            (list 'project 'cl-nintendo-ware.test::xsar-project-info-record
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-xsar-project-info-record
                     :maximum-sequences 12 :maximum-sequence-tracks 24
                     :maximum-stream-sounds 3 :maximum-stream-tracks 6 :maximum-stream-channels 8
                     :maximum-wave-sounds 16 :maximum-wave-tracks 32 :stream-buffer-times 2 :options #x12345678)))
            (list 'player 'cl-nintendo-ware.test::xsar-player-record
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-xsar-player-record :sound-limit 4 :flags (flags 0))))
            (list 'internal 'cl-nintendo-ware.test::xsar-file-record
                  (lambda (address) (cl-nintendo-ware.test::make-xsar-file-record
                                     :location-reference (fixture-reference address #x220c 'file-data 'internal) :flags (flags 0))))
            (list 'file-data 'cl-nintendo-ware.test::sized-reference
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-sized-reference :type #x1f00 :offset (if available-p 0 -1) :size (length embedded))))
            (list 'external 'cl-nintendo-ware.test::xsar-file-record
                  (lambda (address) (cl-nintendo-ware.test::make-xsar-file-record
                                     :location-reference (fixture-reference address #x220d 'path 'external) :flags (flags 0))))
            (list 'path 'cl-nintendo-ware.test::terminated-text
                  (lambda (address) (declare (ignore address))
                    (cl-nintendo-ware.test::make-terminated-text :text #.(coerce "audio/example.bcstm" 'simple-base-string))))))))
    (container-fixture "CSAR"
                       (append (when named-p (list (list #x2000 "STRG" strings)))
                               (list (list #x2001 "INFO" info) (list #x2002 "FILE" embedded))))))

(defun xstm-fixture (major-version
                     &key (section-order '(#x4000 #x4001 #x4002 #x4003))
                       (encoding 2) (seek-interval 14) (sample-offset 0) (region-offset 0))
  (let* ((codec-info (cl-nintendo-ware.test::make-xwav-dsp-adpcm-info
                      :coefficients (make-array 16 :element-type '(signed-byte 16) :initial-element 123)
                      :initial-context (cl-nintendo-ware.test::make-xwav-dsp-adpcm-context :history-1 -111)
                      :loop-context (cl-nintendo-ware.test::make-xwav-dsp-adpcm-context :history-2 -222)))
         (extensions
           (octets-join
            (if (>= major-version 3)
                (encode-record 'cl-nintendo-ware.test::xstm-region-info
                               (cl-nintendo-ware.test::make-xstm-region-info :entry-size 20
                                :data-reference (cl-nintendo-ware.test::make-reference :type #x1f00 :offset region-offset))) #())
            (if (>= major-version 4)
                (encode-record 'cl-nintendo-ware.test::xstm-original-loop-info
                               (cl-nintendo-ware.test::make-xstm-original-loop-info :start 1 :end 28)) #())
            (if (>= major-version 6)
                (encode-record 'cl-nintendo-ware.test::xstm-secret-info (cl-nintendo-ware.test::make-xstm-secret-info :value 42)) #())))
         (info
           (layout-fixture
            (list
             (list 'info 'cl-nintendo-ware.test::reference-triple
                   (lambda (address)
                     (cl-nintendo-ware.test::make-reference-triple :first (fixture-reference address #x4100 'stream 'info)
                      :second (fixture-reference address #x0101 'tracks 'info)
                      :third (fixture-reference address #x0101 'channels 'info))))
             (list 'stream 'cl-nintendo-ware.test::xstm-stream-info
                   (lambda (address) (declare (ignore address))
                     (cl-nintendo-ware.test::make-xstm-stream-info :encoding encoding :loop-flag 1 :channel-count 2 :sample-rate 32000
                      :region-count (if (>= major-version 3) 1 0)
                      :loop-start 0 :sample-count 28 :block-count 2 :block-size 8 :block-sample-count 14
                      :last-block-size 8 :last-block-sample-count 14 :last-block-padded-size 8
                      :seek-entry-size 4 :seek-interval-samples seek-interval :sample-data-reference (cl-nintendo-ware.test::make-reference :type #x1f00 :offset sample-offset))))
             (list 'extensions 'cl-nintendo-ware.test::byte-payload
                   (lambda (address) (declare (ignore address))
                     (cl-nintendo-ware.test::make-byte-payload :bytes extensions)) (length extensions))
             (list 'tracks 'cl-nintendo-ware.test::reference-table
                   (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 1 :entries (vector (fixture-reference address #x4101 'track 'tracks)))))
             (list 'channels 'cl-nintendo-ware.test::reference-table
                   (lambda (address) (cl-nintendo-ware.test::make-reference-table :count 2
                                      :entries (vector (fixture-reference address #x4102 'channel-1 'channels)
                                                       (fixture-reference address #x4102 'channel-2 'channels)))))
             (list 'track 'cl-nintendo-ware.test::xstm-track-record
                   (lambda (address) (cl-nintendo-ware.test::make-xstm-track-record :volume 100 :pan 64
                                      :channels-reference (fixture-reference address #x0100 'indices 'track))))
             (list 'indices 'cl-nintendo-ware.test::stream-byte-table
                   (lambda (address) (declare (ignore address))
                     (cl-nintendo-ware.test::make-stream-byte-table :count 2 :entries (make-array 2 :element-type '(unsigned-byte 8) :initial-contents '(0 1)))))
             (list 'channel-1 'cl-nintendo-ware.test::reference (lambda (address) (fixture-reference address #x0300 'codec-1 'channel-1)))
             (list 'channel-2 'cl-nintendo-ware.test::reference (lambda (address) (fixture-reference address #x0300 'codec-2 'channel-2)))
             (list 'codec-1 'cl-nintendo-ware.test::xwav-dsp-adpcm-info (lambda (address) (declare (ignore address)) codec-info))
             (list 'codec-2 'cl-nintendo-ware.test::xwav-dsp-adpcm-info (lambda (address) (declare (ignore address)) codec-info)))))
         (seek (apply #'octets-join
                      (loop :for value :from 1 :to 4
                            :collect (encode-record 'cl-nintendo-ware.test::xstm-dsp-seek-context
                                      (cl-nintendo-ware.test::make-xstm-dsp-seek-context :history-1 (- value) :history-2 (* value 100))))))
         (payload (apply #'octets-join (loop :for value :from 1 :to 4 :collect (make-array 8 :initial-element value)))))
    (let ((sections
            (append (list (list #x4000 "INFO" info) (list #x4001 "SEEK" seek) (list #x4002 "DATA" payload))
                    (when (>= major-version 3)
                      (list (list #x4003 "REGN"
                                  (encode-record 'cl-nintendo-ware.test::xstm-region-record
                                   (cl-nintendo-ware.test::make-xstm-region-record :start 1 :end 20
                                    :contexts (vector (cl-nintendo-ware.test::make-xwav-dsp-adpcm-context :history-1 -321)
                                                      (cl-nintendo-ware.test::make-xwav-dsp-adpcm-context :history-2 456))) 2)))))))
      (container-fixture "CSTM"
                         (remove nil (mapcar (lambda (tag) (assoc tag sections)) section-order))
                         :version (* major-version #x1000000)))))

;; Each target captures its declared size before a child shadows the size anchor.
(nintendo-ware::define-nintendo-ware-reference (reference-probe-child (:sized t)) ()
  (#x7001 (nintendo-ware::nintendo-ware-reference-octets)))
(nintendo-ware::defbinstruct/me reference-probe-parent ()
  (size 0 :type nintendo-ware::nintendo-ware-reference-size)
  (%base 0 :type position)
  (value 0 :type (unsigned-byte 32))
  (child nil :type (reference-probe-child %base))
  (tail 0 :type (unsigned-byte 32)))
(nintendo-ware::define-nintendo-ware-reference (reference-probe-root (:sized t)) ()
  (#x7000 (reference-probe-parent)))
(nintendo-ware::define-nintendo-ware-section (reference-probe-info (:magic "INFO"))
  (%base 0 :type position)
  (parent nil :type (reference-probe-root %base)))
(nintendo-ware::define-nintendo-ware-file (reference-probe-file (:magic ("CREF" "FREF")))
  (info (make-reference-probe-info) :type reference-probe-info :tag #x6800))
(defbinio reference-probe-file stream)

(defbinstruct reference-probe-payload ()
  (value 0 :type (unsigned-byte 32))
  (child (make-sized-reference) :type sized-reference)
  (tail 0 :type (unsigned-byte 32)))
(defbinstruct (reference-probe-payload/be (:type reference-probe-payload) (:endian :big)) ()
  (value 0 :type fixture-u32/be)
  (child (make-sized-reference) :type sized-reference/be)
  (tail 0 :type fixture-u32/be))

(defun reference-probe-fixture ()
  (container-fixture "CREF"
    (list (list #x6800 "INFO"
            (layout-fixture
             (list
              (list 'root 'sized-reference
                    (lambda (address)
                      (make-sized-reference :type #x7000
                        :offset (- (funcall address 'parent) (funcall address 'root)) :size 23)))
              (list 'parent 'reference-probe-payload
                    (lambda (address)
                      (make-reference-probe-payload :value #x11223344 :tail #x55667788
                        :child (make-sized-reference :type #x7001
                                 :offset (- (funcall address 'child) (funcall address 'parent)) :size 3))))
              (list 'child 'byte-payload
                    (lambda (address) (declare (ignore address))
                      (make-byte-payload :bytes (make-array 3 :element-type '(unsigned-byte 8)
                                                            :initial-contents '(3 4 5)))) 3)))))))

(defun run-archive-tests ()
  (dolist (*fixture-endian* '(:little :big))
    (dolist (*fixture-family* '(:c :f))
      (let* ((file (read-reference-probe-file
                    (flexi-streams:make-in-memory-input-stream (reference-probe-fixture))))
             (parent (reference-probe-info-parent (reference-probe-file-info file))))
        (assert (= 23 (reference-probe-parent-size parent)))
        (assert (= #x11223344 (reference-probe-parent-value parent)))
        (assert (equalp #(3 4 5) (reference-probe-parent-child parent)))
        (assert (= #x55667788 (reference-probe-parent-tail parent))))))
  ;; Nullable table entries preserve indices, ignore absent tags, and resolve
  ;; each non-null target before the next array element is read.
  (flet ((group (tag offset)
           (container-fixture
            "CGRP"
            (list
             (list #x7800 "INFO"
                   (octets-join
                    (encode-record 'reference-table
                      (make-reference-table
                       :count 3
                       :entries (vector (make-reference :type 0 :offset -1)
                                        (make-reference :type tag :offset offset)
                                        (make-reference :type #xbeef :offset -1))))
                    (encode-record 'xgrp-file-record
                      (make-xgrp-file-record
                       :file-id 1234
                       :file-reference (make-sized-reference :type #x1f00 :offset -1)))))))))
    (let* ((parsed (nintendo-ware::read-file 'nintendo-ware::xgrp (group #x7900 28)))
           (entries (nintendo-ware::xgrp-info-entries (nintendo-ware::xgrp-info parsed))))
      (assert (= 3 (length entries)))
      (assert (null (aref entries 0)))
      (assert (= 1234 (nintendo-ware::xgrp-entry-file-id (aref entries 1))))
      (assert (null (nintendo-ware::xgrp-entry-data (aref entries 1))))
      (assert (null (aref entries 2))))
    (dolist (case '((#x7901 28) (#x7900 -2)))
      (destructuring-bind (tag offset) case
        (rejects binstruct::deserialize-error
          (nintendo-ware::read-file 'nintendo-ware::xgrp (group tag offset)))))
    (rejects error
      (nintendo-ware::read-file 'nintendo-ware::xgrp (group #x7900 #x10000))))
  ;; Independent u32 words distinguish signed bytes, reserved bytes and bits.
  (let* ((file (nintendo-ware::read-file 'nintendo-ware::xwsd
                 (xwsd-fixture :item-flags (flags 5 #xa55a7f80 #xa5f3b271))))
         (parameters (nintendo-ware::xwsd-item-parameters
                       (aref (nintendo-ware::xwsd-info-items (nintendo-ware::xwsd-info file)) 0)))
         (pan (nintendo-ware::xwsd-parameters-pan-info parameters))
         (filter (nintendo-ware::xwsd-parameters-filter-info parameters)))
    (assert (= -128 (nintendo-ware::xwsd-packed-pan-pan pan)))
    (assert (= 127 (nintendo-ware::xwsd-packed-pan-surround-pan pan)))
    (assert (= #xa55a (nintendo-ware::xwsd-packed-pan-reserved pan)))
    (assert (= #x71 (nintendo-ware::xwsd-packed-filter-low-pass filter)))
    (assert (= #xb2 (nintendo-ware::xwsd-packed-filter-biquad-type filter)))
    (assert (= #xf3 (nintendo-ware::xwsd-packed-filter-biquad-value filter))))
  (let* ((archive (nintendo-ware::read-file 'nintendo-ware::xsar
                    (xsar-fixture #() :sound-flags (flags 6 #xa55a0801 #x5aa57f80)
                                      :sequence-flags (flags 2 #xa55aff47))))
         (sound (aref (nintendo-ware::xsar-info-sounds (nintendo-ware::xsar-info archive)) 0))
         (player (nintendo-ware::xsar-sound-player-info sound))
         (priority (nintendo-ware::xsar-sequence-info-priority (nintendo-ware::xsar-sound-detail sound))))
    (assert (= -128 (nintendo-ware::xsar-player-info-priority player)))
    (assert (= 127 (nintendo-ware::xsar-player-info-actor-player-id player)))
    (assert (= #xa55a (nintendo-ware::xsar-pan-mode-info-reserved
                       (nintendo-ware::xsar-sound-pan-mode-info sound))))
    (assert (= 71 (nintendo-ware::xsar-packed-priority-channel-priority priority)))
    (assert (nintendo-ware::xsar-packed-priority-release-priority-p priority))
    (assert (= 127 (nintendo-ware::xsar-packed-priority-release-reserved priority))))
  (let* ((archive (nintendo-ware::read-file 'nintendo-ware::xsar
                    (xsar-fixture #() :sound-flags (flags 2 #x0801))))
         (sound (aref (nintendo-ware::xsar-info-sounds (nintendo-ware::xsar-info archive)) 0))
         (pan (nintendo-ware::xsar-sound-pan-mode-info sound)))
    (assert (eq 'nintendo-ware::balance (nintendo-ware::xsar-pan-mode-info-mode pan)))
    (assert (eq 'nintendo-ware::linear-0-clamp (nintendo-ware::xsar-pan-mode-info-curve pan)))
    (assert (eq t (nintendo-ware::xsar-patricia-node-leaf-p
                   (aref (nintendo-ware::xsar-patricia-tree-nodes
                           (nintendo-ware::xsar-strg-tree (nintendo-ware::xsar-strg archive))) 0)))))
  ;; Sparse sets must not shift later values; unknown bits retain their words.
  (let* ((archive (nintendo-ware::read-file 'nintendo-ware::xsar
                    (xsar-fixture (sequence-fixture #(#xff))
                      :sound-flags (flags #x90020009 0 #x10203040 1 #x55667788 #xaabbccdd)
                      :sequence-flags (flags 2 #x0147))))
         (sound (aref (nintendo-ware::xsar-info-sounds (nintendo-ware::xsar-info archive)) 0))
         (sequence (nintendo-ware::xsar-sound-detail sound)))
    (assert (nintendo-ware::xsar-sound-flags-user-parameter-0-p
              (nintendo-ware::xsar-sound-flags sound)))
    (assert (not (nintendo-ware::xsar-sound-flags-pan-mode-info-p
                   (nintendo-ware::xsar-sound-flags sound))))
    (assert (equalp #(#x10203040) (nintendo-ware::xsar-sound-reserved-3-7-values sound)))
    (assert (nintendo-ware::xsar-front-bypass-info-front-bypass-p
              (nintendo-ware::xsar-sound-front-bypass sound)))
    (assert (= #x55667788 (nintendo-ware::xsar-sound-user-parameter-3 sound)))
    (assert (= #xaabbccdd (nintendo-ware::xsar-sound-user-parameter-0 sound)))
    (assert (null (nintendo-ware::xsar-sequence-info-start-offset sequence)))
    (assert (= 71 (nintendo-ware::xsar-packed-priority-channel-priority
                   (nintendo-ware::xsar-sequence-info-priority sequence)))))
  (let* ((file (nintendo-ware::read-file 'nintendo-ware::xwsd
                 (xwsd-fixture :item-flags (flags #x302 #x40000000 #xffffffff #xffffffff)
                               :note-flags (flags 0))))
         (item (aref (nintendo-ware::xwsd-info-items (nintendo-ware::xwsd-info file)) 0))
         (parameters (nintendo-ware::xwsd-item-parameters item))
         (note (aref (nintendo-ware::xwsd-item-notes item) 0)))
    (assert (= 2.0f0 (nintendo-ware::xwsd-parameters-pitch parameters)))
    (assert (null (nintendo-ware::xwsd-parameters-pan-info parameters)))
    (assert (null (nintendo-ware::xwsd-parameters-sends parameters)))
    (assert (null (nintendo-ware::xwsd-parameters-envelope parameters)))
    (assert (null (nintendo-ware::xwsd-parameters-pitch
                   (nintendo-ware::xwsd-note-parameters note)))))
  ;; A null reference, an empty array and null array elements remain distinct.
  (dolist (*fixture-endian* '(:little :big))
    (dolist (*fixture-family* '(:c :f))
      (dolist (layout '(:absent :empty :sparse))
        (let* ((file (nintendo-ware::read-file 'nintendo-ware::xwsd (xwsd-fixture :events layout)))
               (items (nintendo-ware::xwsd-info-items (nintendo-ware::xwsd-info file)))
               (tracks (nintendo-ware::xwsd-item-tracks (aref items 0)))
               (events (nintendo-ware::xwsd-track-events (aref tracks 0))))
          (ecase layout
            (:absent (assert (null events)))
            (:empty (assert (typep events '(simple-array t (0)))))
            (:sparse
             (assert (typep events '(simple-array t (3))))
             (assert (null (aref events 0)))
             (assert (= 0.5f0 (nintendo-ware::xwsd-event-position (aref events 1))))
             (assert (= 2.0f0 (nintendo-ware::xwsd-event-length (aref events 1))))
             (assert (zerop (nintendo-ware::xwsd-event-note-index (aref events 1))))
             (assert (null (aref events 2)))))))))
  (let* ((sound (nintendo-ware::read-file 'nintendo-ware::xwsd (xwsd-fixture)))
         (information (nintendo-ware::xwsd-info sound))
         (item (aref (nintendo-ware::xwsd-info-items information) 0))
         (parameters (nintendo-ware::xwsd-item-parameters item))
         (pan (nintendo-ware::xwsd-parameters-pan-info parameters))
         (filter (nintendo-ware::xwsd-parameters-filter-info parameters))
         (track (aref (nintendo-ware::xwsd-item-tracks item) 0))
         (event (aref (nintendo-ware::xwsd-track-events track) 0))
         (note (aref (nintendo-ware::xwsd-item-notes item) (nintendo-ware::xwsd-event-note-index event))))
    (assert (= 9 (nintendo-ware::nintendo-ware-sound-wave-id-index (aref (nintendo-ware::xwsd-info-waves information) 0))))
    (assert (= 0.5f0 (nintendo-ware::xwsd-event-position event)))
    (assert (= 2.0f0 (nintendo-ware::xwsd-event-length event)))
    (assert (= 64 (nintendo-ware::xwsd-packed-pan-pan pan)))
    (assert (= 32 (nintendo-ware::xwsd-packed-pan-surround-pan pan)))
    (assert (= 1.5f0 (nintendo-ware::xwsd-parameters-pitch parameters)))
    (assert (= 93 (nintendo-ware::xwsd-sends-main-send (nintendo-ware::xwsd-parameters-sends parameters))))
    (assert (equalp #(17 29) (nintendo-ware::xwsd-sends-auxiliary-sends (nintendo-ware::xwsd-parameters-sends parameters))))
    (assert (= 6 (nintendo-ware::xwsd-envelope-attack (nintendo-ware::xwsd-parameters-envelope parameters))))
    (assert (= 10 (nintendo-ware::xwsd-envelope-release (nintendo-ware::xwsd-parameters-envelope parameters))))
    (assert (= 1 (nintendo-ware::xwsd-packed-filter-low-pass filter)))
    (assert (= 2 (nintendo-ware::xwsd-packed-filter-biquad-type filter)))
    (assert (= 3 (nintendo-ware::xwsd-packed-filter-biquad-value filter)))
    (assert (= 0 (nintendo-ware::xwsd-note-wave-index note)))
    (assert (= 0.75f0 (nintendo-ware::xwsd-parameters-pitch (nintendo-ware::xwsd-note-parameters note))))
    (assert (= 55 (nintendo-ware::xwsd-envelope-release (nintendo-ware::xwsd-parameters-envelope (nintendo-ware::xwsd-note-parameters note))))))
  (let* ((embedded (sequence-fixture #(#xff)))
         (group (nintendo-ware::read-file 'nintendo-ware::xgrp (xgrp-fixture embedded)))
         (archive (nintendo-ware::read-file 'nintendo-ware::xsar (xsar-fixture embedded)))
         (information (nintendo-ware::xsar-info archive))
         (strings (nintendo-ware::xsar-strg-strings (nintendo-ware::xsar-strg archive)))
         (sound (aref (nintendo-ware::xsar-info-sounds information) 0))
         (sequence (nintendo-ware::xsar-sound-detail sound))
         (priority (nintendo-ware::xsar-sequence-info-priority sequence))
         (files (nintendo-ware::xsar-files archive))
         (external (aref (nintendo-ware::xsar-info-files information) 1)))
    (assert (= 7 (nintendo-ware::xgrp-entry-file-id (aref (nintendo-ware::xgrp-info-entries (nintendo-ware::xgrp-info group)) 0))))
    (assert (equalp embedded (nintendo-ware::xgrp-entry-data
                              (find 7 (nintendo-ware::xgrp-info-entries (nintendo-ware::xgrp-info group))
                                    :key #'nintendo-ware::xgrp-entry-file-id))))
    (assert (= #x03000000 (nintendo-ware::nintendo-ware-sound-resource-id-value (nintendo-ware::xgrp-dependency-resource-id (aref (nintendo-ware::xgrp-infx-entries (nintendo-ware::xgrp-infx group)) 0)))))
    (assert (string= "song" (nintendo-ware::xsar-string-text (aref strings 0))))
    (assert (= #x01000000 (nintendo-ware::nintendo-ware-sound-resource-id-value (nintendo-ware::xsar-patricia-node-resource-id (aref (nintendo-ware::xsar-patricia-tree-nodes (nintendo-ware::xsar-strg-tree (nintendo-ware::xsar-strg archive))) 0)))))
    (assert (= 4 (nintendo-ware::xsar-sequence-info-start-offset sequence)))
    (assert (= 80 (nintendo-ware::xsar-packed-priority-channel-priority priority)))
    (assert (nintendo-ware::xsar-packed-priority-release-priority-p priority))
    (let ((bank (aref (nintendo-ware::xsar-sequence-info-banks sequence) 0))
          (wave (aref (nintendo-ware::xsar-bank-wave-archives (aref (nintendo-ware::xsar-info-banks information) 0)) 0)))
      (assert (= 3 (nintendo-ware::nintendo-ware-sound-resource-id-type bank)))
      (assert (zerop (nintendo-ware::nintendo-ware-sound-resource-id-index bank)))
      (assert (= 5 (nintendo-ware::nintendo-ware-sound-resource-id-type wave)))
      (assert (= 2 (nintendo-ware::nintendo-ware-sound-resource-id-index wave))))
    (assert (= 4 (nintendo-ware::xsar-player-sound-limit (aref (nintendo-ware::xsar-info-players information) 0))))
    (assert (= 12 (nintendo-ware::xsar-project-info-maximum-sequences (nintendo-ware::xsar-info-project-info information))))
    (assert (= 24 (nintendo-ware::xsar-project-info-maximum-sequence-tracks (nintendo-ware::xsar-info-project-info information))))
    (assert (= #x12345678 (nintendo-ware::xsar-project-info-options (nintendo-ware::xsar-info-project-info information))))
    (assert (equalp (cons "song" embedded) (aref files 0)))
    (assert (equal '(nil) (aref files 1)))
    (assert (typep (aref (nintendo-ware::xseq-events
                          (nintendo-ware::read-file 'nintendo-ware::xseq
                                                  (nintendo-ware::xsar-file-data (aref files 0)))) 0)
                   'nintendo-ware::xseq-event-finish))
    (assert (string= "audio/example.bcstm" (nintendo-ware::xsar-external-file-text (nintendo-ware::xsar-file-location external)))))
  ;; Numeric-word bitfields retain all three index bytes and unknown type tags,
  ;; including the all-ones sentinel, in either container byte order.
  (dolist (case '((#x05abcdef 5 #xabcdef) (#xffffffff 255 #xffffff)))
    (destructuring-bind (word type index) case
      (let* ((group (nintendo-ware::read-file 'nintendo-ware::xgrp
                      (xgrp-fixture #() :resource-id word)))
             (identifier (nintendo-ware::xgrp-dependency-resource-id
                          (aref (nintendo-ware::xgrp-infx-entries (nintendo-ware::xgrp-infx group)) 0))))
        (assert (= type (nintendo-ware::nintendo-ware-sound-resource-id-type identifier)))
        (assert (= index (nintendo-ware::nintendo-ware-sound-resource-id-index identifier)))
        (assert (= word (nintendo-ware::nintendo-ware-sound-resource-id-value identifier))))))
  ;; GRP file IDs belong to the archive, not the position in this group's table.
  ;; Unknown/invalid children are opaque; only an explicit read may reject them.
  (dolist (payload (list (octets-join #(66 65 68 33))
                        (sequence-fixture #(130) :padded nil)
                        (make-array 0 :element-type '(unsigned-byte 8))))
    (let* ((group (nintendo-ware::read-file 'nintendo-ware::xgrp
                                         (xgrp-fixture payload :file-id 1234)))
           (entry (find 1234 (nintendo-ware::xgrp-info-entries (nintendo-ware::xgrp-info group))
                        :key #'nintendo-ware::xgrp-entry-file-id)))
      (assert entry)
      (assert (typep (nintendo-ware::xgrp-entry-data entry) '(simple-array (unsigned-byte 8) (*))))
      (assert (equalp payload (nintendo-ware::xgrp-entry-data entry)))))
  (let* ((group (nintendo-ware::read-file 'nintendo-ware::xgrp
                                       (xgrp-fixture #(66 65 68 33) :available-p nil)))
         (entry (aref (nintendo-ware::xgrp-info-entries (nintendo-ware::xgrp-info group)) 0)))
    (assert (= 7 (nintendo-ware::xgrp-entry-file-id entry)))
    (assert (null (nintendo-ware::xgrp-entry-data entry))))
  ;; A known-format child with an invalid opcode must remain opaque to XSAR.
  (let* ((bad-child (sequence-fixture #(130) :padded nil))
         (archive (nintendo-ware::read-file 'nintendo-ware::xsar (xsar-fixture bad-child)))
         (file (aref (nintendo-ware::xsar-files archive) 0)))
    (assert (string= "song" (nintendo-ware::xsar-file-name file)))
    (assert (equalp bad-child (nintendo-ware::xsar-file-data file)))
    (rejects binstruct::deserialize-error
      (nintendo-ware::read-file 'nintendo-ware::xseq (nintendo-ware::xsar-file-data file))))
  ;; Unknown payloads require no magic/BOM, and STRG is optional.
  (let* ((bytes (make-array 3 :element-type '(unsigned-byte 8) :initial-contents '(1 2 3)))
         (archive (nintendo-ware::read-file 'nintendo-ware::xsar (xsar-fixture bytes :named-p nil)))
         (file (aref (nintendo-ware::xsar-files archive) 0)))
    (assert (null (nintendo-ware::xsar-file-name file)))
    (assert (equalp bytes (nintendo-ware::xsar-file-data file))))
  ;; Empty data is an octet vector, not a null reference or a dropped file ID.
  (let* ((archive (nintendo-ware::read-file 'nintendo-ware::xsar
                                        (xsar-fixture (make-array 0 :element-type '(unsigned-byte 8)))))
         (files (nintendo-ware::xsar-files archive))
         (data (nintendo-ware::xsar-file-data (aref files 0))))
    (assert (= 2 (length files)))
    (assert (typep data '(simple-array (unsigned-byte 8) (0)))))
  (let* ((archive (nintendo-ware::read-file 'nintendo-ware::xsar
                                        (xsar-fixture #(1 2 3) :available-p nil)))
         (files (nintendo-ware::xsar-files archive)))
    (assert (= 2 (length files)))
    (assert (equal '("song") (aref files 0))))
  ;; The caller, not XSAR, selects the child reader and its independent BOM.
  (let* ((child-endian (if (eq *fixture-endian* :little) :big :little))
         (child (let ((*fixture-family* :c) (*fixture-endian* child-endian))
                  (sequence-fixture #(60 100 12 255))))
         (archive (nintendo-ware::read-file 'nintendo-ware::xsar (xsar-fixture child)))
         (sequence (nintendo-ware::read-file 'nintendo-ware::xseq
                                          (nintendo-ware::xsar-file-data
                                           (aref (nintendo-ware::xsar-files archive) 0))))
         (note (aref (nintendo-ware::xseq-events sequence) 0)))
    (assert (eq child-endian (nintendo-ware::nintendo-ware-file-endian sequence)))
    (assert (= 60 (nintendo-ware::xseq-event-note-key note)))
    (assert (= 100 (nintendo-ware::xseq-event-note-velocity note)))
    (assert (= 12 (nintendo-ware::xseq-event-note-duration note))))
  (dolist (order '((#x4000 #x4001 #x4002 #x4003)
                   (#x4003 #x4001 #x4002 #x4000)
                   (#x4001 #x4000 #x4003 #x4002)))
    (dolist (major '(2 3 4 6))
      (let* ((stream (nintendo-ware::read-file 'nintendo-ware::xstm (xstm-fixture major :section-order order)))
             (information (nintendo-ware::xstm-info stream))
             (metadata (nintendo-ware::xstm-info-stream information))
             (seek-data (nintendo-ware::xstm-info-seek-data information))
             (seek (nintendo-ware::xstm-seek-entry-context (aref (aref (nintendo-ware::xstm-seek-data-rows seek-data) 1) 1)))
             (channel (aref (nintendo-ware::xstm-info-channels information) 1))
             (track (aref (nintendo-ware::xstm-info-tracks information) 0)))
        (assert (eq 'nintendo-ware::dsp-adpcm (nintendo-ware::xstm-stream-info-encoding metadata)))
        (assert (eq t (nintendo-ware::xstm-stream-info-loop-p metadata)))
        (assert (equalp #(0 1) (nintendo-ware::xstm-track-channels track)))
        (assert (= -4 (nintendo-ware::xstm-dsp-seek-context-history-1 seek)))
        (assert (= 400 (nintendo-ware::xstm-dsp-seek-context-history-2 seek)))
        (assert (equalp #(0 0 0 0 0 0 0 0) (nintendo-ware::xstm-seek-data-padding seek-data)))
        (assert (equalp #(4 4 4 4 4 4 4 4) (subseq (nintendo-ware::xstm-stream-info-sample-data metadata) 24 32)))
        (assert (= -222 (nintendo-ware::xwav-dsp-adpcm-context-history-2 (nintendo-ware::xwav-dsp-adpcm-info-loop-context (nintendo-ware::xstm-channel-codec-info channel)))))
        (when (>= major 3)
          (let ((region (aref (nintendo-ware::xstm-region-info-data (nintendo-ware::xstm-stream-info-region-info metadata)) 0)))
            (assert (= 1 (nintendo-ware::xstm-region-start region)))
            (assert (= 20 (nintendo-ware::xstm-region-end region)))
            (assert (= -321 (nintendo-ware::xwav-dsp-adpcm-context-history-1 (aref (nintendo-ware::xstm-region-contexts region) 0))))))
        (when (>= major 4) (assert (= 28 (nintendo-ware::xstm-original-loop-info-end (nintendo-ware::xstm-stream-info-original-loop-info metadata)))))
        (when (>= major 6) (assert (= 42 (nintendo-ware::xstm-secret-info-value (nintendo-ware::xstm-stream-info-secret-info metadata)))))))
    (rejects binstruct::deserialize-error
      (nintendo-ware::read-file 'nintendo-ware::xstm (xstm-fixture 3 :section-order order :seek-interval 0)))
    (rejects binstruct::deserialize-error
      (nintendo-ware::read-file 'nintendo-ware::xstm (xstm-fixture 3 :section-order order :encoding 0)))
    (let* ((stream (nintendo-ware::read-file 'nintendo-ware::xstm
                                          (xstm-fixture 3 :section-order order :sample-offset -1 :region-offset -1)))
           (metadata (nintendo-ware::xstm-info-stream (nintendo-ware::xstm-info stream))))
      (assert (null (nintendo-ware::xstm-stream-info-sample-data metadata)))
      (assert (null (nintendo-ware::xstm-region-info-data (nintendo-ware::xstm-stream-info-region-info metadata))))))
  (format t "SAR extraction and GRP/WSD/STM reader scenarios passed.~%"))
