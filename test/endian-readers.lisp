(in-package #:cl-nintendo-ware.test)

;; A complete synthetic file tests the tail type after consuming a field,
;; rather than only at the beginning of a production section body.
(nintendo-ware::define-nintendo-ware-section (tail-probe-info (:magic "INFO"))
  (value 0 :type (unsigned-byte 32))
  (%size 0 :type nintendo-ware::nintendo-ware-section-tail-size)
  (tail #.(make-array 0 :element-type '(unsigned-byte 8))
        :type (simple-array (unsigned-byte 8) (%size))))

(nintendo-ware::define-nintendo-ware-file (tail-probe (:magic ("CTST" "FTST")))
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
               (sequence (nintendo-ware::read-file 'nintendo-ware::xseq (sequence-fixture payload)))
               (header (nintendo-ware::xseq-header sequence))
               (events (nintendo-ware::xseq-events sequence))
               (tempo (nintendo-ware::xseq-event-if-sub-event (aref events 0)))
               (random (aref events 1))
               (note (nintendo-ware::xseq-event-random-sub-event random)))
          (assert (eq endian (nintendo-ware::header-endian header)))
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
        (assert (eq endian (nintendo-ware::header-endian (nintendo-ware::xwar-header parsed))))
        (assert (eq child-endian (nintendo-ware::header-endian (nintendo-ware::xwav-header embedded))))
        (ecase codec
          (1 (assert (equalp #(-32768 -1 32767) (nintendo-ware::xwav-channel-data channel))))
          (2 (assert (= -123 (aref (nintendo-ware::xwav-dsp-adpcm-info-coefficients
                                    (nintendo-ware::xwav-channel-codec-info channel)) 0))))))))
  (assert (not (boundp 'nintendo-ware::*endian*)))
  (format t "Shared-type ME, C/F containers, event endian and mixed embedded files passed.~%"))
