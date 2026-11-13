(defpackage #:cl-nintendo-ware
  (:use #:cl #:alexandria #:parsonic #:binstruct)
  (:nicknames #:nintendo-ware)
  (:export
   #:read-file
   #:xseq
   #:xseq-events
   #:xwav
   #:xwav-channels
   #:xwav-codec
   #:xwav-sample-rate
   #:xwav-loop-p
   #:xwav-loop-start
   #:xwav-loop-end
   #:xwar
   #:xwar-waves
   #:xbnk
   #:xbnk-instruments
   #:xbnk-waves
   #:xwsd
   #:xwsd-items
   #:xwsd-waves
   #:xstm
   #:xstm-stream
   #:xstm-tracks
   #:xstm-channels
   #:xstm-seek-table
   #:xsar
   #:xsar-files
   #:xsar-file-name
   #:xsar-file-data
   #:xgrp
   #:xgrp-entries
   #:xgrp-dependencies))
