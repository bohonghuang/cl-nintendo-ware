(in-package #:cl-nintendo-ware)

(defbinstruct/me xwsd-envelope ()
  (attack 0 :type (unsigned-byte 8)) (decay 0 :type (unsigned-byte 8))
  (sustain 0 :type (unsigned-byte 8)) (hold 0 :type (unsigned-byte 8)) (release 0 :type (unsigned-byte 8)))

(defbinstruct/me xwsd-sends ()
  (main-send 0 :type (unsigned-byte 8))
  (count 0 :type (unsigned-byte 8))
  (auxiliary-sends #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (count))))

(defbinstruct/me xwsd-parameters (note-p base)
  (%start 0 :type position)
  (flags (make-flag-values) :type flag-values)
  (key-info nil :type (ecase (and note-p (logbitp 0 (flag-values-mask flags)))
                        ((nil) null) ((t) (peek xbnk-key-flag
                                               (flag-position flags 0 %start)))))
  (volume-info nil :type (ecase (and note-p (logbitp 1 (flag-values-mask flags)))
                           ((nil) null) ((t) (peek xbnk-volume-flag
                                                  (flag-position flags 1 %start)))))
  (pan-info nil :type (ecase (logbitp (if note-p 2 0) (flag-values-mask flags))
                        ((nil) null) ((t) (peek packed-pan
                                               (flag-position flags (if note-p 2 0) %start)))))
  (pitch nil :type (ecase (logbitp (if note-p 3 1) (flag-values-mask flags))
                     ((nil) null) ((t) (peek single-float (flag-position flags (if note-p 3 1) %start)))))
  (filter-info nil :type (ecase (logbitp (if note-p 4 2) (flag-values-mask flags))
                           ((nil) null) ((t) (peek packed-filter
                                                  (flag-position flags (if note-p 4 2) %start)))))
  ;; Item effects are relative to these flags; note effects include wave-index.
  (sends nil :type (ecase (not (null (flag-target flags 8 (if note-p base %start))))
                     ((nil) null) ((t) (peek xwsd-sends (flag-target flags 8 (if note-p base %start))))))
  (envelope nil :type (ecase (not (null (flag-target flags 9 (if note-p base %start))))
                        ((nil) null)
                        ((t) (peek (reference-to 0 (flag-target flags 9 (if note-p base %start)) (xwsd-envelope))
                                   (flag-target flags 9 (if note-p base %start)))))))

(defbinstruct/me xwsd-note ()
  (%start 0 :type position)
  (wave-index 0 :type (unsigned-byte 32))
  (parameters nil :type (xwsd-parameters t %start)))

(defbinstruct/me xwsd-event ()
  (position 0.0f0 :type single-float) (length 0.0f0 :type single-float)
  (note-index 0 :type (unsigned-byte 32)) (reserved 0 :type (unsigned-byte 32)))

(defbinstruct/me xwsd-event-table ()
  ($events-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4904 $events-start (xwsd-event)) (count))))

(defbinstruct/me xwsd-track ()
  ($track-start 0 :type position)
  (events nil :type (reference-to 0 $track-start xwsd-event-table)))

(defbinstruct/me xwsd-track-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4903 $table-start xwsd-track) (count))))

(defbinstruct/me xwsd-note-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4902 $table-start xwsd-note) (count))))

(defbinstruct/me xwsd-item ()
  ($item-start 0 :type position)
  (parameters nil :type (reference-to #x4901 $item-start (xwsd-parameters nil $item-start)))
  (tracks nil :type (reference-to #x0101 $item-start xwsd-track-table))
  (notes nil :type (reference-to #x0101 $item-start xwsd-note-table)))

(defbinstruct/me xwsd-item-table ()
  ($table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array (reference-to #x4900 $table-start xwsd-item) (count))))

(define-nintendo-ware-section (xwsd-info (:magic "INFO"))
  ($info-start 0 :type position)
  (waves nil :type (reference-to #x0100 $info-start wave-id-table))
  (items nil :type (reference-to #x0101 $info-start xwsd-item-table)))

(define-nintendo-ware-file (xwsd (:magic ("CWSD" "FWSD")))
  (%tag #x6800 :type (map null (lambda (ignored) (declare (ignore ignored)) (if (block-reference header #x6800 nil) #x6800 #x4800))))
  (info nil :type (peek xwsd-info (block-start header %tag))))

(export '(xwsd xwsd-header xwsd-info xwsd-info-waves xwsd-info-items xwsd-item-table-entries xwsd-item
          xwsd-item-parameters xwsd-item-tracks xwsd-item-notes xwsd-track-table-entries xwsd-note-table-entries
          xwsd-track xwsd-track-events xwsd-event-table-entries xwsd-event xwsd-event-position xwsd-event-length xwsd-event-note-index
          xwsd-note xwsd-note-wave-index xwsd-note-parameters xwsd-parameters xwsd-parameters-flags xwsd-parameters-pan-info
          xwsd-parameters-key-info xwsd-parameters-volume-info xwsd-parameters-pitch xwsd-parameters-filter-info
          xwsd-parameters-sends xwsd-parameters-envelope xwsd-envelope xwsd-envelope-release xwsd-sends xwsd-sends-main-send xwsd-sends-auxiliary-sends))
