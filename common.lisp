(in-package #:cl-nintendo-ware)

(define-condition invalid-file (error)
  ((reason :initarg :reason :reader invalid-file-reason))
  (:report (lambda (condition output) (write-string (invalid-file-reason condition) output))))

(defun fail-file (control &rest arguments)
  (error 'invalid-file :reason (apply #'format nil control arguments)))

(defun check-span (start size lower upper)
  (unless (and (integerp start) (integerp size) (<= lower start upper) (<= 0 size (- upper start)))
    (fail-file "Range ~S + ~S outside [~D, ~D)" start size lower upper))
  start)

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

(defun reference-target (reference base lower upper &optional expected-type (size 1))
  (let ((offset (reference-offset reference)))
    (unless (= offset -1)
      (when (and expected-type (/= expected-type (reference-type reference)))
        (fail-file "Reference tag #x~X; expected #x~X" (reference-type reference) expected-type))
      (when (minusp offset) (fail-file "Invalid relative offset ~D" offset))
      (check-span (+ base offset) size lower upper))))

(defun sized-reference-target (reference base lower upper &optional expected-type)
  (let ((offset (sized-reference-offset reference)))
    (unless (= offset -1)
      (when (and expected-type (/= expected-type (sized-reference-type reference)))
        (fail-file "Sized reference tag mismatch"))
      (when (minusp offset) (fail-file "Invalid sized relative offset ~D" offset))
      (check-span (+ base offset) (sized-reference-size reference) lower upper))))

;; These are compile-time type operators, not parameterized parser functions.
;; Expand concrete targets directly; only file/section containers use INLINE.

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmethod binstruct::lisp-type-expr ((name (eql 'bounded)) &rest arguments)
    (binstruct::lisp-type (third arguments)))
  (defmethod binstruct::expand-reader-type-expr ((name (eql 'bounded)) &rest arguments)
    (destructuring-bind (upper minimum-size content) arguments
      (alexandria:with-gensyms (start)
        `(let ((,start (position)))
           (constantly (check-span ,start ,minimum-size 0 ,upper))
           ,(binstruct::expand-reader-type content)))))

  (defmethod binstruct::expand-writer-type-expr ((name (eql 'bounded)) &rest arguments)
    (binstruct::expand-writer-type (third arguments))))


(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmethod binstruct::lisp-type-expr ((name (eql 'reference-to)) &rest arguments)
    `(or null ,(binstruct::lisp-type (third arguments))))
  (defmethod binstruct::expand-reader-type-expr ((name (eql 'reference-to)) &rest arguments)
    (destructuring-bind (tag base content) arguments
      (alexandria:with-gensyms (offset)
        `(let ((,offset ,(binstruct::expand-reader-type-unit `(peek (reference-offset-value ,tag)))))
           ,(binstruct::expand-reader-type
             `(ecase (= ,offset -1)
                ((t) (map (reference-offset-value ,tag) (constantly nil)))
                ((nil) (pointer (map ,content
                                     (the (function (t) (or null ,(binstruct::lisp-type content))) #'identity))
                                (reference-offset-value ,tag)
                                ,base))))))))
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

(defbinstruct/me header ()
  (start 0 :type position)
  (magic #.(coerce "" 'simple-base-string) :type (simple-base-string 4))
  (endian :little :type file-byte-order)
  (header-size 20 :type (satisfies (unsigned-byte 16) (lambda (size) (>= size 20))))
  (version 0 :type (unsigned-byte 32))
  (file-size 20 :type (satisfies (unsigned-byte 32) (lambda (size) (<= header-size size))))
  ;; Reject a physically truncated file before allocating its reference table.
  (%last-byte 0 :type (peek (unsigned-byte 8) (+ start file-size -1)))
  (block-count 0 :type (satisfies (unsigned-byte 16) (lambda (count) (<= (+ 20 (* 12 count)) header-size))))
  (padding 0 :type (unsigned-byte 16))
  (references #() :type (simple-array sized-reference (block-count)))
  (%valid nil :type (map null (lambda (ignored) (declare (ignore ignored))
                                (validate-header start header-size file-size references)))))

(defun header-version-major (header)
  (mod (floor (header-version header) (if (char= (char (header-magic header) 0) #\C) #x1000000 #x10000)) 256))

(defun validate-header (start header-size file-size references)
  (loop :for index :below (length references) :for current := (aref references index)
        :for offset := (sized-reference-target current start (+ start header-size) (+ start file-size))
        :do (unless (and offset (>= (sized-reference-size current) 8)) (fail-file "Null or short block"))
            (loop :for previous-index :below index :for previous := (aref references previous-index)
                  :do (when (= (sized-reference-type current) (sized-reference-type previous))
                        (fail-file "Duplicate block tag"))
                      (when (< (max (sized-reference-offset current) (sized-reference-offset previous))
                               (min (+ (sized-reference-offset current) (sized-reference-size current))
                                    (+ (sized-reference-offset previous) (sized-reference-size previous))))
                        (fail-file "Overlapping blocks"))))
  nil)

(defun block-reference (header type &optional (required t))
  (or (find type (header-references header) :key #'sized-reference-type)
      (when required (fail-file "Missing block #x~X" type))))

(defun block-start (header type)
  (+ (header-start header) (sized-reference-offset (block-reference header type))))

(defun block-end (header type)
  (+ (block-start header type) (sized-reference-size (block-reference header type))))

(defun flag-value (flags bit &optional default)
  (let ((mask (flag-values-mask flags)))
    (if (logbitp bit mask)
        (aref (flag-values-values flags) (logcount (logand mask (1- (expt 2 bit))))) default)))

(defun flag-position (flags bit start)
  (+ start 4 (* 4 (logcount (logand (flag-values-mask flags) (1- (expt 2 bit)))))))

(defun flag-target (flags bit base lower upper)
  (let ((offset (flag-value flags bit #xffffffff)))
    (unless (= offset #xffffffff) (check-span (+ base offset) 1 lower upper))))

(defbinstruct/me flag-values (upper)
  (%start 0 :type position)
  (mask 0 :type (satisfies (unsigned-byte 32) (lambda (mask) (<= (+ %start 4 (* 4 (logcount mask))) upper))))
  (values #.(make-array 0 :element-type '(unsigned-byte 32)) :type (simple-array (unsigned-byte 32) ((logcount mask)))))

(defbinstruct/me integer-table (upper)
  (%start 0 :type position)
  (count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (<= (+ %start 4 (* 4 count)) upper))))
  (entries #.(make-array 0 :element-type '(unsigned-byte 32)) :type (simple-array (unsigned-byte 32) (count))))

(defbinstruct/me byte-table (upper)
  (%start 0 :type position)
  (count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (<= (+ %start 4 count) upper))))
  (entries #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) (count))))

(defbinstruct/me wave-id ()
  (archive-id 0 :type (unsigned-byte 32))
  (index 0 :type (unsigned-byte 32)))

(defbinstruct/me wave-id-table (upper)
  (%start 0 :type position)
  (count 0 :type (satisfies (unsigned-byte 32) (lambda (count) (<= (+ %start 4 (* 8 count)) upper))))
  (entries #() :type (simple-array wave-id (count))))

(defbinstruct/me raw-block (expected-magic expected-size)
  (magic #.(coerce "" 'simple-base-string) :type (satisfies (simple-base-string 4) (lambda (magic) (string= magic expected-magic))))
  (size 0 :type (satisfies (unsigned-byte 32) (lambda (size) (= size expected-size))))
  (bytes #.(make-array 0 :element-type '(unsigned-byte 8)) :type (simple-array (unsigned-byte 8) ((- size 8)))))

(deftype nintendo-ware-file-union () '(or null sound-sequence sound-wave wave-archive sound-bank wave-sound-data sound-stream sound-archive sound-group))

(defun magic-kind (magic)
  (unless (and (= (length magic) 4) (find (char magic 0) "CF"))
    (fail-file "Unknown file magic ~S" magic))
  (cond ((string= magic "SEQ" :start1 1) :sound-sequence)
        ((string= magic "WAV" :start1 1) :sound-wave)
        ((string= magic "WAR" :start1 1) :wave-archive)
        ((string= magic "BNK" :start1 1) :sound-bank)
        ((string= magic "WSD" :start1 1) :wave-sound-data)
        ((string= magic "STM" :start1 1) :sound-stream)
        ((string= magic "SAR" :start1 1) :sound-archive)
        ((string= magic "GRP" :start1 1) :sound-group)
        (t (fail-file "Unknown file magic ~S" magic))))

(defbinstruct (embedded-file (:type nintendo-ware-file-union) (:constructor progn) (:conc-name nil)) ()
  (%start 0 :type position)
  (%kind :sound-sequence :type (map (peek (simple-base-string 4)) #'magic-kind))
  (%endian :little :type (peek file-byte-order (+ %start 4)))
  (values nil :type (ecase %endian
                     (:little (ecase %kind
                                (:sound-sequence sound-sequence/le)
                                (:sound-wave sound-wave/le)
                                (:wave-archive wave-archive/le)
                                (:sound-bank sound-bank/le)
                                (:wave-sound-data wave-sound-data/le)
                                (:sound-stream sound-stream/le)
                                (:sound-archive sound-archive/le)
                                (:sound-group sound-group/le)))
                     (:big (ecase %kind
                                (:sound-sequence sound-sequence/be)
                                (:sound-wave sound-wave/be)
                                (:wave-archive wave-archive/be)
                                (:sound-bank sound-bank/be)
                                (:wave-sound-data wave-sound-data/be)
                                (:sound-stream sound-stream/be)
                                (:sound-archive sound-archive/be)
                                (:sound-group sound-group/be)))
)))

(defbinstruct/me (file-size-probe (:type (unsigned-byte 32)) (:constructor progn) (:conc-name nil)) ()
  (%start 0 :type position)
  (values 0 :type (peek (unsigned-byte 32) (+ %start 12))))

;; A complete embedded file has its own BOM. Check its declared span before
;; following any of its references, without adding arguments to file readers.
(defbinstruct (file-span (:type null) (:constructor progn) (:conc-name nil)) (upper)
  (%start 0 :type position)
  (%endian :little :type (peek file-byte-order (+ %start 4)))
  (%size 0 :type (ecase %endian (:little file-size-probe/le) (:big file-size-probe/be)))
  (%valid nil :type (map null (lambda (ignored) (declare (ignore ignored))
                                (check-span %start %size %start upper)))))

(defbinstruct (bounded-file (:type nintendo-ware-file-union) (:constructor progn) (:conc-name nil)
                            (:include (file-span upper))) (upper)
  (values nil :type embedded-file))

(export '(read-file invalid-file invalid-file-reason header header-start header-magic header-endian header-version-major
          header-header-size header-version header-file-size header-block-count header-references
          reference reference-type reference-offset sized-reference sized-reference-type sized-reference-offset sized-reference-size
          flag-values flag-values-mask flag-values-values integer-table integer-table-entries byte-table byte-table-entries
          wave-id wave-id-archive-id wave-id-index wave-id-table wave-id-table-entries raw-block raw-block-bytes))

(defbinstruct packed-pan ()
  (pan 0 :type (signed-byte 8))
  (surround-pan 0 :type (signed-byte 8))
  (reserved 0 :type (unsigned-byte 16)))

(defbinstruct (packed-pan/be (:type packed-pan) (:endian :big)) ()
  (reserved 0 :type (unsigned-byte 16))
  (surround-pan 0 :type (signed-byte 8))
  (pan 0 :type (signed-byte 8)))

(defbinalias packed-pan/le () packed-pan)
(%define-endian-reader packed-pan)

(defbinstruct packed-filter ()
  (low-pass 0 :type (unsigned-byte 8))
  (biquad-type 0 :type (unsigned-byte 8))
  (biquad-value 0 :type (unsigned-byte 8))
  (reserved 0 :type (unsigned-byte 8)))

(defbinstruct (packed-filter/be (:type packed-filter) (:endian :big)) ()
  (reserved 0 :type (unsigned-byte 8))
  (biquad-value 0 :type (unsigned-byte 8))
  (biquad-type 0 :type (unsigned-byte 8))
  (low-pass 0 :type (unsigned-byte 8)))

(defbinalias packed-filter/le () packed-filter)
(%define-endian-reader packed-filter)

(defbinstruct packed-priority ()
  (channel-priority 0 :type (unsigned-byte 8))
  (release-priority 0 :type (unsigned-byte 8))
  (reserved 0 :type (unsigned-byte 16)))

(defbinstruct (packed-priority/be (:type packed-priority) (:endian :big)) ()
  (reserved 0 :type (unsigned-byte 16))
  (release-priority 0 :type (unsigned-byte 8))
  (channel-priority 0 :type (unsigned-byte 8)))

(defbinalias packed-priority/le () packed-priority)
(%define-endian-reader packed-priority)

