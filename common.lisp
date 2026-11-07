(in-package #:cl-nintendo-ware)

(defbinenum (sample-codec (:type (unsigned-byte 8))) ()
  (pcm-8 0)
  (pcm-16 1)
  (dsp-adpcm 2)
  (ima-adpcm 3))

(define-condition invalid-file (error)
  ((reason :initarg :reason :reader invalid-file-reason))
  (:report (lambda (condition output) (write-string (invalid-file-reason condition) output))))

(defun fail-file (control &rest arguments)
  (error 'invalid-file :reason (apply #'format nil control arguments)))

(defgeneric read-file (type input)
  (:method (type (pathname pathname))
    (with-open-file (stream pathname :direction :input :element-type '(unsigned-byte 8))
      (read-file type stream)))
  (:method (type (vector vector))
    (read-file type (flexi-streams:make-in-memory-input-stream vector)))
  (:method (type (filename string))
    (read-file type (pathname filename)))
  (:method :around (type (stream stream))
    (handler-case (call-next-method)
      (binstruct::deserialize-error (condition) (fail-file "~A" condition)))))

(defun valid-reference-offset-p (offset type expected-type)
  (or (= offset -1)
      (and (not (minusp offset)) (or (null expected-type) (= type expected-type)))))

(defbinstruct/me reference (&optional expected-type)
  (type 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (offset -1 :type (satisfies (signed-byte 32)
                              (lambda (offset)
                                (valid-reference-offset-p offset type expected-type)))))

(defbinstruct/me sized-reference ()
  (type 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (offset -1 :type (signed-byte 32))
  (size 0 :type (unsigned-byte 32)))

;; Pointer fields need an offset, not a temporary REFERENCE object. Keep the
;; same wire declaration and validation while returning the scalar directly.
(defbinstruct/me (reference-offset-value (:type (signed-byte 32)) (:constructor progn) (:conc-name nil)) (tag)
  (%tag tag :type (unsigned-byte 16))
  (nil 0 :type (unsigned-byte 16))
  (values -1 :type (satisfies (signed-byte 32)
                             (lambda (offset) (valid-reference-offset-p offset %tag tag)))))

(defun reference-target (reference base &optional expected-type)
  (let ((offset (reference-offset reference)))
    (unless (= offset -1)
      (when (and expected-type (/= expected-type (reference-type reference)))
        (fail-file "Reference tag #x~X; expected #x~X" (reference-type reference) expected-type))
      (when (minusp offset) (fail-file "Invalid relative offset ~D" offset))
      (+ base offset))))

(defun sized-reference-target (reference base &optional expected-type)
  (let ((offset (sized-reference-offset reference)))
    (unless (= offset -1)
      (when (and expected-type (/= expected-type (sized-reference-type reference)))
        (fail-file "Sized reference tag mismatch"))
      (when (minusp offset) (fail-file "Invalid sized relative offset ~D" offset))
      (+ base offset))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmethod binstruct::lisp-type-expr ((name (eql 'reference-to)) &rest arguments)
    `(or null ,(binstruct::lisp-type (third arguments))))
  (defmethod binstruct::expand-reader-type-expr ((name (eql 'reference-to)) &rest arguments)
    (destructuring-bind (tag base content) arguments
      (with-gensyms (offset)
        `(let ((,offset ,(binstruct::expand-reader-type-unit `(peek (reference-offset-value ,tag)))))
           ,(binstruct::expand-reader-type
             `(ecase (= ,offset -1)
                ((t) (map (reference-offset-value ,tag) (constantly nil)))
                ((nil) (pointer (map ,content
                                     (the (function (t) (or null ,(binstruct::lisp-type content))) #'identity))
                                (reference-offset-value ,tag)
                                ;; These anchors have already been read. Use
                                ;; their lexical value, not a global $ alias
                                ;; overwritten by nested reference targets.
                                (progn ,base)))))))))
  (defmethod binstruct::expand-writer-type-expr ((name (eql 'reference-to)) &rest arguments)
    (destructuring-bind (tag base content) arguments
      (binstruct::expand-writer-type
       `(ecase (null ,binstruct::*value*)
          ((t) (map (reference-offset-value ,tag) (constantly nil) (constantly -1)))
          ((nil) (pointer ,content (reference-offset-value ,tag) ,base)))))))

(defbinstruct (file-byte-order (:type (member :little :big)) (:constructor progn) (:conc-name nil) (:endian :big)) ()
  (%value #xfffe :type (satisfies (unsigned-byte 16) (lambda (value) (member value '(#xfffe #xfeff)))))
  (values :little :type (map null (lambda (ignored) (declare (ignore ignored))
                                   (ecase %value (#xfffe :little) (#xfeff :big))))))

(defbinstruct/me header (start magic endian)
  (start 0 :type (map null (constantly start)))
  (magic #.(coerce "" 'simple-base-string) :type (map null (constantly magic)))
  (endian :little :type (map null (constantly endian)))
  (header-size 20 :type (unsigned-byte 16))
  (version 0 :type (unsigned-byte 32))
  (file-size 20 :type (unsigned-byte 32))
  (block-count 0 :type (unsigned-byte 16))
  (padding 0 :type (unsigned-byte 16))
  (references #() :type (simple-array sized-reference (block-count)))
  (%valid nil :type (map null (lambda (ignored) (declare (ignore ignored))
                                (validate-header references)))))

;; Explicit LE entry: embedded headers do not inherit their parent's endian.
(defbinalias header/le (start magic endian) (header start magic endian))

(defbinstruct (file-header (:type header) (:constructor progn) (:conc-name nil)) ()
  (%start 0 :type position)
  (%magic #.(coerce "" 'simple-base-string) :type (simple-base-string 4))
  (%endian :little :type file-byte-order)
  (values nil :type (ecase %endian
                     (:little (header/le %start %magic %endian))
                     (:big (header/be %start %magic %endian)))))

(defun header-version-major (header)
  (mod (floor (header-version header) (if (char= (char (header-magic header) 0) #\C) #x1000000 #x10000)) 256))

(defun validate-header (references)
  (loop :for index :below (length references) :for current := (aref references index)
        :do (loop :for previous-index :below index :for previous := (aref references previous-index)
                  :do (when (= (sized-reference-type current) (sized-reference-type previous))
                        (fail-file "Duplicate block tag"))))
  nil)

(defun block-reference (header type &optional (required t))
  (or (find type (header-references header) :key #'sized-reference-type)
      (when required (fail-file "Missing block #x~X" type))))

(defun block-start (header type)
  (+ (header-start header) (sized-reference-offset (block-reference header type))))



(defbinstruct/me integer-table ()
  (count 0 :type (unsigned-byte 32))
  (entries #.(make-array 0 :element-type '(unsigned-byte 32)) :type (simple-array (unsigned-byte 32) (count))))

(defbinstruct/me byte-table ()
  (count 0 :type (unsigned-byte 32))
  (entries #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (count))))

(defbinstruct/me wave-id ()
  (archive-id 0 :type (unsigned-byte 32))
  (index 0 :type (unsigned-byte 32)))

(defbinstruct/me wave-id-table ()
  (count 0 :type (unsigned-byte 32))
  (entries #() :type (simple-array wave-id (count))))

(defbinstruct/me raw-block (expected-magic)
  (magic #.(coerce "" 'simple-base-string) :type (satisfies (simple-base-string 4) (lambda (magic) (string= magic expected-magic))))
  (size 0 :type (unsigned-byte 32))
  (bytes #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- size 8)))))

(defbinstruct/me (packed-pan (:alignment 4)) ()
  (pan 0 :type (signed-byte 8))
  (surround-pan 0 :type (signed-byte 8))
  (reserved 0 :type (unsigned-byte 16)))

(defbinstruct/me (packed-filter (:alignment 4)) ()
  (low-pass 0 :type (unsigned-byte 8))
  (biquad-type 0 :type (unsigned-byte 8))
  (biquad-value 0 :type (unsigned-byte 8))
  (reserved 0 :type (unsigned-byte 8)))

(defbinstruct/me (packed-priority (:alignment 4)) ()
  (channel-priority 0 :type (unsigned-byte 8))
  (release-priority-p nil :type (boolean bit))
  (release-reserved 0 :type (unsigned-byte 7))
  (reserved 0 :type (unsigned-byte 16)))
