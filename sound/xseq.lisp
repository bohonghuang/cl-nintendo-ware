(in-package #:nintendo-ware)

(declaim (inline make-%vlq))
(defbinstruct %vlq ()
  (bytes #.(make-array 0 :element-type '(unsigned-byte 8))
         :type (simple-array (satisfies (unsigned-byte 8) (lambda (byte) (plusp (ldb (byte 1 7) byte)))) (*)))
  (byte 0 :type (unsigned-byte 8)))

(declaim (inline %vlq-integer))
(defun %vlq-integer (vlq)
  (declare (dynamic-extent vlq))
  (loop :with value :of-type (unsigned-byte 64) := (%vlq-byte vlq)
        :with bytes := (%vlq-bytes vlq)
        :for i :of-type (mod 8) :from 1 :to (length bytes)
        :do (setf (ldb (byte 7 (* i 7)) value) (ldb (byte 7 0) (aref bytes (- (length bytes) i))))
        :finally (return value)))

(defun integer-%vlq (value)
  (loop :for v :of-type (unsigned-byte 64) := (ash value -7) :then (ash v -7)
        :while (plusp v)
        :collect (logior #x80 (ldb (byte 7 0) v)) :into bytes
        :finally (return (make-%vlq :bytes (coerce (nreverse bytes) '(simple-array (unsigned-byte 8) (*)))
                                         :byte (ldb (byte 7 0) value)))))

(deftype vlq ()
  '(unsigned-byte 32))

(defbinalias vlq ()
  (map %vlq #'%vlq-integer #'integer-%vlq))

(defbinenum (xseq-mod-target (:type (unsigned-byte 8)) (:endian :little)) ()
  (pitch 0)
  (volume 1)
  (pan 2))

(defbinenum (xseq-mod-curve (:type (unsigned-byte 8)) (:endian :little)) ()
  (sine 0)
  (triangle 1)
  (sawtooth 2)
  (rectangular 3)
  (random 4)
  (none 5))

(defbinenum (xseq-mute-mode (:type (unsigned-byte 8)) (:endian :little)) ()
  (off 0)
  (no-stop 1)
  (release 2)
  (stop 3))

(defbinstruct/me xseq-event ())
(deftype xseq-event-union () 'xseq-event)
(deftype xseq-event-partial-union (&optional status) (declare (ignore status)) 'xseq-event)
(defbinstruct/me xseq-event-union)
(defbinstruct/me xseq-event-partial-union)

(defgeneric xseq-event-variable-value (event)
  (:documentation "Return the final field as raw u16 when fixed-size, or directly when variable-length."))
(defgeneric (setf xseq-event-variable-value) (value event)
  (:documentation "Assign the final field through its native reader when fixed-size, or directly when variable-length."))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defvar *xseq-events* nil)
  (defvar *xseq-event-variable-value-types* nil))

(defmacro define-xseq-event ((name event-bytes) &body fields)
  (let* ((class (symbolicate '#:xseq-event- name))
         (class-partial (symbolicate class '#:/partial))
         (last-field (car (last fields)))
         (variable-value-type (getf (cddr last-field) :type))
         (event-bytes (ensure-list event-bytes))
         (tags (if (eq name 'note)
                   '((key 0 :type (satisfies (unsigned-byte 8) (rcurry #'<= #x7f))))
                   (loop for byte in event-bytes collect
                     `(nil ,byte :type (satisfies (unsigned-byte 8) (curry #'eql ,byte)))))))
    (with-gensyms (status value event bytes)
      `(progn
         (defbinstruct/me (,class (:include xseq-event)) () ,@tags ,@fields)
         (defbinstruct/me (,class-partial (:type ,class)) (,status)
           ,@(if (eq name 'note)
                 `((key 0 :type (satisfies (map null (constantly ,status)) (lambda (key) (<= 0 key #x7f)))))
                 `((nil ,(first event-bytes) :type (satisfies (map null (constantly ,status))
                                                           (curry #'eql ,(first event-bytes))))))
           ,@(rest tags)
           ,@(if (and fields (subtypep (binstruct::lisp-type variable-value-type) 'xseq-event))
                 fields (butlast fields)))
         ,@(let* ((accessor (symbolicate class '- (first last-field)))
                  (reader (intern (format nil "~A-~A" 'read variable-value-type)))
                  (writer (intern (format nil "~A-~A" 'write variable-value-type)))
                  (parameters (remove-if-not #'symbolp (cdr (ensure-list variable-value-type)))))
             (multiple-value-bind (minimum maximum)
                 (ignore-errors
                  (parsonic::compute-bounds/compile
                   (parsonic::expand/compile (ensure-list variable-value-type))))
               (cond
                 ((not (and minimum maximum)) nil)
                 ((= minimum maximum)
                  `((eval-when (:compile-toplevel :load-toplevel :execute)
                      (pushnew ',variable-value-type *xseq-event-variable-value-types* :test #'equal))
                    (declaim (ftype (function ((simple-array (unsigned-byte 8) (*)) ,@(mapcar (constantly t) parameters)) (values t)) ,reader)
                             (ftype (function ((simple-array (unsigned-byte 8) (*)) t ,@(mapcar (constantly t) parameters)) (values (simple-array (unsigned-byte 8) (*)))) ,writer))
                    (defmethod xseq-event-variable-value ((,event ,class))
                      (let ((,bytes (make-array 2 :element-type '(unsigned-byte 8) :initial-element 0)))
                        (declare (dynamic-extent ,bytes))
                        (,writer ,bytes (,accessor ,event))
                        (logior (aref ,bytes 0) (ash (aref ,bytes 1) 8))))
                    (defmethod (setf xseq-event-variable-value) (,value (,event ,class))
                      (let ((,bytes (make-array 2 :element-type '(unsigned-byte 8))))
                        (declare (dynamic-extent ,bytes))
                        (setf (aref ,bytes 0) (ldb (byte 8 0) ,value)
                              (aref ,bytes 1) (ldb (byte 8 8) ,value))
                        (setf (,accessor ,event) (,reader ,bytes)))
                      ,value)))
                 (t `((defmethod xseq-event-variable-value ((,event ,class))
                        (,accessor ,event))
                      (defmethod (setf xseq-event-variable-value) (,value (,event ,class))
                        (setf (,accessor ,event) ,value)))))))
         (eval-when (:compile-toplevel :load-toplevel :execute)
           (pushnew ',class *xseq-events*))))))

(define-xseq-event (note #x00)
  (velocity 0 :type (unsigned-byte 8))
  (duration 0 :type vlq))

(define-xseq-event (wait #x80)
  (value 0 :type vlq))

(define-xseq-event (program-change #x81)
  (value 0 :type vlq))

(define-xseq-event (open-track #x88)
  (track 0 :type (unsigned-byte 8))
  (index 0 :type (unsigned-byte 24)))

(define-xseq-event (jump #x89)
  (index 0 :type (unsigned-byte 24)))

(define-xseq-event (call #x8a)
  (index 0 :type (unsigned-byte 24)))

(define-xseq-event (random #xa0)
  (%status 0 :type (unsigned-byte 8))
  (sub-event nil :type (xseq-event-partial-union %status))
  (min 0 :type (signed-byte 16))
  (max 0 :type (signed-byte 16)))

(define-xseq-event (variable #xa1)
  (%status 0 :type (unsigned-byte 8))
  (sub-event nil :type (xseq-event-partial-union %status))
  (variable 0 :type (unsigned-byte 8)))

(define-xseq-event (if #xa2)
  (sub-event nil :type xseq-event-union))

(define-xseq-event (time #xa3)
  (sub-event nil :type xseq-event-union)
  (value 0 :type (signed-byte 16)))

(define-xseq-event (time-random #xa4)
  (sub-event nil :type xseq-event-union)
  (min 0 :type (signed-byte 16))
  (max 0 :type (signed-byte 16)))

(define-xseq-event (time-variable #xa5)
  (sub-event nil :type xseq-event-union)
  (variable 0 :type (unsigned-byte 8)))

(define-xseq-event (timebase #xb0)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (env-hold #xb1)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (monophonic #xb2)
  (value nil :type (boolean (unsigned-byte 8))))

(define-xseq-event (velocity-range #xb3)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (biquad-type #xb4)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (biquad-value #xb5)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (bank-select #xb6)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod-phase #xbd)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod-curve #xbe)
  (value 'sine :type xseq-mod-curve))

(define-xseq-event (front-bypass #xbf)
  (value nil :type (boolean (unsigned-byte 8))))

(define-xseq-event (pan #xc0)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (volume #xc1)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (main-volume #xc2)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (transpose #xc3)
  (value 0 :type (signed-byte 8)))

(define-xseq-event (pitch-bend #xc4)
  (value 0 :type (signed-byte 8)))

(define-xseq-event (bend-range #xc5)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (priority #xc6)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (note-wait #xc7)
  (value nil :type (boolean (unsigned-byte 8))))

(define-xseq-event (tie #xc8)
  (value nil :type (boolean (unsigned-byte 8))))

(define-xseq-event (portamento #xc9)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod-depth #xca)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod-speed #xcb)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod-type #xcc)
  (value 'pitch :type xseq-mod-target))

(define-xseq-event (mod-range #xcd)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (portamento-switch #xce)
  (value nil :type (boolean (unsigned-byte 8))))

(define-xseq-event (portamento-time #xcf)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (attack #xd0)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (decay #xd1)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (sustain #xd2)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (release #xd3)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (loop-start #xd4)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (volume2 #xd5)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (print-variable #xd6)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (surround-pan #xd7)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (lpf-cutoff #xd8)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (fx-send-a #xd9)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (fx-send-b #xda)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (main-send #xdb)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (initial-pan #xdc)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mute #xdd)
  (value 'off :type xseq-mute-mode))

(define-xseq-event (fx-send-c #xde)
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (damper #xdf)
  (value nil :type (boolean (unsigned-byte 8))))

(define-xseq-event (mod-delay #xe0)
  (value 0 :type (signed-byte 16)))

(define-xseq-event (tempo #xe1)
  (value 0 :type (signed-byte 16)))

(define-xseq-event (sweep-pitch #xe3)
  (value 0 :type (signed-byte 16)))

(define-xseq-event (mod-period #xe4)
  (value 0 :type (signed-byte 16)))

(define-xseq-event (envelope-reset #xfb))

(define-xseq-event (loop-end #xfc))

(define-xseq-event (return #xfd))

(define-xseq-event (allocate-track #xfe)
  (value 0 :type (unsigned-byte 16)))

(define-xseq-event (finish #xff))

(define-xseq-event (set-variable (#xf0 #x80))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (add-variable (#xf0 #x81))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (subtract-variable (#xf0 #x82))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (multiply-variable (#xf0 #x83))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (divide-variable (#xf0 #x84))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (shift-variable (#xf0 #x85))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (random-variable (#xf0 #x86))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (and-variable (#xf0 #x87))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (or-variable (#xf0 #x88))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (xor-variable (#xf0 #x89))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (not-variable (#xf0 #x8a))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (modulo-variable (#xf0 #x8b))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (compare-equal (#xf0 #x90))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (compare-greater-equal (#xf0 #x91))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (compare-greater (#xf0 #x92))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (compare-less-equal (#xf0 #x93))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (compare-less (#xf0 #x94))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (compare-not-equal (#xf0 #x95))
  (variable 0 :type (unsigned-byte 8))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (mod2-curve (#xf0 #xa0))
  (value 'sine :type xseq-mod-curve))

(define-xseq-event (mod2-phase (#xf0 #xa1))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod2-depth (#xf0 #xa2))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod2-speed (#xf0 #xa3))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod2-type (#xf0 #xa4))
  (value 'pitch :type xseq-mod-target))

(define-xseq-event (mod2-range (#xf0 #xa5))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod3-curve (#xf0 #xa6))
  (value 'sine :type xseq-mod-curve))

(define-xseq-event (mod3-phase (#xf0 #xa7))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod3-depth (#xf0 #xa8))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod3-speed (#xf0 #xa9))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod3-type (#xf0 #xaa))
  (value 'pitch :type xseq-mod-target))

(define-xseq-event (mod3-range (#xf0 #xab))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod4-curve (#xf0 #xac))
  (value 'sine :type xseq-mod-curve))

(define-xseq-event (mod4-phase (#xf0 #xad))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod4-depth (#xf0 #xae))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod4-speed (#xf0 #xaf))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (mod4-type (#xf0 #xb0))
  (value 'pitch :type xseq-mod-target))

(define-xseq-event (mod4-range (#xf0 #xb1))
  (value 0 :type (unsigned-byte 8)))

(define-xseq-event (user-call (#xf0 #xe0))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (mod2-delay (#xf0 #xe1))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (mod2-period (#xf0 #xe2))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (mod3-delay (#xf0 #xe3))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (mod3-period (#xf0 #xe4))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (mod4-delay (#xf0 #xe5))
  (value 0 :type (signed-byte 16)))

(define-xseq-event (mod4-period (#xf0 #xe6))
  (value 0 :type (signed-byte 16)))

(defmacro defbinio-xseq-event-variable-value-types ()
  `(progn
     ,@(loop :for type :in *xseq-event-variable-value-types*
             :for name := (if (symbolp type) type (intern (princ-to-string type)))
             :for parameters := (remove-if-not #'symbolp (cdr (ensure-list type)))
             :unless (symbolp type)
               :collect `(defbinalias ,name ,parameters ,type)
             :collect `(defbinio (,name ,@parameters) (simple-array (unsigned-byte 8) (*))))))

(defbinio-xseq-event-variable-value-types)


(defmacro define-xseq-event-unions ()
  `(progn
     (defbinalias/me (xseq-event-union (:type xseq-event)) ()
       (or ,@(loop for type in *xseq-events* collect `(,type))))
     (defbinalias/me (xseq-event-partial-union (:type xseq-event)) (status)
       (or ,@(loop for type in *xseq-events*
                   collect `(,(symbolicate type '/partial) status))))))

(define-xseq-event-unions)

(defun xseq-event-child (event)
  (typecase event
    (xseq-event-random (xseq-event-random-sub-event event))
    (xseq-event-variable (xseq-event-variable-sub-event event))
    (xseq-event-if (xseq-event-if-sub-event event))
    (xseq-event-time (xseq-event-time-sub-event event))
    (xseq-event-time-random (xseq-event-time-random-sub-event event))
    (xseq-event-time-variable (xseq-event-time-variable-sub-event event))))

(defbinstruct/me (xseq-track-event (:type xseq-event) (:constructor progn) (:conc-name nil)) (end positions)
  (%start 0 :type (satisfies position (rcurry #'< end)))
  (values nil :type xseq-event-union)
  (nil 0 :type (map (satisfies position (rcurry #'<= end))
                   (lambda (position) (declare (ignore position)) (vector-push-extend %start positions)))))

(defbinstruct/me (xseq-track (:type (simple-array xseq-event (*))) (:constructor progn) (:conc-name nil)) (end labels)
  (%positions #() :type (map null (lambda (ignored) (declare (ignore ignored))
                                   (make-array 0 :element-type 'integer :adjustable t :fill-pointer 0))))
  (%events #() :type (simple-array (xseq-track-event end %positions) (*)))
  (%end 0 :type position)
  (nil #.(make-array 0 :element-type '(unsigned-byte 8))
       :type (simple-array (satisfies (unsigned-byte 8) #'zerop) ((- end %end))))
  (values #.(make-array 0 :element-type 'xseq-event)
          :type (map null (lambda (ignored) (declare (ignore ignored))
                            (xseq-events-unpack %events %positions labels)))))

;; The event stream's endian is independent of the surrounding section.
(defbinalias xseq-track/le (end labels) (xseq-track end labels))

(defbinstruct/me (xseq-label-event-reference (:type (or null (unsigned-byte 32)))
                  (:constructor progn) (:conc-name nil)) (indices)
  (%tag 0 :type (unsigned-byte 16))
  (nil 0 :type (unsigned-byte 16))
  (%offset -1 :type (satisfies (signed-byte 32)
                     (lambda (offset)
                       (and (<= -1 offset) (or (= offset -1) (= %tag #x1f00))))))
  (values nil :type (map null
                     (lambda (ignored)
                       (declare (ignore ignored))
                       (unless (= %offset -1)
                         (or (gethash %offset indices)
                             (error 'binstruct::deserialize-error
                                    :input nil :position nil :info "Invalid SEQ label")))))))

(defbinstruct/me xseq-label-entry (indices)
  (index 0 :type (xseq-label-event-reference indices))
  (length 0 :type (unsigned-byte 32))
  (name #.(coerce "" 'simple-base-string) :type (simple-base-string length))
  (nil 0 :type (satisfies (unsigned-byte 8))))

(define-nintendo-ware-reference xseq-label-reference (indices)
  (#x5100 (xseq-label-entry indices)))

(defbinstruct/me xseq-labels-record (indices)
  (%labels-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (xseq-label-reference %labels-start indices) (count))))

(defun resolve-xseq-event (event indices &optional partial)
  (flet ((index (offset)
           (or (gethash offset indices) (error 'binstruct::deserialize-error
                                               :input nil :position nil
                                               :info (format nil "SEQ target ~D is not an event boundary" offset)))))
    (unless partial
      (typecase event
        (xseq-event-open-track (setf (xseq-event-open-track-index event) (index (xseq-event-open-track-index event))))
        (xseq-event-jump (setf (xseq-event-jump-index event) (index (xseq-event-jump-index event))))
        (xseq-event-call (setf (xseq-event-call-index event) (index (xseq-event-call-index event))))))
    (let ((child (xseq-event-child event)))
      (when child (resolve-xseq-event child indices (typep event '(or xseq-event-random xseq-event-variable))))))
  event)

(defun xseq-events-unpack (events positions labels)
  (let* ((last (position-if (lambda (event) (typep event '(or xseq-event-finish xseq-event-return xseq-event-jump))) events :from-end t))
         (indices (make-hash-table)))
    (unless last (error 'binstruct::deserialize-error
                        :input nil :position nil
                        :info "SEQ has no terminating event"))
    (loop for index from (1+ last) below (length events)
          for event = (aref events index)
          unless (and (typep event 'xseq-event-note)
                      (zerop (xseq-event-note-key event))
                      (zerop (xseq-event-note-velocity event))
                      (zerop (xseq-event-note-duration event)))
            do (error 'binstruct::deserialize-error
                      :input nil :position nil
                      :info "Non-padding data after final SEQ event"))
    (let ((result (if (= (length events) (1+ last)) events (subseq events 0 (1+ last))))
          (base (aref positions 0)))
      (loop for index to last do (setf (gethash (- (aref positions index) base) indices) index))
      (loop for event across result do (resolve-xseq-event event indices))
      (values result (funcall labels indices)))))

(define-nintendo-ware-section (xseq-data (:magic "DATA"))
  (%size 0 :type nintendo-ware-tail-size)
  (bytes #.(make-array 0 :element-type '(unsigned-byte 8))
         :type (simple-array (unsigned-byte 8) (%size))))

(define-nintendo-ware-section (xseq-labels (:magic "LABL"))
  (%size 0 :type nintendo-ware-tail-size)
  (bytes #.(make-array 0 :element-type '(unsigned-byte 8))
         :type (simple-array (unsigned-byte 8) (%size))))

(define-nintendo-ware-file (xseq (:magic ("CSEQ" "FSEQ")))
  (data (make-xseq-data) :type xseq-data :tag #x5000)
  (labels (make-xseq-labels) :type xseq-labels :tag #x5001))

(defun xseq-contents (sequence)
  (let* ((data (xseq-data-body-bytes (xseq-data-body (xseq-data sequence))))
         (end (length data))
         (section (xseq-labels sequence))
         (label-data (when section (xseq-labels-body-bytes (xseq-labels-body section))))
         (entries nil))
    (flet ((decode-labels (indices)
             (when label-data
               (let ((record (ecase (nintendo-ware-file-endian sequence)
                               (:little (nintendo-ware-parse (xseq-labels-record indices) label-data))
                               (:big (nintendo-ware-parse (xseq-labels-record/be indices) label-data)))))
                 (setf entries (xseq-labels-record-entries record))))))
      (let ((events (if (and (string= (nintendo-ware-file-magic sequence) "FSEQ")
                             (eq (nintendo-ware-file-endian sequence) :little))
                        (nintendo-ware-parse (xseq-track/le end #'decode-labels) data)
                        (nintendo-ware-parse (xseq-track/be end #'decode-labels) data))))
        (values events entries)))))

(defun xseq-events (sequence)
  (nth-value 0 (xseq-contents sequence)))

(defun xseq-label-entries (sequence)
  (nth-value 1 (xseq-contents sequence)))

(defbinio xseq stream)

(defmethod read-file ((type (eql 'xseq)) (stream stream))
  (read-xseq stream))
