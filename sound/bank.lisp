(in-package #:cl-nintendo-ware)

(defbinstruct/me adshr-curve ()
  (attack 127 :type (satisfies (signed-byte 8) (lambda (value) (not (minusp value)))))
  (decay 127 :type (satisfies (signed-byte 8) (lambda (value) (not (minusp value)))))
  (sustain 127 :type (satisfies (signed-byte 8) (lambda (value) (not (minusp value)))))
  (hold 127 :type (satisfies (signed-byte 8) (lambda (value) (not (minusp value)))))
  (release 127 :type (satisfies (signed-byte 8) (lambda (value) (not (minusp value)))))
  (padding (make-array 3 :element-type '(unsigned-byte 8) :initial-element 0)
           :type (simple-array (unsigned-byte 8) (3))))

(defbinstruct bank-key-flag ()
  (value 60 :type (signed-byte 8))
  (nil 0 :type (unsigned-byte 24)))

(defbinstruct (bank-key-flag/be (:type bank-key-flag) (:endian :big)) ()
  (nil 0 :type (unsigned-byte 24))
  (value 60 :type (signed-byte 8)))

(defbinalias bank-key-flag/le () bank-key-flag)
(%define-endian-reader bank-key-flag)

(defbinstruct bank-volume-flag ()
  (value 127 :type (unsigned-byte 8))
  (nil 0 :type (unsigned-byte 24)))

(defbinstruct (bank-volume-flag/be (:type bank-volume-flag) (:endian :big)) ()
  (nil 0 :type (unsigned-byte 24))
  (value 127 :type (unsigned-byte 8)))

(defbinalias bank-volume-flag/le () bank-volume-flag)
(%define-endian-reader bank-volume-flag)

(defbinstruct bank-pan-flag ()
  (pan 64 :type (signed-byte 8))
  (surround-pan 0 :type (signed-byte 8))
  (nil 0 :type (unsigned-byte 16)))

(defbinstruct (bank-pan-flag/be (:type bank-pan-flag) (:endian :big)) ()
  (nil 0 :type (unsigned-byte 16))
  (surround-pan 0 :type (signed-byte 8))
  (pan 64 :type (signed-byte 8)))

(defbinalias bank-pan-flag/le () bank-pan-flag)
(%define-endian-reader bank-pan-flag)

(defbinstruct bank-note-flag ()
  (percussion 0 :type (unsigned-byte 8))
  (key-group 0 :type (unsigned-byte 8))
  (interpolation-type 0 :type (unsigned-byte 8))
  (nil 0 :type (unsigned-byte 8)))

(defbinstruct (bank-note-flag/be (:type bank-note-flag) (:endian :big)) ()
  (nil 0 :type (unsigned-byte 8))
  (interpolation-type 0 :type (unsigned-byte 8))
  (key-group 0 :type (unsigned-byte 8))
  (percussion 0 :type (unsigned-byte 8)))

(defbinalias bank-note-flag/le () bank-note-flag)
(%define-endian-reader bank-note-flag)

(defbinstruct/me bank-velocity (upper wave-count)
  (%start 0 :type position)
  (wave-index 0 :type (satisfies (unsigned-byte 32) (lambda (index) (< index wave-count))))
  (%flags-start 0 :type position)
  (flags (make-flag-values) :type (flag-values upper))
  (key-info nil :type (ecase (logbitp 0 (flag-values-mask flags))
                        ((nil) null)
                        ((t) (peek bank-key-flag
                                   (flag-position flags 0 %flags-start)))))
  (volume-info nil :type (ecase (logbitp 1 (flag-values-mask flags))
                        ((nil) null)
                        ((t) (peek bank-volume-flag
                                   (flag-position flags 1 %flags-start)))))
  (pan-info nil :type (ecase (logbitp 2 (flag-values-mask flags))
                        ((nil) null)
                        ((t) (peek bank-pan-flag
                                   (flag-position flags 2 %flags-start)))))
  (note-info nil :type (ecase (logbitp 4 (flag-values-mask flags))
                        ((nil) null)
                        ((t) (peek bank-note-flag
                                   (flag-position flags 4 %flags-start)))))
  (pitch nil :type (ecase (logbitp 3 (flag-values-mask flags))
                     ((nil) null) ((t) (peek single-float (flag-position flags 3 %flags-start)))))
  (envelope nil :type (ecase (not (null (flag-target flags 9 %start 0 upper)))
                        ((nil) null)
                        ((t) (peek (reference-to 0 (flag-target flags 9 %start 0 upper) (bounded upper 8 (adshr-curve)))
                                   (flag-target flags 9 %start 0 upper))))))

(defbinstruct/me bank-velocity-direct (upper wave-count)
  ($table-start 0 :type position)
  (entry nil :type (reference-to #x5902 $table-start (bounded upper 8 (bank-velocity upper wave-count)))))

(defbinstruct/me bank-velocity-index (upper wave-count)
  ($table-start 0 :type position)
  (count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (and (<= count 128) (<= (+ $table-start 4 count (mod (- count) 4) (* 8 count)) upper)))))
  (upper-bounds #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (count)))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((mod (- count) 4))))
  (entries #() :type (simple-array (reference-to #x5902 $table-start (bounded upper 8 (bank-velocity upper wave-count))) (count))))

(defbinstruct/me bank-velocity-range (upper wave-count)
  ($table-start 0 :type position)
  (minimum 0 :type (unsigned-byte 8))
  (maximum 0 :type (satisfies (unsigned-byte 8) (lambda (maximum) (and (<= minimum maximum 127) (<= (+ $table-start 4 (* 8 (1+ (- maximum minimum)))) upper)))))
  (padding 0 :type (unsigned-byte 16))
  (entries #() :type (simple-array (reference-to #x5902 $table-start (bounded upper 8 (bank-velocity upper wave-count))) ((1+ (- maximum minimum))))))

(defbinstruct/me bank-key (upper wave-count)
  (%start 0 :type position)
  (reference (make-reference) :type reference)
  (definition nil :type (ecase (= (reference-offset reference) -1)
                          ((t) null)
                          ((nil) (ecase (reference-type reference)
                                   (#x6000 (peek (bank-velocity-direct upper wave-count)
                                                 (reference-target reference %start 0 upper #x6000 8)))
                                   (#x6001 (peek (bank-velocity-index upper wave-count)
                                                 (reference-target reference %start 0 upper #x6001 4)))
                                   (#x6002 (peek (bank-velocity-range upper wave-count)
                                                 (reference-target reference %start 0 upper #x6002 4))))))))

(defbinstruct/me bank-key-direct (upper wave-count)
  ($table-start 0 :type position)
  (entry nil :type (reference-to #x5901 $table-start (bounded upper 8 (bank-key upper wave-count)))))

(defbinstruct/me bank-key-index (upper wave-count)
  ($table-start 0 :type position)
  (count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (and (<= count 128) (<= (+ $table-start 4 count (mod (- count) 4) (* 8 count)) upper)))))
  (upper-bounds #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (count)))
  (padding #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((mod (- count) 4))))
  (entries #() :type (simple-array (reference-to #x5901 $table-start (bounded upper 8 (bank-key upper wave-count))) (count))))

(defbinstruct/me bank-key-range (upper wave-count)
  ($table-start 0 :type position)
  (minimum 0 :type (unsigned-byte 8))
  (maximum 0 :type (satisfies (unsigned-byte 8) (lambda (maximum) (and (<= minimum maximum 127) (<= (+ $table-start 4 (* 8 (1+ (- maximum minimum)))) upper)))))
  (padding 0 :type (unsigned-byte 16))
  (entries #() :type (simple-array (reference-to #x5901 $table-start (bounded upper 8 (bank-key upper wave-count))) ((1+ (- maximum minimum))))))

(defbinstruct/me bank-instrument (upper wave-count)
  (%start 0 :type position)
  (reference (make-reference) :type reference)
  (definition nil :type (ecase (= (reference-offset reference) -1)
                          ((t) null)
                          ((nil) (ecase (reference-type reference)
                                   (#x6000 (peek (bank-key-direct upper wave-count)
                                                 (reference-target reference %start 0 upper #x6000 8)))
                                   (#x6001 (peek (bank-key-index upper wave-count)
                                                 (reference-target reference %start 0 upper #x6001 4)))
                                   (#x6002 (peek (bank-key-range upper wave-count)
                                                 (reference-target reference %start 0 upper #x6002 4))))))))

(defbinstruct/me bank-instrument-table (upper wave-count)
  ($table-start 0 :type position)
  (count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (<= (+ $table-start 4 (* 8 count)) upper))))
  (entries #() :type (simple-array (reference-to #x5900 $table-start (bounded upper 8 (bank-instrument upper wave-count))) (count))))

(define-nintendo-ware-section (sound-bank-info (:magic "INFO"))
  ($info-start 0 :type position)
  (waves-reference (make-reference) :type reference)
  (instruments-reference (make-reference) :type reference)
  (waves nil :type (ecase (= (reference-offset waves-reference) -1)
                     ((t) null)
                     ((nil) (peek (wave-id-table %upper)
                                  (reference-target waves-reference $info-start %section-start %upper #x0100 4)))))
  (instruments nil :type (ecase (= (reference-offset instruments-reference) -1)
                           ((t) null)
                           ((nil) (peek (bank-instrument-table %upper (if waves (wave-id-table-count waves) 0))
                                        (reference-target instruments-reference $info-start %section-start %upper #x0101 4))))))

(define-nintendo-ware-file (sound-bank (:magic ("CBNK" "FBNK")))
  (info nil :type (peek sound-bank-info (block-start header #x5800))))

(export '(sound-bank sound-bank-header sound-bank-info sound-bank-info-waves sound-bank-info-instruments bank-instrument-table-entries
          bank-instrument bank-instrument-reference bank-instrument-definition bank-key bank-key-reference bank-key-definition
          bank-key-direct bank-key-direct-entry bank-key-index bank-key-index-upper-bounds bank-key-index-entries
          bank-key-range bank-key-range-minimum bank-key-range-maximum bank-key-range-entries
          bank-velocity-direct bank-velocity-direct-entry bank-velocity-index bank-velocity-index-upper-bounds bank-velocity-index-entries
          bank-velocity-range bank-velocity-range-minimum bank-velocity-range-maximum bank-velocity-range-entries
          bank-velocity bank-velocity-wave-index bank-velocity-flags bank-velocity-key-info bank-velocity-volume-info
          bank-velocity-pan-info bank-velocity-note-info bank-velocity-pitch bank-velocity-envelope
          bank-pan-flag-pan bank-pan-flag-surround-pan
          adshr-curve adshr-curve-attack adshr-curve-decay adshr-curve-sustain adshr-curve-hold adshr-curve-release))
