(in-package #:cl-nintendo-ware.test)

(nintendo-ware:defbinstruct/me reader-leaf
  (value 0 :type (unsigned-byte 16)))

(nintendo-ware:defbinstruct/me reader-nested
  (first (make-reader-leaf) :type reader-leaf)
  (count 0 :type (unsigned-byte 16))
  (entries #() :type (simple-array reader-leaf (count))))

(nintendo-ware:defbinstruct/me reader-pointer
  (target nil :type (nintendo-ware::reference-to #x1234 0
                     (nintendo-ware::bounded 10 2 (reader-leaf)))))

(defbinio (reader-nested) (simple-array (unsigned-byte 8) (*)))
(defbinio (reader-nested/le) (simple-array (unsigned-byte 8) (*)))
(defbinio (reader-nested/be) (simple-array (unsigned-byte 8) (*)))
(defbinio (reader-pointer/le) (simple-array (unsigned-byte 8) (*)))
(defbinio (reader-pointer/be) (simple-array (unsigned-byte 8) (*)))

(defun reader-octets (bytes)
  (coerce bytes '(simple-array (unsigned-byte 8) (*))))

(defun run-endian-tests ()
  (let* ((little (reader-octets #(52 18 2 0 120 86 188 154)))
         (big (reader-octets #(18 52 0 2 86 120 154 188)))
         (default (read-reader-nested little))
         (le (read-reader-nested/le little))
         (be (read-reader-nested/be big)))
    (assert (equalp default le))
    (assert (equalp le be))
    (assert (eq 'reader-nested (type-of be)))
    (assert (eq 'reader-leaf (type-of (reader-nested-first be))))
    (assert (= #x1234 (reader-leaf-value (reader-nested-first be))))
    (assert (= #x9abc (reader-leaf-value (aref (reader-nested-entries be) 1)))))
  (let* ((little (read-reader-pointer/le (reader-octets #(52 18 0 0 8 0 0 0 103 69))))
         (big (read-reader-pointer/be (reader-octets #(18 52 0 0 0 0 0 8 69 103))))
         (target (reader-pointer-target little)))
    (assert (= #x4567 (reader-leaf-value target)))
    (assert (equalp little big)))
  (assert (null (reader-pointer-target
                 (read-reader-pointer/be (reader-octets #(0 0 0 0 255 255 255 255))))))
  (rejects binstruct::deserialize-error
    (read-reader-pointer/be (reader-octets #(18 53 0 0 0 0 0 8 69 103))))
  (rejects binstruct::deserialize-error
    (read-reader-pointer/be (reader-octets #(18 52 0 0 255 255 255 254 69 103))))
  (rejects nintendo-ware:invalid-file
    (read-reader-pointer/be (reader-octets #(18 52 0 0 0 0 0 9 69 103 0))))
  ;; Both event entry points share the same command type and opcode table.
  (flet ((event (reader bytes)
           (funcall reader (flexi-streams:make-in-memory-input-stream (reader-octets bytes)))))
    (let* ((big (event #'nintendo-ware:read-bcseq #(162 225 1 44)))
           (little (event #'nintendo-ware:read-bfseq #(162 225 44 1)))
           (big-inner (nintendo-ware:sequence-command-nested big))
           (little-inner (nintendo-ware:sequence-command-nested little)))
      (assert (eq :if (nintendo-ware:sequence-command-name big)))
      (assert (eq :tempo (nintendo-ware:sequence-command-name little-inner)))
      (assert (= 300 (nintendo-ware:sequence-command-arguments big-inner)))
      (assert (= 300 (nintendo-ware:sequence-command-arguments little-inner))))
    (let* ((big (event #'nintendo-ware:read-bcseq #(240 128 2 255 244)))
           (little (event #'nintendo-ware:read-bfseq #(240 128 2 244 255)))
           (big-args (nintendo-ware:sequence-command-arguments big))
           (little-args (nintendo-ware:sequence-command-arguments little)))
      (assert (= -12 (nintendo-ware:variable-arguments-value big-args)))
      (assert (= -12 (nintendo-ware:variable-arguments-value little-args))))
    (let* ((big (event #'nintendo-ware:read-bcseq #(136 3 18 52 171)))
           (little (event #'nintendo-ware:read-bfseq #(136 3 171 52 18)))
           (big-args (nintendo-ware:sequence-command-arguments big))
           (little-args (nintendo-ware:sequence-command-arguments little)))
      (assert (= 3 (nintendo-ware:track-arguments-track big-args)))
      (assert (= #x1234ab (nintendo-ware:track-arguments-target big-args)))
      (assert (= #x1234ab (nintendo-ware:track-arguments-target little-args))))
    (let ((newer (event #'nintendo-ware:read-bcseq #(240 172 5))))
      (assert (eq :mod4-curve (nintendo-ware:sequence-command-name newer)))
      (assert (= 5 (nintendo-ware:sequence-command-arguments newer)))))
  (dolist (family '(:c :f))
    (dolist (endian '(:little :big))
      (let ((*fixture-family* family) (*fixture-endian* endian))
        (run-format-tests)
        (run-archive-tests)
        (let* ((payload (if (and (eq family :f) (eq endian :little)) #(225 44 1 255) #(225 1 44 255)))
               (sequence (nintendo-ware:read-file :auto (sequence-fixture payload)))
               (header (nintendo-ware:sound-sequence-header sequence))
               (command (nintendo-ware:read-command sequence 0)))
          (assert (eq endian (nintendo-ware:header-endian header)))
          (assert (= 1 (nintendo-ware:header-version-major header)))
          (assert (= 300 (nintendo-ware:sequence-command-arguments command)))))))
  ;; Embedded headers never inherit their parent's endian or C/F identity.
  (let* ((wave (let ((*fixture-family* :c) (*fixture-endian* :little)) (wave-fixture 2)))
         (archive (let ((*fixture-family* :f) (*fixture-endian* :big))
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
    (assert (eq :big (nintendo-ware:header-endian (nintendo-ware:wave-archive-header parsed))))
    (assert (eq :little (nintendo-ware:header-endian (nintendo-ware:sound-wave-header embedded))))
    (assert (= -123 (aref coefficients 0))))
  (let ((sequence (sequence-fixture #(255))))
    (rejects nintendo-ware:invalid-file
      (nintendo-ware:read-file :auto (sound-group-fixture sequence :declared-size (1- (length sequence))))))
  (assert (not (boundp 'nintendo-ware:*endian*)))
  (format t "Shared-type ME, bounded pointers, C/F containers, event endian and mixed embedded files passed.~%"))
