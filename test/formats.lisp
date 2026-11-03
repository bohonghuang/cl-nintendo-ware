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

(defun container-fixture (magic block-specifications &key (version #x02010000))
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
                                                                    :block-count (length references) :references references)))
      (emit-octets output (make-array (- header-size (+ 20 (* 12 (length references)))) :initial-element 0))
      (loop :for specification :in block-specifications
            :for reference :across references
            :do (destructuring-bind (type magic bytes) specification
                  (declare (ignore type))
                  (emit-octets output (encode-record 'cl-nintendo-ware.test::block-record
                                                    (cl-nintendo-ware.test::make-block-record :magic (coerce magic 'simple-base-string) :size (cl-nintendo-ware.test::sized-reference-size reference))))
                  (emit-octets output bytes)
                  (emit-octets output (make-array (- (cl-nintendo-ware.test::sized-reference-size reference) 8 (length bytes)) :initial-element 0)))))))

(defun wave-fixture (codec)
  (let* ((sample-size (cl-nintendo-ware.test::sound-wave-encoded-size codec 3))
         (codec-size (case codec (2 46) (3 8) (otherwise 0)))
         (codec-reference-type (case codec (2 #x0300) (3 #x0301) (otherwise 0)))
         (info
           (octets-join
            (encode-record 'cl-nintendo-ware.test::sound-wave-info
                           (cl-nintendo-ware.test::make-sound-wave-info :codec codec :loop 1 :sample-rate 32000 :loop-start 1 :loop-end 3))
            (encode-record 'cl-nintendo-ware.test::reference-table
                           (cl-nintendo-ware.test::make-reference-table :count 2
                             :entries (vector (cl-nintendo-ware.test::make-reference :type #x7100 :offset 20)
                                              (cl-nintendo-ware.test::make-reference :type #x7100 :offset 40))))
            (apply #'octets-join
                   (loop :for index :below 2
                         :collect (encode-record 'cl-nintendo-ware.test::sound-wave-channel-info
                                   (cl-nintendo-ware.test::make-sound-wave-channel-info
                                    :samples-reference (cl-nintendo-ware.test::make-reference :type #x1f00 :offset (* index sample-size))
                                    :codec-reference (cl-nintendo-ware.test::make-reference :type codec-reference-type
                                                       :offset (if (zerop codec-size) -1
                                                                   (- (+ 80 (* index codec-size)) (+ 40 (* index 20)))))))))
            (apply #'octets-join
                   (loop :for index :below 2
                         :collect (case codec
                                    (2 (encode-record 'cl-nintendo-ware.test::dsp-adpcm-info
                                         (cl-nintendo-ware.test::make-dsp-adpcm-info
                                          :coefficients (make-array 16 :element-type '(signed-byte 16) :initial-element -123)
                                          :initial-context (cl-nintendo-ware.test::make-dsp-adpcm-context :predictor-scale 5 :history-1 -200 :history-2 300)
                                          :loop-context (cl-nintendo-ware.test::make-dsp-adpcm-context :history-1 400 :history-2 -500))))
                                    (3 (encode-record 'cl-nintendo-ware.test::ima-adpcm-info
                                         (cl-nintendo-ware.test::make-ima-adpcm-info
                                          :initial-context (cl-nintendo-ware.test::make-ima-adpcm-context :predictor -200 :step-index 12)
                                          :loop-context (cl-nintendo-ware.test::make-ima-adpcm-context :predictor 300 :step-index 24))))
                                    (otherwise #()))))))
         (payload (octets-join (make-array sample-size :initial-element 17)
                               (make-array sample-size :initial-element 34))))
    (container-fixture "CWAV" (list (list #x7000 "INFO" info) (list #x7001 "DATA" payload)))))

(defun bank-node-fixture (tag child-type child)
  (let* ((detail-size (ecase tag (#x6000 8) (#x6001 16) (#x6002 12)))
         (reference (cl-nintendo-ware.test::make-reference :type child-type :offset detail-size))
         (detail (ecase tag
                   (#x6000 (encode-record 'cl-nintendo-ware.test::reference reference))
                   (#x6001 (encode-record 'cl-nintendo-ware.test::bank-index-data
                            (cl-nintendo-ware.test::make-bank-index-data :count 1
                             :upper-bounds (make-array 1 :element-type '(unsigned-byte 8) :initial-element 127)
                             :padding (make-array 3 :element-type '(unsigned-byte 8) :initial-element 0)
                             :references (vector reference))))
                   (#x6002 (encode-record 'cl-nintendo-ware.test::bank-range-data
                            (cl-nintendo-ware.test::make-bank-range-data :minimum 64 :maximum 64 :references (vector reference)))))))
    (octets-join (encode-record 'cl-nintendo-ware.test::reference (cl-nintendo-ware.test::make-reference :type tag :offset 8)) detail child)))

(defun bank-fixture (instrument-tag key-tag &optional (wave-index 0))
  (let* ((leaf (octets-join
                (encode-record 'cl-nintendo-ware.test::bank-velocity-data (cl-nintendo-ware.test::make-bank-velocity-data :wave-index wave-index))
                (encode-record 'cl-nintendo-ware.test::flag-values
                               (cl-nintendo-ware.test::make-flag-values :mask #x21f
                                 :values (make-array 6 :element-type '(unsigned-byte 32)
                                                     :initial-contents '(60 100 #x2040 #x3fc00000 #x10001 32))))
                (encode-record 'cl-nintendo-ware.test::reference (cl-nintendo-ware.test::make-reference :type 0 :offset 8))
                (encode-record 'cl-nintendo-ware.test::adshr-curve
                               (cl-nintendo-ware.test::make-adshr-curve :attack 1 :decay 2 :sustain 3 :hold 4 :release 5))))
         (node (bank-node-fixture instrument-tag #x5901
                                 (bank-node-fixture key-tag #x5902 leaf)))
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

(defun run-format-tests ()
  (dotimes (codec 4)
    (let* ((bytes (wave-fixture codec))
           (wave (nintendo-ware:read-file :sound-wave bytes))
           (information (nintendo-ware:sound-wave-info wave))
           (channels (nintendo-ware:sound-wave-info-channels information))
           (codec-info (nintendo-ware:sound-wave-channel-codec-info (aref channels 0))))
      (assert (= 32000 (nintendo-ware:sound-wave-info-sample-rate information)))
      (assert (= 1 (nintendo-ware:sound-wave-info-loop-start information)))
      (assert (= 3 (nintendo-ware:sound-wave-info-loop-end information)))
      (assert (equalp (make-array (sound-wave-encoded-size codec 3) :initial-element 17)
                      (nintendo-ware:sound-wave-channel-encoded-data (aref channels 0))))
      (assert (equalp (make-array (sound-wave-encoded-size codec 3) :initial-element 34)
                      (nintendo-ware:sound-wave-channel-encoded-data (aref channels 1))))
      (case codec
        (2 (assert (= -123 (aref (nintendo-ware:dsp-adpcm-info-coefficients codec-info) 15)))
           (assert (= -200 (nintendo-ware:dsp-adpcm-context-history-1 (nintendo-ware:dsp-adpcm-info-initial-context codec-info))))
           (assert (= -500 (nintendo-ware:dsp-adpcm-context-history-2 (nintendo-ware:dsp-adpcm-info-loop-context codec-info)))))
        (3 (assert (= -200 (nintendo-ware:ima-adpcm-context-predictor (nintendo-ware:ima-adpcm-info-initial-context codec-info))))
           (assert (= 24 (nintendo-ware:ima-adpcm-context-step-index (nintendo-ware:ima-adpcm-info-loop-context codec-info)))))
        (otherwise (assert (null codec-info))))
      (let* ((table (encode-record 'sized-reference-table
                      (make-sized-reference-table :count 2
                       :entries (vector (make-sized-reference :type #x1f00 :offset 0 :size (length bytes))
                                        (make-sized-reference :offset -1)))))
             (archive (nintendo-ware:read-file :wave-archive (container-fixture "CWAR"
                                            (list (list #x6800 "INFO" table) (list #x6801 "FILE" bytes)))))
             (entries (nintendo-ware:wave-archive-info-entries (nintendo-ware:wave-archive-info archive))))
        (let ((embedded (nintendo-ware:wave-archive-entry-content (aref entries 0))))
          (assert (> (nintendo-ware:header-start (nintendo-ware:sound-wave-header embedded)) 0))
          (assert (equalp (nintendo-ware:sound-wave-info-channels information)
                          (nintendo-ware:sound-wave-info-channels (nintendo-ware:sound-wave-info embedded)))))
        (assert (null (nintendo-ware:wave-archive-entry-content (aref entries 1)))))))
  (dolist (instrument-tag '(#x6000 #x6001 #x6002))
    (dolist (key-tag '(#x6000 #x6001 #x6002))
      (let* ((bank (nintendo-ware:read-file :sound-bank (bank-fixture instrument-tag key-tag)))
             (instrument (aref (nintendo-ware:bank-instrument-table-entries (nintendo-ware:sound-bank-info-instruments (nintendo-ware:sound-bank-info bank))) 0))
             (keys (nintendo-ware:bank-instrument-definition instrument))
             (key (ecase instrument-tag
                    (#x6000 (nintendo-ware:bank-key-direct-entry keys))
                    (#x6001 (aref (nintendo-ware:bank-key-index-entries keys) 0))
                    (#x6002 (aref (nintendo-ware:bank-key-range-entries keys) 0))))
             (velocities (nintendo-ware:bank-key-definition key))
             (velocity (ecase key-tag
                         (#x6000 (nintendo-ware:bank-velocity-direct-entry velocities))
                         (#x6001 (aref (nintendo-ware:bank-velocity-index-entries velocities) 0))
                         (#x6002 (aref (nintendo-ware:bank-velocity-range-entries velocities) 0))))
             (pan (nintendo-ware:bank-velocity-pan-info velocity)))
        (assert (= 0 (nintendo-ware:bank-velocity-wave-index velocity)))
        (assert (= 7 (nintendo-ware:wave-id-index (aref (nintendo-ware:wave-id-table-entries (nintendo-ware:sound-bank-info-waves (nintendo-ware:sound-bank-info bank))) 0))))
        (assert (= 1.5f0 (nintendo-ware:bank-velocity-pitch velocity)))
        (assert (= 64 (nintendo-ware:bank-pan-flag-pan pan)))
        (assert (= 32 (nintendo-ware:bank-pan-flag-surround-pan pan)))
        (assert (= 4 (nintendo-ware:adshr-curve-hold (nintendo-ware:bank-velocity-envelope velocity)))))))
  (rejects nintendo-ware:invalid-file (nintendo-ware:read-file :sound-bank (bank-fixture #x6000 #x6000 1)))
  (let* ((first (wave-fixture 2))
         (second (wave-fixture 3))
         (table (encode-record 'sized-reference-table
                  (make-sized-reference-table :count 2
                   :entries (vector (make-sized-reference :type #x1f00 :offset 0 :size (length first))
                                    (make-sized-reference :type #x1f00 :offset (length first) :size (length second))))))
         (archive (nintendo-ware:read-file :wave-archive (container-fixture "CWAR"
                                        (list (list #x6800 "INFO" table) (list #x6801 "FILE" (octets-join first second))))))
         (entries (nintendo-ware:wave-archive-info-entries (nintendo-ware:wave-archive-info archive)))
         (first-wave (nintendo-ware:wave-archive-entry-content (aref entries 0)))
         (second-wave (nintendo-ware:wave-archive-entry-content (aref entries 1))))
    (assert (= -123 (aref (nintendo-ware:dsp-adpcm-info-coefficients
                           (nintendo-ware:sound-wave-channel-codec-info (aref (nintendo-ware:sound-wave-info-channels (nintendo-ware:sound-wave-info first-wave)) 0))) 15)))
    (assert (= -200 (nintendo-ware:ima-adpcm-context-predictor
                     (nintendo-ware:ima-adpcm-info-initial-context
                      (nintendo-ware:sound-wave-channel-codec-info (aref (nintendo-ware:sound-wave-info-channels (nintendo-ware:sound-wave-info second-wave)) 0)))))))
  (let* ((bytes (wave-fixture 2))
         (table (encode-record 'sized-reference-table
                  (make-sized-reference-table :count 1
                   :entries (vector (make-sized-reference :type #x1f00 :offset 0 :size (length bytes)))))))
    (rotatef (aref bytes 4) (aref bytes 5))
    (rejects nintendo-ware:invalid-file
      (nintendo-ware:read-file :wave-archive (container-fixture "CWAR"
                            (list (list #x6800 "INFO" table) (list #x6801 "FILE" bytes))))))
  (format t "Direct WAV/WAR/BNK graph scenarios passed.~%"))
