(in-package #:nintendo-ware)

(defbinio embedded-file (simple-array (unsigned-byte 8) (*)))
(defbinio (sequence-command/le) stream)
(defbinio (sequence-command/be) stream)

(defun read-bcseq (stream)
  "Read one 3DS/Wii U sequence event (fixed big-endian operands)."
  (read-sequence-command/be stream))

(defun read-bfseq (stream)
  "Read one Switch sequence event (little-endian operands)."
  (read-sequence-command/le stream))

(defgeneric read-file (type input))

(defun requested-file-kind (type)
  (let* ((name (string-upcase (string type)))
         (symbol (find-symbol name :nintendo-ware)))
    (cond ((string= name "AUTO") :auto)
          ((member symbol '(sound-sequence sound-wave wave-archive sound-bank wave-sound-data sound-stream sound-archive sound-group))
           (intern name :keyword))
          ((and (= (length name) 5) (char= (char name 0) #\B))
           (magic-kind (subseq name 1)))
          (t (magic-kind name)))))

(defmethod read-file (type (input vector))
  (let* ((kind (requested-file-kind type))
         (bytes (coerce input '(simple-array (unsigned-byte 8) (*)))))
    (handler-case
        (let ((result (read-embedded-file bytes)))
          (unless (or (eq kind :auto) (eq kind (magic-kind (header-magic (nintendo-ware-file-header result)))))
            (fail-file "Requested ~S, got ~S" type (type-of result)))
          result)
      (binstruct::deserialize-error (condition) (fail-file "~A" condition)))))

(defmethod read-file (type (input stream))
  (read-file type (flexi-streams:with-output-to-sequence (output)
                    (uiop:copy-stream-to-stream input output :element-type '(unsigned-byte 8)))))

(defmethod read-file (type (input pathname))
  (with-open-file (stream input :element-type '(unsigned-byte 8)) (read-file type stream)))

(defmethod read-file (type (input string)) (read-file type (pathname input)))
