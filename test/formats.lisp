(in-package #:cl-nintendo-ware.test)

(defun encode-record (type value &rest arguments)
  (let* ((name (if (eq *fixture-endian* :big)
                   (intern (format nil "~A/BE" (symbol-name type)) (symbol-package type)) type))
         (emitter (binstruct::emitter-name-symbol name)))
    (flexi-streams:with-output-to-sequence (output)
      (let ((binstruct::*positions* nil))
        (apply (symbol-function emitter) (binstruct::stream-emitter-output output) value arguments)
        (binstruct::flush-pointer-positions)))))

(defun octets-join (&rest parts)
  (apply #'concatenate '(simple-array (unsigned-byte 8) (*)) parts))

(defun container-fixture (magic block-specifications &key (version #x02010000) directory-order)
  (let* ((header-size (* 32 (ceiling (+ 20 (* 12 (length block-specifications))) 32)))
         (position header-size)
         (references
           (map 'vector
                (lambda (specification)
                  (destructuring-bind (type block-magic bytes) specification
                    (declare (ignore block-magic))
                    (let* ((size (* 32 (ceiling (+ 8 (length bytes)) 32)))
                           (reference (cl-nintendo-ware.test::make-sized-reference :type type :offset position :size size)))
                      (incf position size)
                      reference)))
                block-specifications)))
    (flexi-streams:with-output-to-sequence (output)
      (emit-octets output (encode-record 'cl-nintendo-ware.test::header-record
                                        (cl-nintendo-ware.test::make-header-record :magic (coerce (fixture-magic magic) 'simple-base-string) :bom #xfeff :header-size header-size
                                                                    :version (fixture-version version) :file-size position
                                                                    :block-count (length references)
                                                                    :references (if directory-order
                                                                                    (map 'vector (lambda (index) (aref references index)) directory-order)
                                                                                    references))))
      (emit-octets output (make-array (- header-size (+ 20 (* 12 (length references)))) :initial-element 0))
      (loop :for specification :in block-specifications
            :for reference :across references
            :do (destructuring-bind (type magic bytes) specification
                  (declare (ignore type))
                  (emit-octets output (encode-record 'cl-nintendo-ware.test::block-record
                                                    (cl-nintendo-ware.test::make-block-record :magic (coerce magic 'simple-base-string) :size (cl-nintendo-ware.test::sized-reference-size reference))))
                  (emit-octets output bytes)
                  (emit-octets output (make-array (- (cl-nintendo-ware.test::sized-reference-size reference) 8 (length bytes)) :initial-element 0)))))))

(defun wave-fixture (codec &key (sample-count 3) payloads (loop 1) (data-magic "DATA") (data-p t))
  (let* ((sample-size (cl-nintendo-ware.test::xwav-encoded-size codec sample-count))
         (codec-size (case codec (2 46) (3 8) (otherwise 0)))
         (codec-reference-type (case codec (2 #x0300) (3 #x0301) (otherwise 0)))
         (info
           (octets-join
            (encode-record 'cl-nintendo-ware.test::xwav-info
                           (cl-nintendo-ware.test::make-xwav-info :codec codec :loop loop :sample-rate 32000 :loop-start 1 :loop-end sample-count))
            (encode-record 'cl-nintendo-ware.test::reference-table
                           (cl-nintendo-ware.test::make-reference-table :count 2
                             :entries (vector (cl-nintendo-ware.test::make-reference :type #x7100 :offset 20)
                                              (cl-nintendo-ware.test::make-reference :type #x7100 :offset 40))))
            (apply #'octets-join
                   (loop :for index :below 2
                         :collect (encode-record 'cl-nintendo-ware.test::xwav-channel-info
                                   (cl-nintendo-ware.test::make-xwav-channel-info
                                    :samples-reference (cl-nintendo-ware.test::make-reference :type #x1f00 :offset (* index sample-size))
                                    :codec-reference (cl-nintendo-ware.test::make-reference :type codec-reference-type
                                                       :offset (if (zerop codec-size) -1
                                                                   (- (+ 80 (* index codec-size)) (+ 40 (* index 20)))))))))
            (apply #'octets-join
                   (loop :for index :below 2
                         :collect (case codec
                                    (2 (encode-record 'cl-nintendo-ware.test::xwav-dsp-adpcm-info
                                         (cl-nintendo-ware.test::make-xwav-dsp-adpcm-info
                                          :coefficients (make-array 16 :element-type '(signed-byte 16) :initial-element -123)
                                          :initial-context (cl-nintendo-ware.test::make-xwav-dsp-adpcm-context :predictor-scale 5 :history-1 -200 :history-2 300)
                                          :loop-context (cl-nintendo-ware.test::make-xwav-dsp-adpcm-context :history-1 400 :history-2 -500))))
                                    (3 (encode-record 'cl-nintendo-ware.test::xwav-ima-adpcm-info
                                         (cl-nintendo-ware.test::make-xwav-ima-adpcm-info
                                          :initial-context (cl-nintendo-ware.test::make-xwav-ima-adpcm-context :predictor -200 :step-index 12)
                                          :loop-context (cl-nintendo-ware.test::make-xwav-ima-adpcm-context :predictor 300 :step-index 24))))
                                    (otherwise #()))))))
         (payload (if payloads (apply #'octets-join payloads)
                      (octets-join (make-array sample-size :initial-element 17)
                                   (make-array sample-size :initial-element 34)))))
    (container-fixture "CWAV" (append (list (list #x7000 "INFO" info))
                                     (when data-p (list (list #x7001 data-magic payload)))))))

(defun xbnk-node-fixture (tag child-type child)
  (let* ((detail-size (ecase tag (#x6000 8) (#x6001 16) (#x6002 12)))
         (reference (cl-nintendo-ware.test::make-reference :type child-type :offset detail-size))
         (detail (ecase tag
                   (#x6000 (encode-record 'cl-nintendo-ware.test::reference reference))
                   (#x6001 (encode-record 'cl-nintendo-ware.test::xbnk-index-data
                            (cl-nintendo-ware.test::make-xbnk-index-data :count 1
                             :upper-bounds (make-array 1 :element-type '(unsigned-byte 8) :initial-element 127)
                             :padding (make-array 3 :element-type '(unsigned-byte 8) :initial-element 0)
                             :references (vector reference))))
                   (#x6002 (encode-record 'cl-nintendo-ware.test::xbnk-range-data
                            (cl-nintendo-ware.test::make-xbnk-range-data :minimum 64 :maximum 64 :references (vector reference)))))))
    (octets-join (encode-record 'cl-nintendo-ware.test::reference (cl-nintendo-ware.test::make-reference :type tag :offset 8)) detail child)))

(defun xbnk-fixture (instrument-tag key-tag &optional (wave-index 0))
  (let* ((leaf (octets-join
                (encode-record 'cl-nintendo-ware.test::xbnk-velocity-data (cl-nintendo-ware.test::make-xbnk-velocity-data :wave-index wave-index))
                (encode-record 'cl-nintendo-ware.test::fixture-parameter-words
                               (cl-nintendo-ware.test::make-fixture-parameter-words :mask #x21f
                                 :values (make-array 6 :element-type '(unsigned-byte 32)
                                                     :initial-contents '(60 100 #x2040 #x3fc00000 #x10001 32))))
                (encode-record 'cl-nintendo-ware.test::reference (cl-nintendo-ware.test::make-reference :type 0 :offset 8))
                (encode-record 'cl-nintendo-ware.test::xbnk-adshr-curve
                               (cl-nintendo-ware.test::make-xbnk-adshr-curve :attack 1 :decay 2 :sustain 3 :hold 4 :release 5))))
         (node (xbnk-node-fixture instrument-tag #x5901
                                 (xbnk-node-fixture key-tag #x5902 leaf)))
         (info (octets-join
                (encode-record 'cl-nintendo-ware.test::reference-pair
                               (cl-nintendo-ware.test::make-reference-pair :first (cl-nintendo-ware.test::make-reference :type #x0100 :offset 28)
                                                           :second (cl-nintendo-ware.test::make-reference :type #x0101 :offset 16)))
                (encode-record 'cl-nintendo-ware.test::reference-table
                               (cl-nintendo-ware.test::make-reference-table :count 1
                                 :entries (vector (cl-nintendo-ware.test::make-reference :type #x5900 :offset 24))))
                (encode-record 'cl-nintendo-ware.test::wave-id-table
                               (cl-nintendo-ware.test::make-wave-id-table :count 1
                                 :entries (vector (cl-nintendo-ware.test::make-wave-id :archive-id #x05000002 :index 7))))
                node)))
    (container-fixture "CBNK" (list (list #x5800 "INFO" info)))))

(defun run-container-default-tests ()
  ;; Empty constructors must not fabricate section presence or depend on parser
  ;; arguments. Array defaults must already satisfy their public Lisp types.
  (dolist (file (list (nintendo-ware::make-xseq) (nintendo-ware::make-xwav)
                     (nintendo-ware::make-xwar) (nintendo-ware::make-xbnk)
                     (nintendo-ware::make-xwsd) (nintendo-ware::make-xstm)
                     (nintendo-ware::make-xsar) (nintendo-ware::make-xgrp)))
    (assert (typep (nintendo-ware::nintendo-ware-file-sections file) '(simple-array t (0))))
    (assert (typep (nintendo-ware::nintendo-ware-file-magic file) 'simple-base-string))
    (assert (zerop (nintendo-ware::nintendo-ware-file-version file))))
  (assert (null (nintendo-ware::xseq-data (nintendo-ware::make-xseq))))
  (assert (null (nintendo-ware::xwar-info (nintendo-ware::make-xwar))))
  (dolist (body (list
                 (nintendo-ware::xseq-data-body (nintendo-ware::make-xseq-data))
                 (nintendo-ware::xseq-labels-body (nintendo-ware::make-xseq-labels))
                 (nintendo-ware::xwav-info-body (nintendo-ware::make-xwav-info))
                 (nintendo-ware::xwav-data-body (nintendo-ware::make-xwav-data))
                 (nintendo-ware::xwar-info-body (nintendo-ware::make-xwar-info))
                 (nintendo-ware::xbnk-info-body (nintendo-ware::make-xbnk-info))
                 (nintendo-ware::xwsd-info-body (nintendo-ware::make-xwsd-info))
                 (nintendo-ware::xsar-strg-body (nintendo-ware::make-xsar-strg))
                 (nintendo-ware::xsar-info-body (nintendo-ware::make-xsar-info))
                 (nintendo-ware::xgrp-info-body (nintendo-ware::make-xgrp-info))
                 (nintendo-ware::xgrp-infx-body (nintendo-ware::make-xgrp-infx))
                 (nintendo-ware::xstm-info-body (nintendo-ware::make-xstm-info))
                 (nintendo-ware::xstm-seek-body (nintendo-ware::make-xstm-seek))
                 (nintendo-ware::xstm-regions-body (nintendo-ware::make-xstm-regions))
                 (nintendo-ware::nintendo-ware-section-raw-block-body (nintendo-ware::make-nintendo-ware-section-raw-block))))
    (assert (null body)))
  (dolist (bytes (list
                 (nintendo-ware::xseq-data-body-bytes (nintendo-ware::make-xseq-data-body))
                 (nintendo-ware::xseq-labels-body-bytes (nintendo-ware::make-xseq-labels-body))
                 (nintendo-ware::xwav-data-body-bytes (nintendo-ware::make-xwav-data-body))
                 (nintendo-ware::xsar-info-body-bytes (nintendo-ware::make-xsar-info-body))
                 (nintendo-ware::xstm-info-body-bytes (nintendo-ware::make-xstm-info-body))
                 (nintendo-ware::xstm-seek-body-bytes (nintendo-ware::make-xstm-seek-body))
                 (nintendo-ware::xstm-regions-body-bytes (nintendo-ware::make-xstm-regions-body))
                 (nintendo-ware::nintendo-ware-section-octets-bytes (nintendo-ware::make-nintendo-ware-section-octets))))
    (assert (typep bytes '(simple-array (unsigned-byte 8) (0)))))
  (dolist (entries (list
                   (nintendo-ware::xwav-info-body-channels (nintendo-ware::make-xwav-info-body))
                   (nintendo-ware::xwar-info-body-entries (nintendo-ware::make-xwar-info-body))
                   (nintendo-ware::xgrp-info-body-entries (nintendo-ware::make-xgrp-info-body))
                   (nintendo-ware::xgrp-infx-body-entries (nintendo-ware::make-xgrp-infx-body))))
    (assert (typep entries '(simple-array t (0)))))
  (assert (null (nintendo-ware::xbnk-info-body-instruments (nintendo-ware::make-xbnk-info-body))))
  (assert (null (nintendo-ware::xbnk-info-body-waves (nintendo-ware::make-xbnk-info-body))))
  (assert (null (nintendo-ware::xwsd-info-body-items (nintendo-ware::make-xwsd-info-body))))
  (assert (null (nintendo-ware::xwsd-info-body-waves (nintendo-ware::make-xwsd-info-body))))
  (assert (null (nintendo-ware::xsar-strg-body-strings (nintendo-ware::make-xsar-strg-body)))))

(defun run-format-tests ()
  (run-container-default-tests)
  ;; Directory order is not physical section order. Embedded WAV parsing is
  ;; deferred until extraction, including failure of a malformed child.
  (dolist (child (list (wave-fixture 0) (octets-join #(66 65 68 33))))
    (let* ((table (encode-record 'sized-reference-table
                    (make-sized-reference-table :count 2
                      :entries (vector (make-sized-reference :type #x1f00 :offset 0 :size (length child))
                                       (make-sized-reference :offset -1)))))
           (archive (nintendo-ware::read-file 'nintendo-ware::xwar
                      (container-fixture "CWAR"
                        (list (list #x6801 "FILE" child) (list #x6800 "INFO" table))
                        :directory-order '(1 0)))))
      (assert (typep (nintendo-ware::xwar-info archive) 'nintendo-ware::xwar-info))
      (assert (typep (nintendo-ware::xwar-file archive) 'nintendo-ware::nintendo-ware-section-raw-block))
      (assert (= 2 (nintendo-ware::xwar-info-body-count
                     (nintendo-ware::xwar-info-body (nintendo-ware::xwar-info archive)))))
      (if (= 4 (length child))
          (rejects binstruct::deserialize-error (nintendo-ware::xwar-waves archive))
          (let ((waves (nintendo-ware::xwar-waves archive)))
            (assert (equalp #(17 17 17) (nintendo-ware::xwav-samples (aref waves 0))))
            (assert (null (aref waves 1)))))))
  (rejects binstruct::deserialize-error
    (nintendo-ware::read-file 'nintendo-ware::xwar
      (container-fixture "CWAR" (list (list #x7ffe "FILE" #())))))
  (rejects binstruct::deserialize-error
    (nintendo-ware::read-file 'nintendo-ware::xwar
      (container-fixture "CWAR" (list (list #x6801 "JUNK" #())))))
  (rejects type-error
    (nintendo-ware::read-file 'nintendo-ware::xwar
      (encode-record 'header-record
        (make-header-record :magic (coerce (fixture-magic "CWAR") 'simple-base-string)
          :bom #x1234 :header-size 20 :file-size 20))))
  (dolist (tag '(#x6801 #x7ffe))
    (rejects binstruct::deserialize-error
      (nintendo-ware::read-file 'nintendo-ware::xwar
        (encode-record 'header-record
          (make-header-record :magic (coerce (fixture-magic "CWAR") 'simple-base-string)
            :bom #xfeff :header-size 32 :file-size 32 :block-count 1
            :references (vector (make-sized-reference :type tag :offset -1)))))))
  (let ((wave (nintendo-ware::read-file 'nintendo-ware::xwav (wave-fixture 0 :data-p nil))))
    (assert (= 32000 (nintendo-ware::xwav-info-body-sample-rate
                      (nintendo-ware::xwav-info-body (nintendo-ware::xwav-info wave)))))
    (assert (null (nintendo-ware::xwav-data wave)))
    (rejects binstruct::deserialize-error (nintendo-ware::xwav-samples wave)))
  (let ((wave (nintendo-ware::read-file 'nintendo-ware::xwav
                (wave-fixture 0 :sample-count 100 :payloads '(#(1) #(2))))))
    (assert (= 100 (nintendo-ware::xwav-info-body-loop-end
                    (nintendo-ware::xwav-info-body (nintendo-ware::xwav-info wave)))))
    (rejects binstruct::deserialize-error (nintendo-ware::xwav-samples wave)))
  (let ((wave (nintendo-ware::read-file 'nintendo-ware::xwav (wave-fixture 0))))
    (rejects type-error (nintendo-ware::xwav-samples wave 2)))
  (dotimes (codec 4)
    (let* ((bytes (wave-fixture codec))
           (wave (nintendo-ware::read-file 'nintendo-ware::xwav bytes))
           (information (nintendo-ware::xwav-info-body (nintendo-ware::xwav-info wave)))
           (channels (nintendo-ware::xwav-info-body-channels information))
           (codec-info (nintendo-ware::xwav-channel-codec-info (aref channels 0))))
      (assert (eq (nth codec '(nintendo-ware::pcm-8 nintendo-ware::pcm-16
                               nintendo-ware::dsp-adpcm nintendo-ware::ima-adpcm))
                  (nintendo-ware::xwav-info-body-codec information)))
      (assert (eq t (nintendo-ware::xwav-info-body-loop-p information)))
      (assert (= 32000 (nintendo-ware::xwav-info-body-sample-rate information)))
      (assert (= 1 (nintendo-ware::xwav-info-body-loop-start information)))
      (assert (= 3 (nintendo-ware::xwav-info-body-loop-end information)))
      (loop for channel-index from 0 below (length channels) for value in '(17 34) do
        (let* ((data (nintendo-ware::xwav-samples wave channel-index))
               (element-type (ecase codec (0 '(signed-byte 8)) (1 '(signed-byte 16))
                                          (2 '(unsigned-byte 8)) (3 '(unsigned-byte 4))))
               (expected (ecase codec (0 value) (1 (* value 257)) (2 value) (3 (/ value 17)))))
          (assert (typep data `(simple-array ,element-type (*))))
          (assert (equalp (make-array (if (= codec 2) 8 3) :initial-element expected) data))))
      (case codec
        (2 (assert (= -123 (aref (nintendo-ware::xwav-dsp-adpcm-info-coefficients codec-info) 15)))
           (assert (= -200 (nintendo-ware::xwav-dsp-adpcm-context-history-1 (nintendo-ware::xwav-dsp-adpcm-info-initial-context codec-info))))
           (assert (= -500 (nintendo-ware::xwav-dsp-adpcm-context-history-2 (nintendo-ware::xwav-dsp-adpcm-info-loop-context codec-info)))))
        (3 (assert (= -200 (nintendo-ware::xwav-ima-adpcm-context-predictor (nintendo-ware::xwav-ima-adpcm-info-initial-context codec-info))))
           (assert (= 24 (nintendo-ware::xwav-ima-adpcm-context-step-index (nintendo-ware::xwav-ima-adpcm-info-loop-context codec-info)))))
        (otherwise (assert (null codec-info))))
      (let* ((table (encode-record 'sized-reference-table
                      (make-sized-reference-table :count 2
                       :entries (vector (make-sized-reference :type #x1f00 :offset 0 :size (length bytes))
                                        (make-sized-reference :offset -1)))))
             (archive (nintendo-ware::read-file 'nintendo-ware::xwar (container-fixture "CWAR"
                                            (list (list #x6800 "INFO" table) (list #x6801 "FILE" bytes)))))
             (waves (nintendo-ware::xwar-waves archive)))
        (let ((embedded (aref waves 0)))
          (assert (equalp channels
                          (nintendo-ware::xwav-info-body-channels
                           (nintendo-ware::xwav-info-body (nintendo-ware::xwav-info embedded))))))
        (assert (null (aref waves 1))))))
  ;; Distinct signs/bytes catch unsigned PCM and container-endian regressions;
  ;; odd IMA lengths must discard the unused high nibble, not expose padding.
  (dolist (case `((0 5 #(#x80 #xff 0 1 #x7f) (-128 -1 0 1 127) (signed-byte 8))
                  (1 5 ,(if (eq *fixture-endian* :little)
                            #(#xff #x7f 0 #x80 #xff #xff 0 0 #x34 #x12)
                            #(#x7f #xff #x80 0 #xff #xff 0 0 #x12 #x34))
                     (32767 -32768 -1 0 4660) (signed-byte 16))
                  (2 15 #(#x21 #x7f #x80 #xff #xab #xcd #xef #x01
                           #x30 #x89 #x67 #x45 #x23 #x01 #xfe #xdc)
                     (33 127 128 255 171 205 239 1 48 137 103 69 35 1 254 220) (unsigned-byte 8))
                  (3 5 #(#x21 #x43 #xf5) (1 2 3 4 5) (unsigned-byte 4))))
    (destructuring-bind (codec count payload expected element-type) case
      (let* ((wave (nintendo-ware::read-file 'nintendo-ware::xwav
                     (wave-fixture codec :sample-count count :loop 0 :payloads (list payload payload))))
             (info (nintendo-ware::xwav-info-body (nintendo-ware::xwav-info wave)))
             (data (nintendo-ware::xwav-samples wave)))
        (assert (null (nintendo-ware::xwav-info-body-loop-p info)))
        (assert (typep data `(simple-array ,element-type (*))))
        (assert (equalp (coerce expected 'vector) data)))))
  (dotimes (codec 4)
    (let* ((wave (nintendo-ware::read-file 'nintendo-ware::xwav (wave-fixture codec :sample-count 0)))
           (data (nintendo-ware::xwav-samples wave)))
      (assert (typep data `(simple-array ,(ecase codec (0 '(signed-byte 8)) (1 '(signed-byte 16))
                                                     (2 '(unsigned-byte 8)) (3 '(unsigned-byte 4))) (0))))))
  (rejects binstruct::deserialize-error
    (nintendo-ware::read-file 'nintendo-ware::xwav (wave-fixture 0 :data-magic "JUNK")))
  (dolist (instrument-tag '(#x6000 #x6001 #x6002))
    (dolist (key-tag '(#x6000 #x6001 #x6002))
      (let* ((xbnk (nintendo-ware::read-file 'nintendo-ware::xbnk (xbnk-fixture instrument-tag key-tag)))
             (instrument (aref (nintendo-ware::xbnk-info-body-instruments (nintendo-ware::xbnk-info-body (nintendo-ware::xbnk-info xbnk))) 0))
             (keys (nintendo-ware::xbnk-instrument-definition instrument))
             (key (ecase instrument-tag
                    (#x6000 (nintendo-ware::xbnk-key-direct-entry keys))
                    (#x6001 (aref (nintendo-ware::xbnk-key-index-entries keys) 0))
                    (#x6002 (aref (nintendo-ware::xbnk-key-range-entries keys) 0))))
             (velocities (nintendo-ware::xbnk-key-definition key))
             (velocity (ecase key-tag
                         (#x6000 (nintendo-ware::xbnk-velocity-direct-entry velocities))
                         (#x6001 (aref (nintendo-ware::xbnk-velocity-index-entries velocities) 0))
                         (#x6002 (aref (nintendo-ware::xbnk-velocity-range-entries velocities) 0))))
             (pan (nintendo-ware::xbnk-velocity-pan-info velocity)))
        (assert (= 0 (nintendo-ware::xbnk-velocity-wave-index velocity)))
        (assert (= 7 (nintendo-ware::nintendo-ware-sound-wave-id-index (aref (nintendo-ware::xbnk-info-body-waves (nintendo-ware::xbnk-info-body (nintendo-ware::xbnk-info xbnk))) 0))))
        (assert (= 1.5f0 (nintendo-ware::xbnk-velocity-pitch velocity)))
        (assert (= 64 (nintendo-ware::xbnk-pan-flag-pan pan)))
        (assert (= 32 (nintendo-ware::xbnk-pan-flag-surround-pan pan)))
        (let ((note (nintendo-ware::xbnk-velocity-note-info velocity)))
          (assert (nintendo-ware::xbnk-note-flag-percussion-p note))
          (assert (= 0 (nintendo-ware::xbnk-note-flag-key-group note)))
          (assert (eq 'nintendo-ware::linear (nintendo-ware::xbnk-note-flag-interpolation-type note))))
        (assert (= 4 (nintendo-ware::xbnk-adshr-curve-hold (nintendo-ware::xbnk-velocity-envelope velocity)))))))
  (rejects binstruct::deserialize-error (nintendo-ware::read-file 'nintendo-ware::xbnk (xbnk-fixture #x6000 #x6000 1)))
  ;; Removing size/overlap validation must not remove section identification.
  (rejects binstruct::deserialize-error
    (nintendo-ware::read-file 'nintendo-ware::xwav
      (container-fixture "CWAV" (list (list #x7000 "JUNK" #()) (list #x7001 "DATA" #())))))
  (let* ((first (wave-fixture 2))
         (second (wave-fixture 3))
         (table (encode-record 'sized-reference-table
                  (make-sized-reference-table :count 2
                   :entries (vector (make-sized-reference :type #x1f00 :offset 0 :size (length first))
                                    (make-sized-reference :type #x1f00 :offset (length first) :size (length second))))))
         (archive (nintendo-ware::read-file 'nintendo-ware::xwar (container-fixture "CWAR"
                                        (list (list #x6800 "INFO" table) (list #x6801 "FILE" (octets-join first second))))))
         (entries (nintendo-ware::xwar-waves archive))
         (first-wave (aref entries 0))
         (second-wave (aref entries 1)))
    (assert (= -123 (aref (nintendo-ware::xwav-dsp-adpcm-info-coefficients
                           (nintendo-ware::xwav-channel-codec-info (aref (nintendo-ware::xwav-info-body-channels (nintendo-ware::xwav-info-body (nintendo-ware::xwav-info first-wave))) 0))) 15)))
    (assert (= -200 (nintendo-ware::xwav-ima-adpcm-context-predictor
                     (nintendo-ware::xwav-ima-adpcm-info-initial-context
                      (nintendo-ware::xwav-channel-codec-info (aref (nintendo-ware::xwav-info-body-channels (nintendo-ware::xwav-info-body (nintendo-ware::xwav-info second-wave))) 0)))))))
  (format t "Direct WAV/WAR/BNK graph scenarios passed.~%"))
