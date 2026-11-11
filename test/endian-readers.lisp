(in-package #:cl-nintendo-ware.test)

;; A complete synthetic file tests the tail type after consuming a field,
;; rather than only at the beginning of a production section body.
(nintendo-ware::define-nintendo-ware-section (tail-probe-info (:magic "INFO"))
  (value 0 :type (unsigned-byte 32))
  (%size 0 :type nintendo-ware::nintendo-ware-section-tail-size)
  (tail #.(make-array 0 :element-type '(unsigned-byte 8))
        :type (simple-array (unsigned-byte 8) (%size))))

(nintendo-ware::define-nintendo-ware-file (tail-probe (:magic ("CTST" "FTST")))
  (info nil :type (values (pointer tail-probe-info
                                  (map null (constantly (nintendo-ware::block-start nintendo-ware::%header #x1000)))))))

(defbinio tail-probe (simple-array (unsigned-byte 8) (*)))

(defun run-endian-tests ()
  ;; Consumers see the same concrete classes in either byte order.
  (dolist (family '(:c :f))
    (dolist (endian '(:little :big))
      (let ((*fixture-family* family) (*fixture-endian* endian))
        (run-format-tests)
        (run-archive-tests)
        ;; Complete readers consume trailing padding, stop at the owning file's
        ;; end and can start the next file at a nonzero stream position.
        (let* ((first (wave-fixture 0 :payloads '(#(1 2 3) #(4 5 6))))
               (second (wave-fixture 0 :payloads '(#(128 255 127) #(7 8 9))))
               (stream (flexi-streams:make-in-memory-input-stream (octets-join first second))))
          (unwind-protect
               (progn
                 (let ((wave (nintendo-ware::read-file 'nintendo-ware::xwav stream)))
                   (assert (equalp #(1 2 3)
                                   (nintendo-ware::xwav-channel-data
                                    (aref (nintendo-ware::xwav-info-channels
                                           (nintendo-ware::xwav-info wave)) 0)))))
                 (assert (= (length first) (file-position stream)))
                 (let ((wave (nintendo-ware::read-file 'nintendo-ware::xwav stream)))
                   (assert (equalp #(-128 -1 127)
                                   (nintendo-ware::xwav-channel-data
                                    (aref (nintendo-ware::xwav-info-channels
                                           (nintendo-ware::xwav-info wave)) 0)))))
                 (assert (= (+ (length first) (length second)) (file-position stream))))
            (close stream))
          (rejects error
            (nintendo-ware::read-file 'nintendo-ware::xwav
                                     (subseq first 0 (1- (length first))))))
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
               (sequence (nintendo-ware::read-file 'nintendo-ware::xseq (sequence-fixture payload)))
               (header (nintendo-ware::xseq-header sequence))
               (events (nintendo-ware::xseq-events sequence))
               (tempo (nintendo-ware::xseq-event-if-sub-event (aref events 0)))
               (random (aref events 1))
               (note (nintendo-ware::xseq-event-random-sub-event random)))
          (assert (eq endian (nintendo-ware::nintendo-ware-file-header-endian header)))
          (assert (= 300 (nintendo-ware::xseq-event-tempo-value tempo)))
          (assert (= -12 (nintendo-ware::xseq-event-random-min random)))
          (assert (= 12 (nintendo-ware::xseq-event-random-max random)))
          (assert (= 60 (nintendo-ware::xseq-event-note-key note)))
          (assert (eq 'nintendo-ware::none (nintendo-ware::xseq-event-mod4-curve-value (aref events 3))))
          (let* ((body (if little
                           #(136 2 11 0 0 162 138 11 0 0 255 137 10 0 0)
                           #(136 2 0 0 11 162 138 0 0 11 255 137 0 0 10)))
                 (flow (nintendo-ware::read-file 'nintendo-ware::xseq (sequence-fixture body :label-offset 11)))
                 (events (nintendo-ware::xseq-events flow)))
            (assert (= 3 (nintendo-ware::xseq-event-open-track-index (aref events 0))))
            (assert (= 3 (nintendo-ware::xseq-event-call-index
                           (nintendo-ware::xseq-event-if-sub-event (aref events 1)))))
            (assert (= 2 (nintendo-ware::xseq-event-jump-index (aref events 3))))
            (assert (= 3 (nintendo-ware::xseq-label-entry-index
                           (aref (nintendo-ware::xseq-labels-entries
                                   (nintendo-ware::xseq-labels flow)) 0)))))
          (assert (= -2 (nintendo-ware::xseq-event-set-variable-value (aref events 2))))))))
  ;; Embedded headers never inherit their parent's endian or C/F identity.
  (dolist (endian '(:little :big))
    (dolist (codec '(1 2))
      (let* ((child-endian (if (eq endian :little) :big :little))
             (wave (let ((*fixture-family* :c) (*fixture-endian* child-endian))
                     (wave-fixture codec :payloads
                       (when (= codec 1)
                         (let ((bytes (if (eq child-endian :little)
                                          #(0 #x80 #xff #xff #xff #x7f)
                                          #(#x80 0 #xff #xff #x7f #xff))))
                           (list bytes bytes))))))
             (archive (let ((*fixture-family* :f) (*fixture-endian* endian))
                        (container-fixture "CWAR"
                          (list (list #x6800 "INFO"
                                      (encode-record 'sized-reference-table
                                        (make-sized-reference-table :count 1 :entries
                                         (vector (make-sized-reference :type #x1f00 :offset 0 :size (length wave))))))
                                (list #x6801 "FILE" wave)))))
             (parsed (nintendo-ware::read-file 'nintendo-ware::xwar archive))
             (embedded (aref (nintendo-ware::xwar-waves parsed) 0))
             (channel (aref (nintendo-ware::xwav-info-channels (nintendo-ware::xwav-info embedded)) 0)))
        (assert (eq endian (nintendo-ware::nintendo-ware-file-header-endian (nintendo-ware::xwar-header parsed))))
        (assert (eq child-endian (nintendo-ware::nintendo-ware-file-header-endian (nintendo-ware::xwav-header embedded))))
        (ecase codec
          (1 (assert (equalp #(-32768 -1 32767) (nintendo-ware::xwav-channel-data channel))))
          (2 (assert (= -123 (aref (nintendo-ware::xwav-dsp-adpcm-info-coefficients
                                    (nintendo-ware::xwav-channel-codec-info channel)) 0))))))))
  ;; File IDs select raw entries. Each explicitly selected child reads its BOM.
  (dolist (endian '(:little :big))
    (let* ((child-endian (if (eq endian :little) :big :little))
           (sequence (let ((*fixture-family* :c) (*fixture-endian* :little))
                       (sequence-fixture #(60 100 12 #xff))))
           (child (let ((*fixture-family* :c) (*fixture-endian* child-endian))
                    (xgrp-fixture sequence)))
           (bytes (let ((*fixture-family* :f) (*fixture-endian* endian))
                    (xgrp-fixture child)))
           (group (nintendo-ware::read-file 'nintendo-ware::xgrp bytes))
           (entry (find 7 (nintendo-ware::xgrp-info-entries (nintendo-ware::xgrp-info group))
                        :key #'nintendo-ware::xgrp-entry-file-id))
           (nested (nintendo-ware::read-file 'nintendo-ware::xgrp (nintendo-ware::xgrp-entry-data entry)))
           (nested-entry (find 7 (nintendo-ware::xgrp-info-entries (nintendo-ware::xgrp-info nested))
                               :key #'nintendo-ware::xgrp-entry-file-id))
           (parsed-sequence (nintendo-ware::read-file 'nintendo-ware::xseq
                                                    (nintendo-ware::xgrp-entry-data nested-entry))))
      (assert (eq endian (nintendo-ware::nintendo-ware-file-header-endian (nintendo-ware::xgrp-header group))))
      (assert (eq child-endian (nintendo-ware::nintendo-ware-file-header-endian (nintendo-ware::xgrp-header nested))))
      (assert (= 12 (nintendo-ware::xseq-event-note-duration
                      (aref (nintendo-ware::xseq-events parsed-sequence) 0))))
      (dolist (container (list group nested))
        (assert (= #x03000000
                   (nintendo-ware::nintendo-ware-sound-resource-id-value
                    (nintendo-ware::xgrp-dependency-resource-id
                     (aref (nintendo-ware::xgrp-infx-entries (nintendo-ware::xgrp-infx container)) 0))))))))
  (assert (not (boundp 'nintendo-ware::*endian*)))
  (format t "Shared-type ME, C/F containers, event endian and mixed embedded files passed.~%"))
