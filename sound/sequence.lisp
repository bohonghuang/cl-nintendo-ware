(in-package #:nintendo-ware)

(defbinstruct (vlq-group (:endian :big)) ()
  (part 0 :type (unsigned-byte 7))
  (continued nil :type (boolean (unsigned-byte 1))))
(defbinstruct (vlq-final-group (:type vlq-group) (:endian :big)) ()
  (part 0 :type (unsigned-byte 7))
  (continued nil :type (satisfies (boolean (unsigned-byte 1)))))
(defbinstruct %sequence-vlq ()
  (first (make-vlq-group) :type vlq-group)
  (second nil :type (ecase (vlq-group-continued first) ((nil) null) (t vlq-group)))
  (third nil :type (ecase (and second (vlq-group-continued second)) ((nil) null) (t vlq-group)))
  (fourth nil :type (ecase (and third (vlq-group-continued third)) ((nil) null) (t vlq-final-group))))
(defbinalias (sequence-vlq (:type (unsigned-byte 28))) ()
  (map %sequence-vlq
       (lambda (groups)
         (let ((value (vlq-group-part (%sequence-vlq-first groups))))
           (when (%sequence-vlq-second groups)
             (setf value (+ (* value 128) (vlq-group-part (%sequence-vlq-second groups)))))
           (when (%sequence-vlq-third groups)
             (setf value (+ (* value 128) (vlq-group-part (%sequence-vlq-third groups)))))
           (when (%sequence-vlq-fourth groups)
             (setf value (+ (* value 128) (vlq-group-part (%sequence-vlq-fourth groups)))))
           value))))

(defbinstruct/me sequence-event ())
(deftype sequence-event-union () 'sequence-event)
(deftype sequence-event-partial-union (&optional status) (declare (ignore status)) 'sequence-event)
(deftype sequence-extended-event-union () 'sequence-event)
(deftype sequence-extended-event-partial-union (&optional status) (declare (ignore status)) 'sequence-event)
(%define-endian-reader sequence-event-union)
(%define-endian-reader sequence-event-partial-union)
(%define-endian-reader sequence-extended-event-union)
(%define-endian-reader sequence-extended-event-partial-union)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defvar *sequence-events* nil)
  (defvar *sequence-extended-events* nil))

(defmacro define-sequence-event ((name status &optional extended) &body fields)
  (let* ((class (alexandria:symbolicate 'sequence-event- name))
         (partial (alexandria:symbolicate class '/partial))
         (registry (if extended '*sequence-extended-events* '*sequence-events*)))
    (destructuring-bind (start &optional (end start)) (alexandria:ensure-list status)
      (alexandria:with-gensyms (arg byte)
        `(progn
           (defbinstruct/me (,class (:include sequence-event)) ()
             (,(when (/= start end) 'key) ,start
              :type (satisfies (unsigned-byte 8)
                              ,(if (= start end) `(alexandria:curry #'eql ,start)
                                   `(lambda (,byte) (<= ,start ,byte ,end)))))
             ,@fields)
           (defbinstruct/me (,partial (:type ,class)) (,arg)
             (,(when (/= start end) 'key) ,start :type (map null (constantly ,arg)))
             ,@(if (and fields (subtypep (binstruct::lisp-type (getf (cddr (car (last fields))) :type)) 'sequence-event))
                   fields (butlast fields)))
           (eval-when (:compile-toplevel :load-toplevel :execute)
             (loop for code from ,start to ,end do (setf (alexandria:assoc-value ,registry code) ',class)))
           (export '(,class ,(alexandria:symbolicate 'make- class)
                     ,(alexandria:symbolicate class '-p)
                     ,@(loop for field in fields unless (or (null (car field))
                                                           (char= (char (symbol-name (car field)) 0) #\%))
                             collect (alexandria:symbolicate class '- (car field)))
                     ,@(when (/= start end) (list (alexandria:symbolicate class '-key))))))))))

(define-sequence-event (note (#x00 #x7f))
  (velocity 0 :type (unsigned-byte 8))
  (duration 0 :type sequence-vlq))

(define-sequence-event (wait #x80)
  (value 0 :type sequence-vlq))

(define-sequence-event (program-change #x81)
  (value 0 :type sequence-vlq))

(define-sequence-event (open-track #x88)
  (track 0 :type (unsigned-byte 8))
  (index 0 :type (unsigned-byte 24)))

(define-sequence-event (jump #x89)
  (index 0 :type (unsigned-byte 24)))

(define-sequence-event (call #x8a)
  (index 0 :type (unsigned-byte 24)))

(define-sequence-event (random #xa0)
  (%status 0 :type (unsigned-byte 8))
  (sub-event nil :type (sequence-event-partial-union %status))
  (min 0 :type (signed-byte 16))
  (max 0 :type (signed-byte 16)))

(define-sequence-event (variable #xa1)
  (%status 0 :type (unsigned-byte 8))
  (sub-event nil :type (sequence-event-partial-union %status))
  (variable 0 :type (unsigned-byte 8)))

(define-sequence-event (if #xa2)
  (sub-event nil :type sequence-event-union))

(define-sequence-event (time #xa3)
  (sub-event nil :type sequence-event-union)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (time-random #xa4)
  (sub-event nil :type sequence-event-union)
  (min 0 :type (signed-byte 16))
  (max 0 :type (signed-byte 16)))

(define-sequence-event (time-variable #xa5)
  (sub-event nil :type sequence-event-union)
  (variable 0 :type (unsigned-byte 8)))

(define-sequence-event (timebase #xb0)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (env-hold #xb1)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (monophonic #xb2)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (velocity-range #xb3)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (biquad-type #xb4)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (biquad-value #xb5)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (bank-select #xb6)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod-phase #xbd)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod-curve #xbe)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (front-bypass #xbf)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (pan #xc0)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (volume #xc1)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (main-volume #xc2)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (transpose #xc3)
  (value 0 :type (signed-byte 8)))

(define-sequence-event (pitch-bend #xc4)
  (value 0 :type (signed-byte 8)))

(define-sequence-event (bend-range #xc5)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (priority #xc6)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (note-wait #xc7)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (tie #xc8)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (portamento #xc9)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod-depth #xca)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod-speed #xcb)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod-type #xcc)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod-range #xcd)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (portamento-switch #xce)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (portamento-time #xcf)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (attack #xd0)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (decay #xd1)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (sustain #xd2)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (release #xd3)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (loop-start #xd4)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (volume2 #xd5)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (print-variable #xd6)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (surround-pan #xd7)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (lpf-cutoff #xd8)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (fx-send-a #xd9)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (fx-send-b #xda)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (main-send #xdb)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (initial-pan #xdc)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mute #xdd)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (fx-send-c #xde)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (damper #xdf)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod-delay #xe0)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (tempo #xe1)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (sweep-pitch #xe3)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (mod-period #xe4)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (envelope-reset #xfb))

(define-sequence-event (loop-end #xfc))

(define-sequence-event (return #xfd))

(define-sequence-event (allocate-track #xfe)
  (value 0 :type (unsigned-byte 16)))

(define-sequence-event (finish #xff))

(define-sequence-event (set-variable #x80 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (add-variable #x81 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (subtract-variable #x82 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (multiply-variable #x83 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (divide-variable #x84 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (shift-variable #x85 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (random-variable #x86 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (and-variable #x87 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (or-variable #x88 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (xor-variable #x89 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (not-variable #x8a t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (modulo-variable #x8b t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (compare-equal #x90 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (compare-greater-equal #x91 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (compare-greater #x92 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (compare-less-equal #x93 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (compare-less #x94 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (compare-not-equal #x95 t)
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-sequence-event (mod2-curve #xa0 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod2-phase #xa1 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod2-depth #xa2 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod2-speed #xa3 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod2-type #xa4 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod2-range #xa5 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod3-curve #xa6 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod3-phase #xa7 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod3-depth #xa8 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod3-speed #xa9 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod3-type #xaa t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod3-range #xab t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod4-curve #xac t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod4-phase #xad t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod4-depth #xae t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod4-speed #xaf t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod4-type #xb0 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (mod4-range #xb1 t)
  (value 0 :type (unsigned-byte 8)))

(define-sequence-event (user-call #xe0 t)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (mod2-delay #xe1 t)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (mod2-period #xe2 t)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (mod3-delay #xe3 t)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (mod3-period #xe4 t)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (mod4-delay #xe5 t)
  (value 0 :type (signed-byte 16)))

(define-sequence-event (mod4-period #xe6 t)
  (value 0 :type (signed-byte 16)))

;; F0 is a wire envelope, not a separate consumer-visible event.
(defbinstruct/me (sequence-event-extended (:type sequence-event) (:constructor progn) (:conc-name nil)) ()
  (nil #xf0 :type (satisfies (unsigned-byte 8) (alexandria:curry #'eql #xf0)))
  (values nil :type sequence-extended-event-union))
(defbinstruct/me (sequence-event-extended/partial (:type sequence-event) (:constructor progn) (:conc-name nil)) (status)
  (%status 0 :type (unsigned-byte 8))
  (values nil :type (sequence-extended-event-partial-union %status)))

(defmacro define-sequence-event-unions ()
  `(progn
     (defbinstruct/me (sequence-event-union (:type sequence-event) (:constructor progn) (:conc-name nil)) ()
       (values nil :type (or ,@(mapcar (lambda (type) (list type))
                                      (delete-duplicates (mapcar #'cdr *sequence-events*)))
                             (sequence-event-extended))))
     (defbinstruct/me (sequence-extended-event-union (:type sequence-event) (:constructor progn) (:conc-name nil)) ()
       (values nil :type (or ,@(mapcar (lambda (type) (list type))
                                      (delete-duplicates (mapcar #'cdr *sequence-extended-events*))))))
     ,@(loop for (name registry) in '((sequence-event-partial-union *sequence-events*)
                                      (sequence-extended-event-partial-union *sequence-extended-events*))
             collect `(defbinstruct/me (,name (:type sequence-event) (:constructor progn) (:conc-name nil)) (status)
                        (values nil :type
                                (ecase ,(if (eq name 'sequence-event-partial-union) '(max status #x7f) 'status)
                                  ,@(loop for (code . type) in (symbol-value registry)
                                          unless (< code #x7f)
                                          collect `((,code) (,(alexandria:symbolicate type '/partial) status)))
                                  ,@(when (eq name 'sequence-event-partial-union)
                                      '(((#xf0) (sequence-event-extended/partial status))))))))))
(define-sequence-event-unions)

;; These walkers operate on semantic events; binary positions stay local to
;; the reader and are discarded after resolving references.
(defun sequence-event-child (event)
  (typecase event
    (sequence-event-random (sequence-event-random-sub-event event))
    (sequence-event-variable (sequence-event-variable-sub-event event))
    (sequence-event-if (sequence-event-if-sub-event event))
    (sequence-event-time (sequence-event-time-sub-event event))
    (sequence-event-time-random (sequence-event-time-random-sub-event event))
    (sequence-event-time-variable (sequence-event-time-variable-sub-event event))))


(defun resolve-sequence-event (event indices &optional partial)
  (flet ((index (offset)
           (or (gethash offset indices) (fail-file "SEQ target ~D is not an event boundary" offset))))
    (unless partial
      (typecase event
        (sequence-event-open-track (setf (sequence-event-open-track-index event) (index (sequence-event-open-track-index event))))
        (sequence-event-jump (setf (sequence-event-jump-index event) (index (sequence-event-jump-index event))))
        (sequence-event-call (setf (sequence-event-call-index event) (index (sequence-event-call-index event))))))
    (let ((child (sequence-event-child event)))
      (when child (resolve-sequence-event child indices (typep event '(or sequence-event-random sequence-event-variable))))))
  event)

(defun sequence-events-unpack (events positions labels)
  (let* ((last (position-if (lambda (event) (typep event '(or sequence-event-finish sequence-event-return sequence-event-jump))) events :from-end t))
         (indices (make-hash-table)))
    (unless last (fail-file "SEQ has no terminating event"))
    (loop for index from (1+ last) below (length events)
          for event = (aref events index)
          unless (and (typep event 'sequence-event-note)
                      (zerop (sequence-event-note-key event))
                      (zerop (sequence-event-note-velocity event))
                      (zerop (sequence-event-note-duration event)))
            do (fail-file "Non-padding data after final SEQ event"))
    (let ((result (if (= (length events) (1+ last)) events (subseq events 0 (1+ last))))
          (base (aref positions 0)))
      (loop for index to last do (setf (gethash (- (aref positions index) base) indices) index))
      (loop for event across result do (resolve-sequence-event event indices))
      (loop for label across labels when label
            do (setf (label-entry-index label)
                     (or (gethash (label-entry-index label) indices) (fail-file "Invalid SEQ label"))))
      result)))

(defbinstruct/me (sequence-track-event (:type sequence-event) (:constructor progn) (:conc-name nil)) (end positions)
  (%start 0 :type (satisfies position (lambda (position) (< position end))))
  (values nil :type sequence-event-union)
  (nil 0 :type (map (satisfies position (lambda (position) (<= position end)))
                   (lambda (position) (declare (ignore position)) (vector-push-extend %start positions)))))

(defbinstruct/me (sequence-track (:type (simple-array sequence-event (*))) (:constructor progn) (:conc-name nil)) (end labels)
  (%positions #() :type (map null (lambda (ignored) (declare (ignore ignored))
                                   (make-array 0 :element-type 'integer :adjustable t :fill-pointer 0))))
  (%events #() :type (simple-array (sequence-track-event end %positions) (*)))
  (%end 0 :type position)
  (nil #.(make-array 0 :element-type '(unsigned-byte 8))
       :type (simple-array (satisfies (unsigned-byte 8) #'zerop) ((- end %end))))
  (values #.(make-array 0 :element-type 'sequence-event)
          :type (map null (lambda (ignored) (declare (ignore ignored))
                            (sequence-events-unpack %events %positions labels)))))

(defbinstruct/me label-entry (data-size upper)
  (%start 0 :type position)
  (index 0 :type (map (satisfies reference
                                 (lambda (reference) (reference-target reference 0 0 data-size #x1f00)))
                      #'reference-offset))
  (length 0 :type (satisfies (unsigned-byte 32) (lambda (length) (<= (+ %start 13 length) upper))))
  (name #.(coerce "" 'simple-base-string) :type (simple-base-string length))
  (nil 0 :type (satisfies (unsigned-byte 8))))

(define-nintendo-ware-section (sound-sequence-labels (:magic "LABL")) (upper data-size)
  ($labels-start 0 :type position)
  (count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (<= (+ $labels-start 4 (* 8 count)) upper))))
  (entries #() :type (simple-array (reference-to #x5100 $labels-start (bounded upper 13 (label-entry data-size upper))) (count))))

(define-nintendo-ware-section (sound-sequence-data (:magic "DATA")) (upper little labels)
  (events #.(make-array 0 :element-type 'sequence-event)
          :type (ecase little
                  ((t) (sequence-track/le upper labels))
                  ((nil) (sequence-track/be upper labels)))))

(define-nintendo-ware-file (sound-sequence (:magic ("CSEQ" "FSEQ")))
  (labels nil :type (peek (sound-sequence-labels (block-end header #x5001) (- (block-end header #x5000) (block-start header #x5000) 8))
                          (block-start header #x5001)))
  (data nil :type (peek (sound-sequence-data (block-end header #x5000)
                                           (and (string= (header-magic header) "FSEQ") (eq (header-endian header) :little))
                                           (sound-sequence-labels-entries labels))
                        (block-start header #x5000))))

(defun sound-sequence-events (sequence)
  (sound-sequence-data-events (sound-sequence-data sequence)))

(export '(sequence-event sequence-event-child sound-sequence-events
          sound-sequence sound-sequence-header sound-sequence-data sound-sequence-labels
          sound-sequence-data-events sound-sequence-labels-entries label-entry label-entry-name label-entry-index))
