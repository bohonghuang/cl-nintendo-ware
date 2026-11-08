(asdf:defsystem #:cl-nintendo-ware
  :description "Binstruct-based NintendoWare C/F sound file readers; no playback."
  :version "0.1.0"
  :depends-on (#:alexandria #:binstruct #:parsonic #:flexi-streams)
  :serial t
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-nintendo-ware/test)))
  :components ((:file "package")
               (:file "binary")
               (:file "common")
               (:file "section")
               (:file "container")
               (:module "sound"
                :serial t
                :components ((:file "xseq")
                             (:file "xwav")
                             (:file "xwar")
                             (:file "xbnk")
                             (:file "xwsd")
                             (:file "xstm")
                             (:file "xsar")
                             (:file "xgrp")))))

(asdf:defsystem #:cl-nintendo-ware/test
  :depends-on (#:cl-nintendo-ware)
  :serial t
  :components ((:static-file "test/data/mset.bcsar")
               (:static-file "test/data/TigerSound.bcsar")
               (:static-file "test/data/menu.bcsar")
               (:file "test/sequence")
               (:file "test/endian-fixtures")
               (:file "test/formats")
               (:file "test/archives")
               (:file "test/endian-readers")
               (:file "test/pmee"))
  :perform (asdf:test-op (operation component)
             (declare (ignore operation component))
             (uiop:symbol-call '#:cl-nintendo-ware.test '#:run-tests)
             (uiop:symbol-call '#:cl-nintendo-ware.test '#:run-format-tests)
             (uiop:symbol-call '#:cl-nintendo-ware.test '#:run-archive-tests)
             (uiop:symbol-call '#:cl-nintendo-ware.test '#:run-endian-tests)
             (uiop:symbol-call '#:cl-nintendo-ware.test '#:run-pmee-tests)))
