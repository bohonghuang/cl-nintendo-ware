(defpackage #:cl-nintendo-ware
  (:use #:cl #:alexandria #:parsonic #:binstruct)
  (:nicknames #:nintendo-ware)
  (:export
   #:read-file
   #:xseq
   #:xseq-events
   #:xwav
   #:xwav-samples
   #:xwar
   #:xwar-waves
   #:xbnk
   #:xwsd
   #:xstm
   #:xstm-sample-data
   #:xstm-seek-rows
   #:xstm-regions-entries
   #:xsar
   #:xsar-files
   #:xsar-file-name
   #:xsar-file-data
   #:xgrp
   #:xgrp-file-data))
