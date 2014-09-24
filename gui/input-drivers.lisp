(in-package :mezzanine.gui.input-drivers)

(defvar *keyboard-forwarder* nil)
(defvar *mouse-forwarder* nil)

(defconstant +extended-scan-code+ #xE0)

(defvar *extended-key-alist*
  '((#x5B #\Left-Super)
    (#x1D #\Right-Control)
    (#x5C #\Right-Super)
    (#x38 #\Right-Meta)
    (#x5D #\Menu)
    (#x52 #\Insert)
    (#x47 #\Home)
    (#x49 #\Page-Up)
    (#x53 #\Delete)
    (#x4F #\End)
    (#x51 #\Page-Down)
    (#x48 #\Up-Arrow)
    (#x4B #\Left-Arrow)
    (#x50 #\Down-Arrow)
    (#x4D #\Right-Arrow)
    (#x35 #\KP-Divide)
    (#x1C #\KP-Enter)))

;; FIXME: use the proper character names for the special keys.
;; Need to modify the cross-compiler to use a custom read-table.
(defvar *translation-table*
  #(nil #\Esc #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9 #\0 #\- #\= #\Backspace
    #\Tab #\Q #\W #\E #\R #\T #\Y #\U #\I #\O #\P #\[ #\] #\Newline
    #\Left-Control #\A #\S #\D #\F #\G #\H #\J #\K #\L #\; #\' #\`
    #\Left-Shift #\# #\Z #\X #\C #\V #\B #\N #\M #\, #\. #\/ #\Right-Shift #\KP-Multiply
    #\Left-Meta #\Space #\Caps-Lock #\F1 #\F2 #\F3 #\F4 #\F5
    #\F6 #\F7 #\F8 #\F9 #\F10 nil nil
    #\KP-7 #\KP-8 #\KP-9 #\KP-Minus
    #\KP-4 #\KP-5 #\KP-6 #\KP-Plus
    #\KP-1 #\KP-2 #\KP-3 #\KP-0 #\KP-Period nil nil #\\ #\F11 #\F12 nil nil nil nil nil nil nil
    nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil)
  "An array, converting from non-extended scancodes to HID keys.")

(defun keyboard-forwarder-thread ()
  ;; Read bytes from the keyboard and translate them into HID events for the input manager.
  (loop
     (handler-case
         (let ((byte (mezzanine.supervisor:ps/2-key-read)))
           (cond
             ((eql byte +extended-scan-code+)
              ;; Reading extended scan code.
              (setf byte (mezzanine.supervisor:ps/2-key-read))
              (let ((extended-key (assoc (logand byte #x7F) *extended-key-alist*)))
                (when extended-key
                  ;; Got a recognized extended key, submit it.
                  (mezzanine.gui.compositor:submit-key extended-key (logtest byte #x80)))))
             (t (let ((key (aref *translation-table* (logand byte #x7F))))
                  (when key
                    ;; Got a regular key, submit it.
                    (mezzanine.gui.compositor:submit-key key (logtest byte #x80)))))))
       (error (c)
         (format t "Aieee ~S.~%" c)))))

(defun mouse-forwarder-thread ()
  ;; Read bytes from the mouse and turn them into HID events.
  (loop
     (let ((byte-1 (mezzanine.supervisor:ps/2-aux-read)))
       ;; Check sync bit.
       (when (logtest byte-1 #b00001000)
         (let ((byte-2 (mezzanine.supervisor:ps/2-aux-read))
               (byte-3 (mezzanine.supervisor:ps/2-aux-read)))
           (mezzanine.gui.compositor:submit-mouse
            (logand byte-1 #b111) ; Buttons 1 to 3.
            (logior byte-2 (if (logtest byte-1 #b00010000) -256 0)) ; x-motion
            (- (logior byte-3 (if (logtest byte-1 #b00100000) -256 0))))))))) ; y-motion

(when *keyboard-forwarder*
  (format t "Restarting keyboard forwarding thread.")
  (mezzanine.supervisor:destroy-thread *keyboard-forwarder*))
(setf *keyboard-forwarder* (mezzanine.supervisor:make-thread 'keyboard-forwarder-thread
                                                             :name "Keyboard Forwarder"))

(when *mouse-forwarder*
  (format t "Restarting mouse forwarding thread.")
  (mezzanine.supervisor:destroy-thread *mouse-forwarder*))
(setf *mouse-forwarder* (mezzanine.supervisor:make-thread 'mouse-forwarder-thread
                                                          :name "Mouse Forwarder"))
(format t "~S  ~S~%" *keyboard-forwarder* *mouse-forwarder*)