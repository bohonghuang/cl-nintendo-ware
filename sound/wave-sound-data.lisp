(in-package #:cl-nintendo-ware)

(defbinstruct/me wave-sound-data-envelope ()
  (attack 0 :type (unsigned-byte 8)) (decay 0 :type (unsigned-byte 8))
  (sustain 0 :type (unsigned-byte 8)) (hold 0 :type (unsigned-byte 8)) (release 0 :type (unsigned-byte 8)))

(defbinstruct/me wave-sound-data-sends ()
  (main-send 0 :type (unsigned-byte 8))
  (count 0 :type (unsigned-byte 8))
  (auxiliary-sends #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (count))))

(defbinstruct/me wave-sound-data-parameters (note-p base)
  (%start 0 :type position)
  (flags (make-flag-values) :type flag-values)
  (key-info nil :type (ecase (and note-p (logbitp 0 (flag-values-mask flags)))
                        ((nil) null) ((t) (peek bank-key-flag
                                               (flag-position flags 0 %start)))))
  (volume-info nil :type (ecase (and note-p (logbitp 1 (flag-values-mask flags)))
                           ((nil) null) ((t) (peek bank-volume-flag
                                                  (flag-position flags 1 %start)))))
  (pan-info nil :type (ecase (logbitp (if note-p 2 0) (flag-values-mask flags))
                        ((nil) null) ((t) (peek packed-pan
                                               (flag-position flags (if note-p 2 0) %start)))))
  (pitch nil :type (ecase (logbitp (if note-p 3 1) (flag-values-mask flags))
                     ((nil) null) ((t) (peek single-float (flag-position flags (if note-p 3 1) %start)))))
  (filter-info nil :type (ecase (logbitp (if note-p 4 2) (flag-values-mask flags))
                           ((nil) null) ((t) (peek packed-filter
                                                  (flag-position flags (if note-p 4 2) %start)))))
  (sends nil :type (ecase (not (null (flag-target flags 8 base)))
                     ((nil) null) ((t) (peek wave-sound-data-sends (flag-target flags 8 base)))))
  (envelope nil :type (ecase (not (null (flag-target flags 9 base)))
                        ((nil) null)
                        ((t) (peek (reference-to 0 (flag-target flags 9 base) (wave-sound-data-envelope))
                                   (flag-target flags 9 base))))))

(defbinstruct/me wave-sound-data-note ()
  (%start 0 :type position)
  (wave-index 0 :type (unsigned-byte 32))
  (parameters nil :type (wave-sound-data-parameters t %start)))

(defbinstruct/me wave-sound-data-event ()
  (position 0.0f0 :type single-float) (length 0.0f0 :type single-float)
  (note-index 0 :type (unsigned-byte 32)) (reserved 0 :type (unsigned-byte 32)))

(defbinstruct/me wave-sound-data-event-table ()
  ($events-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4904 $events-start (wave-sound-data-event)) (count))))

(defbinstruct/me wave-sound-data-track ()
  ($track-start 0 :type position)
  (events nil :type (reference-to 0 $track-start wave-sound-data-event-table)))

(defbinstruct/me wave-sound-data-track-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4903 $table-start wave-sound-data-track) (count))))

(defbinstruct/me wave-sound-data-note-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4902 $table-start wave-sound-data-note) (count))))

(defbinstruct/me wave-sound-data-item ()
  ($item-start 0 :type position)
  (parameters nil :type (reference-to #x4901 $item-start (wave-sound-data-parameters nil $item-start)))
  (tracks nil :type (reference-to #x0101 $item-start wave-sound-data-track-table))
  (notes nil :type (reference-to #x0101 $item-start wave-sound-data-note-table)))

(defbinstruct/me wave-sound-data-item-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4900 $table-start wave-sound-data-item) (count))))

(define-nintendo-ware-section (wave-sound-data-info (:magic "INFO"))
  ($info-start 0 :type position)
  (waves nil :type (reference-to #x0100 $info-start wave-id-table))
  (items nil :type (reference-to #x0101 $info-start wave-sound-data-item-table)))

(define-nintendo-ware-file (wave-sound-data (:magic ("CWSD" "FWSD")))
  (%tag #x6800 :type (map null (lambda (ignored) (declare (ignore ignored)) (if (block-reference header #x6800 nil) #x6800 #x4800))))
  (info nil :type (peek wave-sound-data-info (block-start header %tag))))

(export '(wave-sound-data wave-sound-data-header wave-sound-data-info wave-sound-data-info-waves wave-sound-data-info-items wave-sound-data-item-table-entries wave-sound-data-item
          wave-sound-data-item-parameters wave-sound-data-item-tracks wave-sound-data-item-notes wave-sound-data-track-table-entries wave-sound-data-note-table-entries
          wave-sound-data-track wave-sound-data-track-events wave-sound-data-event-table-entries wave-sound-data-event wave-sound-data-event-position wave-sound-data-event-length wave-sound-data-event-note-index
          wave-sound-data-note wave-sound-data-note-wave-index wave-sound-data-note-parameters wave-sound-data-parameters wave-sound-data-parameters-flags wave-sound-data-parameters-pan-info
          wave-sound-data-parameters-key-info wave-sound-data-parameters-volume-info wave-sound-data-parameters-pitch wave-sound-data-parameters-filter-info
          wave-sound-data-parameters-sends wave-sound-data-parameters-envelope wave-sound-data-envelope wave-sound-data-envelope-release wave-sound-data-sends wave-sound-data-sends-main-send wave-sound-data-sends-auxiliary-sends))
