(in-package #:nintendo-ware)

(defbinio xseq stream)
(defbinio xwav stream)
(defbinio xwar stream)
(defbinio xbnk stream)
(defbinio xwsd stream)
(defbinio xstm stream)
(defbinio xsar stream)
(defbinio xgrp stream)

(defmethod read-file ((type (eql 'xseq)) (stream stream))
  (read-xseq stream))

(defmethod read-file ((type (eql 'xwav)) (stream stream))
  (read-xwav stream))

(defmethod read-file ((type (eql 'xwar)) (stream stream))
  (read-xwar stream))

(defmethod read-file ((type (eql 'xbnk)) (stream stream))
  (read-xbnk stream))

(defmethod read-file ((type (eql 'xwsd)) (stream stream))
  (read-xwsd stream))

(defmethod read-file ((type (eql 'xstm)) (stream stream))
  (read-xstm stream))

(defmethod read-file ((type (eql 'xsar)) (stream stream))
  (read-xsar stream))

(defmethod read-file ((type (eql 'xgrp)) (stream stream))
  (read-xgrp stream))
