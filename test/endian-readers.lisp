(in-package #:cl-nintendo-ware.test)

;; A complete synthetic file tests the tail type after consuming a field,
;; rather than only at the beginning of a production section body.
(nintendo-ware:define-nintendo-ware-section (tail-probe-info (:magic "INFO"))
  (value 0 :type (unsigned-byte 32))
  (%size 0 :type nintendo-ware:nintendo-ware-section-tail-size)
  (tail #.(make-array 0 :element-type '(unsigned-byte 8))
        :type (simple-array (unsigned-byte 8) (%size))))

(nintendo-ware:define-nintendo-ware-file (tail-probe (:magic ("CTST" "FTST")))
  (info nil :type (peek tail-probe-info (nintendo-ware::block-start nintendo-ware::header #x1000))))

(defbinio tail-probe (simple-array (unsigned-byte 8) (*)))

(defun run-endian-tests ()
  ;; Consumers see the same concrete classes in either byte order.
  (dolist (family '(:c :f))
    (dolist (endian '(:little :big))
      (let ((*fixture-family* family) (*fixture-endian* endian))
        (run-format-tests)
        (run-archive-tests)
        (let* ((tail #(20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1))
               (payload (octets-join (if (eq endian :little) #(4 3 2 1) #(1 2 3 4)) tail))
               (file (read-tail-probe
                       (coerce (container-fixture "CTST" (list (list #x1000 "INFO" payload)))
                               '(simple-array (unsigned-byte 8) (*)))))
               (info (tail-probe-info file)))
          (assert (= #x01020304 (tail-probe-info-value info)))
          (assert (equalp tail (tail-probe-info-tail info))))
        (let* ((little (and (eq family :f) (eq endian :little)))
               (payload (if little
                            #(162 225 44 1 160 60 100 244 255 12 0 240 128 3 254 255 240 172 5 255)
                            #(162 225 1 44 160 60 100 255 244 0 12 240 128 3 255 254 240 172 5 255)))
               (sequence (nintendo-ware:read-file :auto (sequence-fixture payload)))
               (header (nintendo-ware:sound-sequence-header sequence))
               (events (nintendo-ware:sound-sequence-events sequence))
               (tempo (nintendo-ware:sequence-event-if-sub-event (aref events 0)))
               (random (aref events 1))
               (note (nintendo-ware:sequence-event-random-sub-event random)))
          (assert (eq endian (nintendo-ware:header-endian header)))
          (assert (= 300 (nintendo-ware:sequence-event-tempo-value tempo)))
          (assert (= -12 (nintendo-ware:sequence-event-random-min random)))
          (assert (= 12 (nintendo-ware:sequence-event-random-max random)))
          (assert (= 60 (nintendo-ware:sequence-event-note-key note)))
          (assert (= 5 (nintendo-ware:sequence-event-mod4-curve-value (aref events 3))))
          (let* ((body (if little
                           #(136 2 11 0 0 162 138 11 0 0 255 137 10 0 0)
                           #(136 2 0 0 11 162 138 0 0 11 255 137 0 0 10)))
                 (flow (nintendo-ware:read-file :auto (sequence-fixture body :label-offset 11)))
                 (events (nintendo-ware:sound-sequence-events flow)))
            (assert (= 3 (nintendo-ware:sequence-event-open-track-index (aref events 0))))
            (assert (= 3 (nintendo-ware:sequence-event-call-index
                           (nintendo-ware:sequence-event-if-sub-event (aref events 1)))))
            (assert (= 2 (nintendo-ware:sequence-event-jump-index (aref events 3))))
            (assert (= 3 (nintendo-ware:label-entry-index
                           (aref (nintendo-ware:sound-sequence-labels-entries
                                   (nintendo-ware:sound-sequence-labels flow)) 0)))))
          (assert (= -2 (nintendo-ware:sequence-event-set-variable-value (aref events 2))))))))
  ;; Embedded headers never inherit their parent's endian or C/F identity.
  (dolist (endian '(:little :big))
    (let* ((child-endian (if (eq endian :little) :big :little))
           (wave (let ((*fixture-family* :c) (*fixture-endian* child-endian)) (wave-fixture 2)))
           (archive (let ((*fixture-family* :f) (*fixture-endian* endian))
                      (container-fixture "CWAR"
                        (list (list #x6800 "INFO"
                                    (encode-record 'sized-reference-table
                                      (make-sized-reference-table :count 1 :entries
                                       (vector (make-sized-reference :type #x1f00 :offset 0 :size (length wave))))))
                              (list #x6801 "FILE" wave)))))
           (parsed (nintendo-ware:read-file :auto archive))
           (entry (aref (nintendo-ware:wave-archive-info-entries (nintendo-ware:wave-archive-info parsed)) 0))
           (embedded (nintendo-ware:wave-archive-entry-content entry))
           (channel (aref (nintendo-ware:sound-wave-info-channels (nintendo-ware:sound-wave-info embedded)) 0))
           (coefficients (nintendo-ware:dsp-adpcm-info-coefficients (nintendo-ware:sound-wave-channel-codec-info channel))))
      (assert (eq endian (nintendo-ware:header-endian (nintendo-ware:wave-archive-header parsed))))
      (assert (eq child-endian (nintendo-ware:header-endian (nintendo-ware:sound-wave-header embedded))))
      (assert (= -123 (aref coefficients 0)))))
  (assert (not (boundp 'nintendo-ware:*endian*)))
  (format t "Shared-type ME, C/F containers, event endian and mixed embedded files passed.~%"))
