(in-package #:cl-nintendo-ware.test)

;; Source revision, original filename and SHA-256 are recorded in README.md.
;; Unlike the synthetic fixtures, this archive is read without rewriting bytes.
(defun run-pmee-tests ()
  (let* ((archive (nintendo-ware::read-file
                   'nintendo-ware::xsar
                   (asdf:system-relative-pathname :cl-nintendo-ware #P"test/data/mset.bcsar")))
         (info (nintendo-ware::xsar-info archive))
         (strings (nintendo-ware::xsar-string-table-entries
                   (nintendo-ware::xsar-strg-strings (nintendo-ware::xsar-strg archive))))
         (sounds (nintendo-ware::xsar-sounds-table-entries (nintendo-ware::xsar-info-sounds info)))
         (files (nintendo-ware::xsar-files archive))
         ;; This test chooses to parse every file. XSAR only returned bytes.
         (contents (map 'vector
                        (lambda (file type)
                          (nintendo-ware::read-file type (nintendo-ware::xsar-file-data file)))
                        files
                        '#(nintendo-ware::xseq nintendo-ware::xseq nintendo-ware::xseq nintendo-ware::xseq nintendo-ware::xseq
                           nintendo-ware::xwsd nintendo-ware::xwsd
                           nintendo-ware::xbnk nintendo-ware::xbnk nintendo-ware::xbnk nintendo-ware::xbnk nintendo-ware::xbnk
                           nintendo-ware::xwar nintendo-ware::xwar nintendo-ware::xwar nintendo-ware::xwar
                           nintendo-ware::xwar nintendo-ware::xwar nintendo-ware::xwar)))
         (project (nintendo-ware::xsar-info-project-info info)))
    (assert (string= "CSAR" (nintendo-ware::header-magic (nintendo-ware::xsar-header archive))))
    (assert (eq :little (nintendo-ware::header-endian (nintendo-ware::xsar-header archive))))
    (assert (= 67 (length strings)))
    (assert (= 50 (length sounds)))
    ;; cl-nitro naming semantics: the last named alias for a file ID wins;
    ;; unnamed WARs keep NIL rather than receiving invented filenames.
    (assert (equal '("BGM_CTR_MSET_FIRST"
                     "BGM_CTR_MSET_TWL"
                     "SE_CTR_MSET_SLIDE_BTN_EDGE"
                     "SE_CTR_COMMON_SYSAPPLET_END"
                     "SE_TWL_SET_USER_COLOR_BOTTOM"
                     "SE_CTR_MSET_PEN"
                     "SE_CTR_COMMON_TOGGLE"
                     "BANK_CTR_MSET_BGM"
                     "BANK_TWL_SETTING"
                     "BANK_CTR_MSET_SE"
                     "BANK_TWL_SE"
                     "BANK_CTR_COMMON"
                     nil
                     nil
                     nil
                     nil
                     nil
                     nil
                     nil)
                   (map 'list #'nintendo-ware::xsar-file-name files)))
    (assert (equal '(68640 8800 2176 1760 352 216 664 2324 264 464 200 1024 10368 2800 230616 7118 7776 488 25232)
                   (map 'list (lambda (file) (length (nintendo-ware::xsar-file-data file))) files)))
    ;; Non-null project-info requires the real #x220b reference tag.
    (assert (= 32 (nintendo-ware::xsar-project-info-maximum-sequences project)))
    (assert (= 64 (nintendo-ware::xsar-project-info-maximum-sequence-tracks project)))
    (assert (= 64 (nintendo-ware::xsar-project-info-maximum-wave-sounds project)))
    (flet ((name (string-index)
             (string-right-trim '(#\Null)
               (nintendo-ware::xsar-string-text
                (aref strings string-index)))))
      ;; Names, file IDs and volumes independently cross-checked with DualRip.
      (loop for sound across sounds
            for (expected-name file-id volume) in
            '(("SE_CTR_MSET_PEN" 5 28)
              ("SE_CTR_COMMON_TOUCH" 6 30)
              ("SE_CTR_COMMON_TOUCHOUT" 6 20)
              ("SE_CTR_COMMON_TOUCHIN" 6 24)
              ("SE_CTR_COMMON_TOGGLE" 6 64)
              ("BGM_CTR_MSET" 0 100)
              ("BGM_CTR_MSET_NET" 0 100)
              ("BGM_CTR_MSET_FIRST" 0 100)
              ("BGM_CTR_MSET_TWL" 1 100)
              ("SE_CTR_MSET_PAGE_SCROLL_LEFT" 2 96)
              ("SE_CTR_MSET_PAGE_SCROLL_RIGHT" 2 96)
              ("SE_CTR_MSET_SOUND_SURROUND" 2 96)
              ("SE_CTR_MSET_SOUND_STEREO" 2 96)
              ("SE_CTR_MSET_SOUND_MONO" 2 96)
              ("SE_CTR_MSET_ANALOGPAD_CHECK" 2 56)
              ("SE_CTR_MSET_3D_TEST" 2 110)
              ("SE_CTR_MSET_BALLOON_OK" 2 96)
              ("SE_CTR_MSET_BALLOON_CANCEL" 3 100)
              ("SE_CTR_MSET_INETKUN_TOUCH" 2 96)
              ("SE_CTR_MSET_INETKUN_TOUCHOUT" 2 72)
              ("SE_CTR_MSET_INETKUN_DECIDE" 2 72)
              ("SE_CTR_MSET_INETKUN_JUMP" 2 64)
              ("SE_CTR_MSET_INETKUN_SPEAK" 2 56)
              ("SE_CTR_MSET_INETKUN_SPEAK_DOWN" 2 56)
              ("SE_CTR_MSET_HOMEBUTTON" 2 127)
              ("SE_CTR_MSET_OCAM_LAMP1" 2 64)
              ("SE_CTR_MSET_OCAM_LAMP2" 2 64)
              ("SE_CTR_MSET_OCAM_LAMP3" 2 64)
              ("SE_CTR_MSET_HOME_LIGHT" 2 110)
              ("SE_CTR_MSET_SLIDE_BTN_CENTER" 2 32)
              ("SE_CTR_MSET_SLIDE_BTN_EDGE" 2 16)
              ("SE_TWL_SET_USER_COLOR_TOP" 4 96)
              ("SE_TWL_SET_USER_COLOR_BOTTOM" 4 96)
              ("SE_CTR_COMMON_SILENT" 3 127)
              ("SE_CTR_COMMON_BUTTON" 3 86)
              ("SE_CTR_COMMON_OK" 3 64)
              ("SE_CTR_COMMON_RETURN" 3 100)
              ("SE_CTR_COMMON_CANCEL" 3 100)
              ("SE_CTR_COMMON_WAIT" 3 72)
              ("SE_CTR_COMMON_WAIT_END" 3 100)
              ("SE_CTR_COMMON_CONNECT" 3 90)
              ("SE_CTR_COMMON_ERROR" 3 116)
              ("SE_CTR_COMMON_NOTICE" 3 40)
              ("SE_CTR_COMMON_NOMOVE" 3 20)
              ("SE_CTR_COMMON_SCROLL" 3 60)
              ("SE_CTR_COMMON_SCROLL_LIST" 3 60)
              ("SE_CTR_COMMON_SCROLL_TEXT" 3 18)
              ("SE_CTR_COMMON_SCROLL_END" 3 16)
              ("SE_CTR_COMMON_DIALOG" 3 110)
              ("SE_CTR_COMMON_SYSAPPLET_END" 3 90)) do
              (assert (string= expected-name (name (nintendo-ware::xsar-sound-string-index sound))))
              (assert (= file-id (nintendo-ware::xsar-sound-file-id sound)))
              (assert (= volume (nintendo-ware::xsar-sound-volume sound))))
      (let ((banks (nintendo-ware::xsar-banks-table-entries (nintendo-ware::xsar-info-banks info))))
        (assert (= 5 (length banks)))
        (loop for bank across banks for (expected-name file-id) in
              '(("BANK_CTR_MSET_BGM" 7)
              ("BANK_TWL_SETTING" 8)
              ("BANK_CTR_MSET_SE" 9)
              ("BANK_TWL_SE" 10)
              ("BANK_CTR_COMMON" 11)) do
                (assert (string= expected-name (name (nintendo-ware::xsar-bank-string-index bank))))
                (assert (= file-id (nintendo-ware::xsar-bank-file-id bank))))))
    ;; Read the whole event stream, including events after finish/return commands.
    (loop for id from 0 below 5 for expected in '(31747 2443 506 481 48) do
      (assert (= expected (length (nintendo-ware::xseq-events (aref contents id))))))
    ;; Item effects are relative to flags, not the surrounding item. Note flags
    ;; are absent in this asset and must remain NIL, not materialized defaults.
    (loop for file-id in '(5 6)
          for expected-items in '(((1.0f0 0)) ((1.0f0 0) (0.8f0 1) (1.8f0 1) (1.0f0 2))) do
      (let ((items (nintendo-ware::xwsd-item-table-entries
                    (nintendo-ware::xwsd-info-items (nintendo-ware::xwsd-info (aref contents file-id))))))
        (assert (= (length expected-items) (length items)))
        (loop for item across items for (pitch wave-index) in expected-items do
          (let* ((parameters (nintendo-ware::xwsd-item-parameters item))
                 (sends (nintendo-ware::xwsd-parameters-sends parameters))
                 (envelope (nintendo-ware::xwsd-parameters-envelope parameters))
                 (notes (nintendo-ware::xwsd-note-table-entries (nintendo-ware::xwsd-item-notes item)))
                 (events (nintendo-ware::xwsd-event-table-entries
                           (nintendo-ware::xwsd-track-events
                            (aref (nintendo-ware::xwsd-track-table-entries (nintendo-ware::xwsd-item-tracks item)) 0)))))
            (assert (= pitch (nintendo-ware::xwsd-parameters-pitch parameters)))
            (assert (= 64 (nintendo-ware::packed-pan-pan (nintendo-ware::xwsd-parameters-pan-info parameters))))
            (assert (= 127 (nintendo-ware::xwsd-sends-main-send sends)))
            (assert (equalp #(0 0) (nintendo-ware::xwsd-sends-auxiliary-sends sends)))
            (assert (equal '(127 127 127 127 127)
                           (list (nintendo-ware::xwsd-envelope-attack envelope)
                                 (nintendo-ware::xwsd-envelope-decay envelope)
                                 (nintendo-ware::xwsd-envelope-sustain envelope)
                                 (nintendo-ware::xwsd-envelope-hold envelope)
                                 (nintendo-ware::xwsd-envelope-release envelope))))
            (assert (= 1 (length notes) (length events)))
            (assert (= wave-index (nintendo-ware::xwsd-note-wave-index (aref notes 0))))
            (assert (null (nintendo-ware::xwsd-parameters-envelope
                           (nintendo-ware::xwsd-note-parameters (aref notes 0)))))
            (assert (= 0.0f0 (nintendo-ware::xwsd-event-position (aref events 0))))
            ;; This asset encodes zero, not an assumed indefinite duration.
            (assert (= 0.0f0 (nintendo-ware::xwsd-event-length (aref events 0))))
            (assert (= 0 (nintendo-ware::xwsd-event-note-index (aref events 0))))))))
    ;; Follow all seven CWARs, not just the first archive or wave in a table.
    (let ((encoded-bytes 0))
      (loop for file-id from 12 below 19
            for expected-waves in
            '(((2 32000 17393))
              ((1 32000 475) (1 32000 259) (2 16000 1033))
              ((1 44100 17040) (1 44100 34914) (1 44100 16271) (2 32000 29542) (2 22050 8319) (2 22050 9184) (2 44100 26460) (2 44100 20550) (2 32000 14022) (2 44100 40337) (2 44100 5114) (2 32000 2149) (2 44100 1598))
              ((1 48000 1456) (1 44100 1607))
              ((1 16000 59) (2 32728 3959) (2 44100 3630) (1 32000 1056))
              ((2 32000 227))
              ((1 44000 356) (2 32000 6083) (2 24000 14011) (2 44100 6796) (2 16000 6000) (2 44100 1233) (1 32000 227) (1 32000 261) (2 32000 625) (2 16000 1033))) do
              (let ((waves (nintendo-ware::xwar-waves (aref contents file-id))))
                (assert (= (length expected-waves) (length waves)))
                (loop for wave across waves for (codec rate sample-count) in expected-waves do
                  (let* ((wave-info (nintendo-ware::xwav-info wave))
                         (channels (nintendo-ware::xwav-info-channels wave-info)))
                    (assert (string= "CWAV" (nintendo-ware::header-magic (nintendo-ware::xwav-header wave))))
                    (assert (eq (ecase codec (1 'nintendo-ware::pcm-16) (2 'nintendo-ware::dsp-adpcm))
                                (nintendo-ware::xwav-info-codec wave-info)))
                    (assert (= rate (nintendo-ware::xwav-info-sample-rate wave-info)))
                    (assert (= sample-count (nintendo-ware::xwav-info-loop-end wave-info)))
                    (assert (= 1 (length channels)))
                    (when (= codec 2)
                      (assert (typep (nintendo-ware::xwav-channel-codec-info (aref channels 0))
                                     'nintendo-ware::xwav-dsp-adpcm-info)))
                    (let ((data (nintendo-ware::xwav-channel-data (aref channels 0))))
                      (ecase codec
                        (1 (assert (typep data '(simple-array (signed-byte 16) (*))))
                           (assert (= sample-count (length data)))
                           (incf encoded-bytes (* 2 (length data))))
                        (2 (assert (typep data '(simple-array (unsigned-byte 8) (*))))
                           (incf encoded-bytes (length data)))))))))
      (assert (= 273362 encoded-bytes))))
  (run-tiger-tests)
  (format t "Real mset.bcsar regression passed: 19 embedded files and 34 waves.~%"))

(defun run-tiger-tests ()
  (let* ((archive (nintendo-ware::read-file
                   'nintendo-ware::xsar
                   (asdf:system-relative-pathname :cl-nintendo-ware #P"test/data/TigerSound.bcsar")))
         (sounds (nintendo-ware::xsar-sounds-table-entries
                  (nintendo-ware::xsar-info-sounds (nintendo-ware::xsar-info archive)))))
    (assert (= 82 (length sounds)))
    (assert (= 16 (length (nintendo-ware::xsar-files archive))))
    (loop for sound across sounds
          for detail = (nintendo-ware::xsar-sound-detail sound)
          when (typep detail 'nintendo-ware::xsar-stream-sound-info) do
            (let ((tracks (nintendo-ware::xsar-stream-sound-info-tracks detail)))
              (assert tracks)
              (loop for track across (nintendo-ware::xsar-stream-track-table-entries tracks)
                    when track do
                      (assert (nintendo-ware::xsar-stream-track-channels track))))))
  (format t "Real TigerSound.bcsar stream track regression passed.~%"))
