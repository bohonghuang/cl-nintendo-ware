(in-package #:cl-nintendo-ware)

(defbinstruct/me (xwsd-packed-pan (:alignment 4)) ()
  (pan 0 :type (signed-byte 8))
  (surround-pan 0 :type (signed-byte 8))
  (reserved 0 :type (unsigned-byte 16)))

(defbinstruct/me (xwsd-packed-filter (:alignment 4)) ()
  (low-pass 0 :type (unsigned-byte 8))
  (biquad-type 0 :type (unsigned-byte 8))
  (biquad-value 0 :type (unsigned-byte 8))
  (reserved 0 :type (unsigned-byte 8)))

(defbinstruct/me xwsd-envelope ()
  (attack 0 :type (unsigned-byte 8)) (decay 0 :type (unsigned-byte 8))
  (sustain 0 :type (unsigned-byte 8)) (hold 0 :type (unsigned-byte 8)) (release 0 :type (unsigned-byte 8)))

(defbinstruct/me xwsd-sends ()
  (main-send 0 :type (unsigned-byte 8))
  (count 0 :type (unsigned-byte 8))
  (auxiliary-sends #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (count))))

(defbinstruct/me (xwsd-item-flags (:alignment 4)) ()
  (pan-info-p nil :type (boolean bit))
  (pitch-p nil :type (boolean bit))
  (filter-info-p nil :type (boolean bit))
  (reserved-3-7 0 :type (unsigned-byte 5))
  (sends-offset-p nil :type (boolean bit))
  (envelope-offset-p nil :type (boolean bit))
  (reserved-10-31 0 :type (unsigned-byte 22)))

(defbinstruct/me (xwsd-note-flags (:alignment 4)) ()
  (key-info-p nil :type (boolean bit))
  (volume-info-p nil :type (boolean bit))
  (pan-info-p nil :type (boolean bit))
  (pitch-p nil :type (boolean bit))
  (filter-info-p nil :type (boolean bit))
  (reserved-5-7 0 :type (unsigned-byte 3))
  (sends-offset-p nil :type (boolean bit))
  (envelope-offset-p nil :type (boolean bit))
  (reserved-10-31 0 :type (unsigned-byte 22)))

(defbinstruct/me (xwsd-envelope-reference (:type (or null xwsd-envelope))
                                                (:constructor progn) (:conc-name nil)) ()
  (%xwsd-envelope-start 0 :type position)
  (values nil :type (or nintendo-ware-null-reference
                        (values (pointer (map xwsd-envelope
                                              (the (function (t) (or null xwsd-envelope)) #'identity))
                                         (nintendo-ware-reference-offset-value 0)
                                         %xwsd-envelope-start)))))

(defbinstruct/me xwsd-parameters (note-p)
  (%xwsd-parameters-start 0 :type position)
  (flags nil :type (ecase note-p
                    ((nil) xwsd-item-flags) ((t) xwsd-note-flags)))
  (key-info nil :type (ecase (and note-p (xwsd-note-flags-key-info-p flags))
                        ((nil) null) ((t) xbnk-key-flag)))
  (volume-info nil :type (ecase (and note-p (xwsd-note-flags-volume-info-p flags))
                        ((nil) null) ((t) xbnk-volume-flag)))
  (pan-info nil :type (ecase (if note-p (xwsd-note-flags-pan-info-p flags) (xwsd-item-flags-pan-info-p flags))
                        ((nil) null) ((t) xwsd-packed-pan)))
  (pitch nil :type (ecase (if note-p (xwsd-note-flags-pitch-p flags) (xwsd-item-flags-pitch-p flags))
                        ((nil) null) ((t) single-float)))
  (filter-info nil :type (ecase (if note-p (xwsd-note-flags-filter-info-p flags) (xwsd-item-flags-filter-info-p flags))
                        ((nil) null) ((t) xwsd-packed-filter)))
  (reserved-low-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32)
            ((logcount (if note-p (xwsd-note-flags-reserved-5-7 flags)
                                 (xwsd-item-flags-reserved-3-7 flags))))))
  (sends-offset nil :type (ecase (if note-p (xwsd-note-flags-sends-offset-p flags) (xwsd-item-flags-sends-offset-p flags))
                        ((nil) null) ((t) (unsigned-byte 32))))
  (envelope-offset nil :type (ecase (if note-p (xwsd-note-flags-envelope-offset-p flags) (xwsd-item-flags-envelope-offset-p flags))
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-high-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32)
            ((logcount (if note-p (xwsd-note-flags-reserved-10-31 flags)
                                 (xwsd-item-flags-reserved-10-31 flags))))))
  ;; Item effects use the flags base; note effects include wave-index.
  (sends nil :type (ecase (and sends-offset (/= sends-offset #xffffffff))
                    ((nil) null)
                    ((t) (ecase note-p
                           ((t) (values (pointer xwsd-sends (map null (constantly sends-offset))
                                                 $xwsd-note-start)))
                           ((nil) (values (pointer xwsd-sends (map null (constantly sends-offset))
                                                   %xwsd-parameters-start)))))))
  (envelope nil :type (ecase (and envelope-offset (/= envelope-offset #xffffffff))
                       ((nil) null)
                       ((t) (ecase note-p
                              ((t) (values (pointer xwsd-envelope-reference
                                                    (map null (constantly envelope-offset))
                                                    $xwsd-note-start)))
                              ((nil) (values (pointer xwsd-envelope-reference
                                                      (map null (constantly envelope-offset))
                                                      %xwsd-parameters-start))))))))

(defbinstruct/me xwsd-note ()
  ($xwsd-note-start 0 :type position)
  (wave-index 0 :type (unsigned-byte 32))
  (parameters nil :type (xwsd-parameters t)))

(defbinstruct/me xwsd-event ()
  (position 0.0f0 :type single-float) (length 0.0f0 :type single-float)
  (note-index 0 :type (unsigned-byte 32)) (reserved 0 :type (unsigned-byte 32)))

(defbinalias/me (xwsd-track-events (:type (simple-array (or null xwsd-event) (*)))) ()
  (nintendo-ware-reference-array #x4904 (xwsd-event)))

(defbinstruct/me xwsd-track ()
  (%track-start 0 :type position)
  (events nil :type (or nintendo-ware-null-reference
                        (values (pointer (map xwsd-track-events
                                              (the (function (t) (or null (simple-array (or null xwsd-event) (*)))) #'identity))
                                         (nintendo-ware-reference-offset-value 0)
                                         %track-start)))))

(defbinalias/me (xwsd-item-tracks (:type (simple-array (or null xwsd-track) (*)))) ()
  (nintendo-ware-reference-array #x4903 (xwsd-track)))

(defbinalias/me (xwsd-item-notes (:type (simple-array (or null xwsd-note) (*)))) ()
  (nintendo-ware-reference-array #x4902 (xwsd-note)))

(defbinstruct/me xwsd-item ()
  (%item-start 0 :type position)
  (parameters nil :type (or nintendo-ware-null-reference
                            (values (pointer (map (xwsd-parameters nil)
                                                  (the (function (t) (or null xwsd-parameters)) #'identity))
                                             (nintendo-ware-reference-offset-value #x4901)
                                             %item-start))))
  (tracks nil :type (or nintendo-ware-null-reference
                        (values (pointer (map xwsd-item-tracks
                                              (the (function (t) (or null (simple-array (or null xwsd-track) (*)))) #'identity))
                                         (nintendo-ware-reference-offset-value #x0101)
                                         %item-start))))
  (notes nil :type (or nintendo-ware-null-reference
                       (values (pointer (map xwsd-item-notes
                                             (the (function (t) (or null (simple-array (or null xwsd-note) (*)))) #'identity))
                                        (nintendo-ware-reference-offset-value #x0101)
                                        %item-start)))))

(defbinalias/me (xwsd-info-items (:type (simple-array (or null xwsd-item) (*)))) ()
  (nintendo-ware-reference-array #x4900 (xwsd-item)))

(define-nintendo-ware-section (xwsd-info (:magic "INFO"))
  (%info-start 0 :type position)
  (waves nil :type (or nintendo-ware-null-reference
                       (values (pointer (map nintendo-ware-sound-wave-ids
                                             (the (function (t) (or null (simple-array nintendo-ware-sound-wave-id (*)))) #'identity))
                                        (nintendo-ware-reference-offset-value #x0100)
                                        %info-start))))
  (items nil :type (or nintendo-ware-null-reference
                       (values (pointer (map xwsd-info-items
                                             (the (function (t) (or null (simple-array (or null xwsd-item) (*)))) #'identity))
                                        (nintendo-ware-reference-offset-value #x0101)
                                        %info-start)))))

(define-nintendo-ware-file (xwsd (:magic ("CWSD" "FWSD")))
  (%tag #x6800 :type (map null (lambda (ignored) (declare (ignore ignored)) (if (block-reference %header #x6800 nil) #x6800 #x4800))))
  (info nil :type (values (pointer xwsd-info (map null (constantly (block-start %header %tag)))))))

(defbinio xwsd stream)

(defmethod read-file ((type (eql 'xwsd)) (stream stream))
  (read-xwsd stream))
