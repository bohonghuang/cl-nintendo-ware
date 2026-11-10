(in-package #:cl-nintendo-ware)

(defbinenum (nintendo-ware-sound-sample-codec (:type (unsigned-byte 8))) ()
  (pcm-8 0)
  (pcm-16 1)
  (dsp-adpcm 2)
  (ima-adpcm 3))

(defbinstruct/me nintendo-ware-sound-byte-table ()
  (count 0 :type (unsigned-byte 32))
  (entries #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (count))))

(defbinstruct/me (nintendo-ware-sound-resource-id (:alignment 4)) ()
  (index 0 :type (unsigned-byte 24))
  (type 0 :type (unsigned-byte 8)))

(defun nintendo-ware-sound-resource-id-value (identifier)
  "Return the complete original resource ID, including its type byte."
  (+ (nintendo-ware-sound-resource-id-index identifier) (* (nintendo-ware-sound-resource-id-type identifier) #x1000000)))

(defbinstruct/me nintendo-ware-sound-wave-id ()
  (archive-id (make-nintendo-ware-sound-resource-id) :type nintendo-ware-sound-resource-id)
  (index 0 :type (unsigned-byte 32)))

(defbinstruct/me nintendo-ware-sound-wave-id-table ()
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array nintendo-ware-sound-wave-id (count))))

