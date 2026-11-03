(in-package #:cl-nintendo-ware)

(defbinstruct/me label-entry (data-size upper)
  (%start 0 :type position)
  (target (make-reference) :type (satisfies reference
                                          (lambda (reference) (reference-target reference 0 0 data-size #x1f00))))
  (length 0 :type (satisfies (unsigned-byte 32) (lambda (length) (<= (+ %start 13 length) upper))))
  (name #.(coerce "" 'simple-base-string) :type (simple-base-string length))
  (nil 0 :type (satisfies (unsigned-byte 8))))

(define-nintendo-ware-section (sound-sequence-data (:magic "DATA"))
    (upper)
  (bytes #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- size 8)))))

(define-nintendo-ware-section (sound-sequence-labels (:magic "LABL"))
    (upper data-size)
  ($labels-start 0 :type position)
  (count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (<= (+ $labels-start 4 (* 8 count)) upper))))
  (entries #() :type (simple-array (reference-to #x5100 $labels-start (bounded upper 13 (label-entry data-size upper))) (count))))

(define-nintendo-ware-file (sound-sequence (:magic ("CSEQ" "FSEQ")))
  (data nil :type (peek (sound-sequence-data (block-end header #x5000)) (block-start header #x5000)))
  (labels nil :type (peek (sound-sequence-labels (block-end header #x5001) (length (sound-sequence-data-bytes data))) (block-start header #x5001))))

(defbinstruct (vlq-group (:endian :big)) ()
  (part 0 :type (unsigned-byte 7))
  (continued nil :type (boolean (unsigned-byte 1))))

(defbinstruct (vlq-final-group (:endian :big)) ()
  (part 0 :type (unsigned-byte 7))
  (continued nil :type (satisfies (boolean (unsigned-byte 1)))))

(defbinstruct (sequence-vlq (:endian :big)) ()
  (first (make-vlq-group) :type vlq-group)
  (second nil :type (ecase (vlq-group-continued first) ((nil) null) (t vlq-group)))
  (third nil :type (ecase (and second (vlq-group-continued second)) ((nil) null) (t vlq-group)))
  (fourth nil :type (ecase (and third (vlq-group-continued third)) ((nil) null) (t vlq-final-group)))
  (value 0 :type (map null
                     (lambda (ignored)
                       (declare (ignore ignored))
                       (let ((value (vlq-group-part first)))
                         (when second (setf value (+ (* value 128) (vlq-group-part second))))
                         (when third (setf value (+ (* value 128) (vlq-group-part third))))
                         (when fourth (setf value (+ (* value 128) (vlq-final-group-part fourth))))
                         value)))))

(define-condition unknown-opcode (invalid-file)
  ((offset :initarg :offset :reader unknown-opcode-offset)
   (raw-bytes :initarg :raw-bytes :reader unknown-opcode-raw-bytes)))

(defparameter *command-descriptions*
  '((#x80 :wait :vlq) (#x81 :program-change :vlq)
    (#x88 :open-track :track) (#x89 :jump :address) (#x8a :call :address)
    (#xa0 :random :prefix) (#xa1 :variable :prefix) (#xa2 :if :prefix)
    (#xa3 :time :prefix) (#xa4 :time-random :prefix) (#xa5 :time-variable :prefix)
    (#xb0 :timebase :u8) (#xb1 :env-hold :u8) (#xb2 :monophonic :u8)
    (#xb3 :velocity-range :u8) (#xb4 :biquad-type :u8) (#xb5 :biquad-value :u8)
    (#xb6 :bank-select :u8) (#xbd :mod-phase :u8) (#xbe :mod-curve :u8) (#xbf :front-bypass :u8)
    (#xc0 :pan :u8) (#xc1 :volume :u8) (#xc2 :main-volume :u8)
    (#xc3 :transpose :s8) (#xc4 :pitch-bend :s8) (#xc5 :bend-range :u8)
    (#xc6 :priority :u8) (#xc7 :note-wait :u8) (#xc8 :tie :u8) (#xc9 :portamento :u8)
    (#xca :mod-depth :u8) (#xcb :mod-speed :u8) (#xcc :mod-type :u8)
    (#xcd :mod-range :u8) (#xce :portamento-switch :u8) (#xcf :portamento-time :u8)
    (#xd0 :attack :u8) (#xd1 :decay :u8) (#xd2 :sustain :u8) (#xd3 :release :u8)
    (#xd4 :loop-start :u8) (#xd5 :volume2 :u8) (#xd6 :print-variable :u8)
    (#xd7 :surround-pan :u8) (#xd8 :lpf-cutoff :u8) (#xd9 :fx-send-a :u8)
    (#xda :fx-send-b :u8) (#xdb :main-send :u8) (#xdc :initial-pan :u8)
    (#xdd :mute :u8) (#xde :fx-send-c :u8) (#xdf :damper :u8)
    (#xe0 :mod-delay :s16) (#xe1 :tempo :s16) (#xe3 :sweep-pitch :s16) (#xe4 :mod-period :s16)
    (#xf0 :extended :extended) (#xfb :envelope-reset :none) (#xfc :loop-end :none)
    (#xfd :return :none) (#xfe :allocate-track :u16) (#xff :finish :none)))

(defparameter *extended-command-descriptions*
  '((#x80 :set-variable :variable) (#x81 :add-variable :variable)
    (#x82 :subtract-variable :variable) (#x83 :multiply-variable :variable)
    (#x84 :divide-variable :variable) (#x85 :shift-variable :variable)
    (#x86 :random-variable :variable) (#x87 :and-variable :variable)
    (#x88 :or-variable :variable) (#x89 :xor-variable :variable)
    (#x8a :not-variable :variable) (#x8b :modulo-variable :variable)
    (#x90 :compare-equal :variable) (#x91 :compare-greater-equal :variable)
    (#x92 :compare-greater :variable) (#x93 :compare-less-equal :variable)
    (#x94 :compare-less :variable) (#x95 :compare-not-equal :variable)
    (#xa0 :mod2-curve :u8) (#xa1 :mod2-phase :u8) (#xa2 :mod2-depth :u8)
    (#xa3 :mod2-speed :u8) (#xa4 :mod2-type :u8) (#xa5 :mod2-range :u8)
    (#xa6 :mod3-curve :u8) (#xa7 :mod3-phase :u8) (#xa8 :mod3-depth :u8)
    (#xa9 :mod3-speed :u8) (#xaa :mod3-type :u8) (#xab :mod3-range :u8)
    (#xac :mod4-curve :u8) (#xad :mod4-phase :u8) (#xae :mod4-depth :u8)
    (#xaf :mod4-speed :u8) (#xb0 :mod4-type :u8) (#xb1 :mod4-range :u8)
    (#xe0 :user-call :s16) (#xe1 :mod2-delay :s16) (#xe2 :mod2-period :s16)
    (#xe3 :mod3-delay :s16) (#xe4 :mod3-period :s16)
    (#xe5 :mod4-delay :s16) (#xe6 :mod4-period :s16)))

(defbinstruct/me note-arguments (reduced)
  (velocity 0 :type (unsigned-byte 8))
  (duration nil :type (ecase reduced ((nil) sequence-vlq) ((t) null))))

(defbinstruct/me track-arguments (reduced)
  (track 0 :type (unsigned-byte 8))
  (target nil :type (ecase reduced ((nil) (unsigned-byte 24)) ((t) null))))

(defbinstruct/me variable-arguments (reduced)
  (variable 0 :type (unsigned-byte 8))
  (value nil :type (ecase reduced ((nil) (signed-byte 16)) ((t) null))))

(defbinstruct/me random-arguments ()
  (minimum 0 :type (signed-byte 16))
  (maximum 0 :type (signed-byte 16)))

(defun find-command-description (opcode extension position base)
  (or (if extension (assoc extension *extended-command-descriptions*)
          (if (< opcode #x80) '(0 :note :note)
              (assoc opcode *command-descriptions*)))
      (error 'unknown-opcode
             :reason (format nil "unknown opcode at ~D" (- position base))
             :offset (- position base)
             :raw-bytes (if extension (vector opcode extension) (vector opcode)))))

;; Prefix commands recursively use the same reader variant.
(%define-endian-reader sequence-command)
(defbinstruct/me sequence-command (&optional (base 0) reduced (depth 0))
  ($command-start 0 :type position)
  (opcode 0 :type (satisfies (unsigned-byte 8)
                           (lambda (opcode)
                             (declare (ignore opcode))
                             (when (>= depth 64) (fail-file "sequence prefixes exceed 64 levels"))
                             t)))
  (extension nil :type (ecase (= opcode #xf0) ((nil) null) ((t) (unsigned-byte 8))))
  (%description nil :type (map null (lambda (ignored)
                                     (declare (ignore ignored))
                                     (find-command-description opcode extension $command-start base))))
  (name :note :type (map null (lambda (ignored) (declare (ignore ignored)) (second %description))))
  (shape :note :type (map null (lambda (ignored) (declare (ignore ignored)) (third %description))))
  (nested nil :type (map (ecase (eq shape :prefix)
                          ((nil) null)
                          ((t) (sequence-command base (not (null (member opcode '(#xa0 #xa1)))) (1+ depth))))
                        (the (function (t) (or null sequence-command)) #'identity)))
  (arguments nil :type (ecase shape
                         (:note (note-arguments reduced))
                         (:track (track-arguments reduced))
                         (:variable (variable-arguments reduced))
                         (:prefix (ecase opcode
                                    ((#xa0 #xa4) random-arguments)
                                    ((#xa1 #xa5) (unsigned-byte 8))
                                    (#xa2 null)
                                    (#xa3 (signed-byte 16))))
                         (:none null)
                         (:vlq (ecase reduced ((nil) sequence-vlq) ((t) null)))
                         (:u8 (ecase reduced ((nil) (unsigned-byte 8)) ((t) null)))
                         (:s8 (ecase reduced ((nil) (signed-byte 8)) ((t) null)))
                         (:u16 (ecase reduced ((nil) (unsigned-byte 16)) ((t) null)))
                         (:s16 (ecase reduced ((nil) (signed-byte 16)) ((t) null)))
                         (:address (ecase reduced ((nil) (unsigned-byte 24)) ((t) null)))))
  ($command-end 0 :type position)
  (offset 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (- $command-start base))))
  (next-offset 0 :type (map null (lambda (ignored) (declare (ignore ignored)) (- $command-end base))))
  (raw-bytes #() :type (peek (simple-array (unsigned-byte 8) ((- $command-end $command-start))) $command-start)))



(defun read-command (sequence offset)
  (let* ((header (sound-sequence-header sequence))
         (bytes (sound-sequence-data-bytes (sound-sequence-data sequence)))
         (stream (flexi-streams:make-in-memory-input-stream bytes)))
    (check-span offset 1 0 (length bytes))
    (file-position stream offset)
    (handler-case
        (if (and (char= (char (header-magic header) 0) #\F) (eq (header-endian header) :little))
            (read-sequence-command/le stream)
            (read-sequence-command/be stream))
      (binstruct::deserialize-error (condition) (fail-file "~A" condition)))))


(export '(sound-sequence sound-sequence-header sound-sequence-data sound-sequence-labels sound-sequence-data-bytes sound-sequence-labels-entries label-entry label-entry-name label-entry-target
          read-command read-bcseq read-bfseq sequence-command sequence-command-offset sequence-command-opcode sequence-command-extension
          sequence-command-name sequence-command-shape sequence-command-nested sequence-command-arguments
          sequence-command-next-offset sequence-command-raw-bytes note-arguments note-arguments-velocity note-arguments-duration
          track-arguments track-arguments-track track-arguments-target variable-arguments variable-arguments-variable variable-arguments-value
          random-arguments random-arguments-minimum random-arguments-maximum sequence-vlq sequence-vlq-value
          unknown-opcode unknown-opcode-offset unknown-opcode-raw-bytes))
