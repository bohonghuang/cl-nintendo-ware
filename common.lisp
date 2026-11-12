(in-package #:cl-nintendo-ware)

(defbinalias nintendo-ware-magic ()
  (pointer (simple-base-string 4) (map null (constantly 0)) $nintendo-ware-file-start))
(defbinalias/me nintendo-ware-version ()
  (pointer (unsigned-byte 32) (map null (constantly 8)) $nintendo-ware-file-start))
(defbinstruct/me (nintendo-ware-major-version (:type (unsigned-byte 8))
                                         (:constructor progn) (:conc-name nil)) ()
  (%magic #.(coerce "" 'simple-base-string) :type (values nintendo-ware-magic))
  (%version 0 :type nintendo-ware-version)
  (values 0 :type (map null (constantly
                            (ldb (byte 8 (if (char= (char %magic 0) #\C) 24 16)) %version)))))
