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

(defbinstruct/me (xwsd-item-flag-set (:alignment 4)) ()
  (pan-info-p nil :type (boolean bit))
  (pitch-p nil :type (boolean bit))
  (filter-info-p nil :type (boolean bit))
  (reserved-3-7 0 :type (unsigned-byte 5))
  (sends-offset-p nil :type (boolean bit))
  (envelope-offset-p nil :type (boolean bit))
  (reserved-10-31 0 :type (unsigned-byte 22)))

(defbinstruct/me (xwsd-note-flag-set (:alignment 4)) ()
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
  ($xwsd-envelope-start 0 :type position)
  (values nil :type (or null-reference
                        (values (pointer (map xwsd-envelope
                                              (the (function (t) (or null xwsd-envelope)) #'identity))
                                         (reference-offset-value 0)
                                         $xwsd-envelope-start)))))

(defbinstruct/me xwsd-parameters (note-p)
  ($xwsd-parameters-start 0 :type position)
  (flags nil :type (ecase note-p
                    ((nil) xwsd-item-flag-set) ((t) xwsd-note-flag-set)))
  (key-info nil :type (ecase (and note-p (xwsd-note-flag-set-key-info-p flags))
                        ((nil) null) ((t) xbnk-key-flag)))
  (volume-info nil :type (ecase (and note-p (xwsd-note-flag-set-volume-info-p flags))
                        ((nil) null) ((t) xbnk-volume-flag)))
  (pan-info nil :type (ecase (if note-p (xwsd-note-flag-set-pan-info-p flags) (xwsd-item-flag-set-pan-info-p flags))
                        ((nil) null) ((t) xwsd-packed-pan)))
  (pitch nil :type (ecase (if note-p (xwsd-note-flag-set-pitch-p flags) (xwsd-item-flag-set-pitch-p flags))
                        ((nil) null) ((t) single-float)))
  (filter-info nil :type (ecase (if note-p (xwsd-note-flag-set-filter-info-p flags) (xwsd-item-flag-set-filter-info-p flags))
                        ((nil) null) ((t) xwsd-packed-filter)))
  (reserved-low-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32)
            ((logcount (if note-p (xwsd-note-flag-set-reserved-5-7 flags)
                                 (xwsd-item-flag-set-reserved-3-7 flags))))))
  (sends-offset nil :type (ecase (if note-p (xwsd-note-flag-set-sends-offset-p flags) (xwsd-item-flag-set-sends-offset-p flags))
                        ((nil) null) ((t) (unsigned-byte 32))))
  (envelope-offset nil :type (ecase (if note-p (xwsd-note-flag-set-envelope-offset-p flags) (xwsd-item-flag-set-envelope-offset-p flags))
                        ((nil) null) ((t) (unsigned-byte 32))))
  (reserved-high-values #.(make-array 0 :element-type '(unsigned-byte 32))
    :type (simple-array (unsigned-byte 32)
            ((logcount (if note-p (xwsd-note-flag-set-reserved-10-31 flags)
                                 (xwsd-item-flag-set-reserved-10-31 flags))))))
  ;; Item effects use the flags base; note effects include wave-index.
  (sends nil :type (ecase (and sends-offset (/= sends-offset #xffffffff))
                    ((nil) null)
                    ((t) (ecase note-p
                           ((t) (values (pointer xwsd-sends (map null (constantly sends-offset))
                                                 $xwsd-note-start)))
                           ((nil) (values (pointer xwsd-sends (map null (constantly sends-offset))
                                                   $xwsd-parameters-start)))))))
  (envelope nil :type (ecase (and envelope-offset (/= envelope-offset #xffffffff))
                       ((nil) null)
                       ((t) (ecase note-p
                              ((t) (values (pointer xwsd-envelope-reference
                                                    (map null (constantly envelope-offset))
                                                    $xwsd-note-start)))
                              ((nil) (values (pointer xwsd-envelope-reference
                                                      (map null (constantly envelope-offset))
                                                      $xwsd-parameters-start))))))))

(defbinstruct/me xwsd-note ()
  ($xwsd-note-start 0 :type position)
  (wave-index 0 :type (unsigned-byte 32))
  (parameters nil :type (xwsd-parameters t)))

(defbinstruct/me xwsd-event ()
  (position 0.0f0 :type single-float) (length 0.0f0 :type single-float)
  (note-index 0 :type (unsigned-byte 32)) (reserved 0 :type (unsigned-byte 32)))

(defbinstruct/me xwsd-event-table ()
  ($events-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map (xwsd-event)
                                                (the (function (t) (or null xwsd-event)) #'identity))
                                           (reference-offset-value #x4904)
                                           $events-start))) (count))))

(defbinstruct/me xwsd-track ()
  ($track-start 0 :type position)
  (events nil :type (or null-reference
                        (values (pointer (map xwsd-event-table
                                              (the (function (t) (or null xwsd-event-table)) #'identity))
                                         (reference-offset-value 0)
                                         $track-start)))))

(defbinstruct/me xwsd-track-table ()
  ($xwsd-track-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map xwsd-track
                                                (the (function (t) (or null xwsd-track)) #'identity))
                                           (reference-offset-value #x4903)
                                           $xwsd-track-table-start))) (count))))

(defbinstruct/me xwsd-note-table ()
  ($xwsd-note-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map xwsd-note
                                                (the (function (t) (or null xwsd-note)) #'identity))
                                           (reference-offset-value #x4902)
                                           $xwsd-note-table-start))) (count))))

(defbinstruct/me xwsd-item ()
  ($item-start 0 :type position)
  (parameters nil :type (or null-reference
                            (values (pointer (map (xwsd-parameters nil)
                                                  (the (function (t) (or null xwsd-parameters)) #'identity))
                                             (reference-offset-value #x4901)
                                             $item-start))))
  (tracks nil :type (or null-reference
                        (values (pointer (map xwsd-track-table
                                              (the (function (t) (or null xwsd-track-table)) #'identity))
                                         (reference-offset-value #x0101)
                                         $item-start))))
  (notes nil :type (or null-reference
                       (values (pointer (map xwsd-note-table
                                             (the (function (t) (or null xwsd-note-table)) #'identity))
                                        (reference-offset-value #x0101)
                                        $item-start)))))

(defbinstruct/me xwsd-item-table ()
  ($xwsd-item-table-start 0 :type position)
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array
                      (or null-reference
                          (values (pointer (map xwsd-item
                                                (the (function (t) (or null xwsd-item)) #'identity))
                                           (reference-offset-value #x4900)
                                           $xwsd-item-table-start))) (count))))

(define-nintendo-ware-section (xwsd-info (:magic "INFO"))
  ($info-start 0 :type position)
  (waves nil :type (or null-reference
                       (values (pointer (map wave-id-table
                                             (the (function (t) (or null wave-id-table)) #'identity))
                                        (reference-offset-value #x0100)
                                        $info-start))))
  (items nil :type (or null-reference
                       (values (pointer (map xwsd-item-table
                                             (the (function (t) (or null xwsd-item-table)) #'identity))
                                        (reference-offset-value #x0101)
                                        $info-start)))))

(define-nintendo-ware-file (xwsd (:magic ("CWSD" "FWSD")))
  (%tag #x6800 :type (map null (lambda (ignored) (declare (ignore ignored)) (if (block-reference %header #x6800 nil) #x6800 #x4800))))
  (info nil :type (values (pointer xwsd-info (map null (constantly (block-start %header %tag)))))))

(defbinio xwsd stream)

(defmethod read-file ((type (eql 'xwsd)) (stream stream))
  (read-xwsd stream))
