;;;; mpv-sub-cheat
;;;;
;;;;   Hold a key to peek at the three most recent subtitles.
;;;;
;;;;   Target: Fennel 1.5.1

;;; --- OPTIONS ----------------------------------------------------------------

(local script-name           :mpv-sub-cheat)
(local script-options-prefix :sub-cheat)
(local cheat-lines-capacity  3)
(local ass-line-break        "\\N")
(local dot-separator-pattern "[^%.]+")

;;; Defaults. Can be overriden like so:
;;;   `--script-opts=sub-cheat-margin-bottom=3,sub-cheat-style="\fs30\1a&H55&"`
;;; For style codes consult https://aegisub.org/docs/latest/ass_tags/
(local options {
  :enabled :no
  :margin-bottom 9 ; (text lines)
  :lifetime 8 ; (seconds)

  ;; [DOES NOT WORK YET]
  ;; Ignore subtitles containing the following codes (dot-separated).
  ;; The value is converted into an array of full-codes at startup
  :ass-filter "move.fr.kf.fad.k"

  :style "\\an2\\fs38\\bord1.5\\shad1\\be2\\1c&HFFFFFF&" ; Base style
  ;; NOTE: The styles also apply to all the following lines unless overridden
  :style-1 "\\3c&H333333&\\4c&H333333&\\1a&H77&" ; Style for line 1 (top)
  :style-2 "\\bord1.5\\3c&H993366&\\4c&H000000&\\1a&H00&" ; ... line 2 (mid)
  :style-3 "\\3c&H1166CC&" ; ... line 3 (bottom)
})

;;; --- META STATE -------------------------------------------------------------

(var enabled?   false) ; Whether the user wants us to be working
(var activated? false) ; Whether we're actually working
;; (true, false) obtains when e.g. the user presses the 'enable' binding but
;; there are no subtitles loaded

;;; --- PER-ACTIVATION STATE ---------------------------------------------------

(var cheat-track               nil)   ; 1/2 for primary/secondary
(var cheat-ass-overlay         nil)   ; <- (mp.create_osd_overlay :ass-events)
(var cheat-lines               [])    ; Array of 0-cap. strings, earliest first
(var cheat-lines-expire-timers [])    ; <- (mp.add_timeout ...)
(var subs-we-revealed-primary? false)
(fn state-clear []
  (set cheat-track               nil)
  (set cheat-ass-overlay         nil)
  (set cheat-lines               [])
  (set cheat-lines-expire-timers [])
  (set subs-we-revealed-primary? true))

;;; A failed macro version of the above: the names inside the `state-clear` fn
;;; are mangled and don't match the outer names
;;;
;;;   (macro define-state [state-map]
;;;     (let [names []
;;;           vals []
;;;           clear-body []]
;;;       (each [k v (pairs state-map)]
;;;         (table.insert names (sym k))
;;;         (table.insert vals v))
;;;
;;;       (table.insert vals
;;;         `(fn []
;;;           (set ,(list (unpack names)) (values ,(unpack vals)))))
;;;       (table.insert names (sym :state-clear))
;;;
;;;       `(var ,(list (unpack names)) (values ,(unpack vals)))))
;;;   (define-state {
;;;     :cheat-track nil
;;;     :cheat-ass-overlay nil
;;;     :cheat-lines []
;;;     :cheat-lines-expire-timers []
;;;     :subs-we-revealed-primary? false
;;;   })

;;; --- GENERAL UTILITIES ------------------------------------------------------

(fn string-and-non-empty? [s]
  (and (not= s nil) (not= s "")))

(fn array-pad-left [arr up-to padding-value]
  (let [result (or arr [])
        n      (length result)]
    (for [i (+ n 1) up-to]
      (table.insert result 1 padding-value))
    result))

(fn map [f arr]
  (icollect [_ v (ipairs arr)]
    (f v)))

;;; --- SUB UTILITIES ----------------------------------------------------------

(fn sub-track-property [sub-track property-base]
  (let [prefix (if (= sub-track 2) :secondary- "")]
    (.. prefix property-base)))

(fn cheat-sub-property [property-base]
  (sub-track-property cheat-track property-base))

(fn has-special-ass-code? [s]
  (var found false)
  (each [_ code (ipairs options.ass-filter) &until found]
    (when (s:find code)
      (set found true)))
  found)

(fn append-ass-line-break [s]
  (.. s ass-line-break))

;;; --- SUB LOGIC --------------------------------------------------------------

(fn cheat-text-showing? []
  "Whether the cheat subtitle overlay is showing (this can be true even if
  it's empty and therefore not visible)"
  (and cheat-ass-overlay (not cheat-ass-overlay.hidden)))

(fn cheat-text-empty? []
  (or (not cheat-ass-overlay) (= cheat-ass-overlay.data "")))

(fn make-cheat-ass-overlay-data []
  (let [num-lines (length cheat-lines)]
    (if (= num-lines 0)
      ""
      (let [lines-with-nl (map #(append-ass-line-break $.text) cheat-lines)
            padded-lines  (array-pad-left lines-with-nl cheat-lines-capacity "")
            margin        (string.rep ass-line-break options.margin-bottom)]
        (string.format
           "{%s%s}%s{%s}%s{%s}%s%s"
           options.style
           options.style-1 (. padded-lines 1)
           options.style-2 (. padded-lines 2)
           options.style-3 (. padded-lines 3)
           margin)))))

(fn cheat-text-show []
  (doto cheat-ass-overlay
    (tset :data (make-cheat-ass-overlay-data))
    ;; We don't hide it even when it's empty to make other logic simpler
    (tset :hidden false)
    (: :update)))

(fn cheat-text-hide []
  (doto cheat-ass-overlay
    (tset :hidden true)
    (: :update)))

(fn subs-reveal []
  (cheat-text-show)
  (when (and
          (= cheat-track 2)
          (= (mp.get_property :sub-visibility) :no))
    (mp.set_property :sub-visibility :yes)
    (set subs-we-revealed-primary? true)))

(fn subs-hide []
  (cheat-text-hide)
  (when subs-we-revealed-primary?
    (mp.set_property :sub-visibility :no)
    (set subs-we-revealed-primary? false)))

(fn cheat-lines-expire-timers-remove [timer]
  (for [i 1 (length cheat-lines-expire-timers)]
    (let [i-timer (. cheat-lines-expire-timers i)]
      (when (= i-timer timer)
        (table.remove cheat-lines-expire-timers i)
        (lua :break)))))

(fn cheat-lines-expire [timer target-hash]
  (cheat-lines-expire-timers-remove timer)
  (for [i 1 (length cheat-lines)]
    (let [i-hash (-> cheat-lines (. i) (. :hash))]
      (when (= i-hash target-hash)
        (table.remove cheat-lines i)
        (when (and cheat-text-showing? (not cheat-text-empty?))
          (cheat-text-show))
        (lua :break)))))

(fn cheat-lines-add [sub-text]
  ;; Using a string representation of time to avoid surprises
  (let [sub-text*  (sub-text:gsub "\n" ass-line-break)
        time       (mp.get_property :time-pos/full)
        first-char (sub-text*:sub 1 1)
        poor-hash  (.. time (length sub-text*) first-char)]
    (table.insert cheat-lines {:hash poor-hash :text sub-text*})
    ;; Keep `cheat-lines` size capped
    (when (> (length cheat-lines) cheat-lines-capacity)
      (table.remove cheat-lines 1))
    ;; Schedule line expiration. Keep the timer around to pause it when
    ;; the playback is paused
    (let [timer (mp.add_timeout
                  options.lifetime
                  #(cheat-lines-expire timer poor-hash))]
      (table.insert cheat-lines-expire-timers timer))))

(fn cheat-lines-clear []
  (set cheat-lines []))

(fn sync-cheat-track []
  (let [sid-secondary (mp.get_property :current-tracks/sub2/id)]
    (set cheat-track (if sid-secondary 2 1)))
  (mp.set_property_bool (cheat-sub-property :sub-visibility) false)
  (cheat-lines-clear))

;;; --- EVENT HANDLERS ---------------------------------------------------------

(fn handle-cheat-sub-text [_ sub-text]
  (when (string-and-non-empty? sub-text)
    ;; Re-enable filtering on v0.39 once we're be able to use
    ;; `secondary-sub-text/ass` (v0.38 only has `sub-text-ass`).
    ;;
    ;;  (let [ass (mp.get_property (cheat-sub-property "sub-text/ass"))]
    ;;    (when (or (not ass) (not (has-special-ass-code? ass))) ; Skip signs+
    (cheat-lines-add sub-text)
    ;; If text is showing, update to show the new line too
    (when (cheat-text-showing?)
      (subs-reveal))))

(fn handle-seeking []
  (when (cheat-text-showing?)
    (cheat-text-hide))
  (cheat-lines-clear)
  (when cheat-ass-overlay
    (cheat-ass-overlay:update)))

(fn handle-pause [_ paused?]
  ;; Pressing a pause key while the peek key is being held causes a fake depress
  ;; event for the latter (why?), causing the cheat text to disappear. Which
  ;; is why we re-show it here when pause is activated.
  ;;
  ;; This still leaves the problem of the text blinking, but it's probably best
  ;; we can do short of remapping the pause key. In case we wanted to do that,
  ;; here's the starting point:
  ;;   (let [all-keybindings (mp.get_property_native :input-bindings)]
  ;;     (each [_ binding (ipairs all-keybindings)]
  ;;       (when (= binding.cmd "cycle pause")
  ;;         (print binding.key))))
  (when cheat-ass-overlay
    (if paused?
      (subs-reveal)
      (subs-hide)))
  ;; Stop the expire timers during pause
  (each [_ timer (ipairs cheat-lines-expire-timers)]
    (if paused?
      (timer:stop)
      (timer:resume))))

(fn activate []
  (mp.observe_property :seeking :bool handle-seeking)
  (mp.observe_property :pause :bool handle-pause)
  (sync-cheat-track)
  (doto cheat-ass-overlay
    (set (mp.create_osd_overlay :ass-events))
    (tset :hidden true))
  (mp.observe_property
    (cheat-sub-property :sub-text)
    :string
    handle-cheat-sub-text)
  (set activated? true))

(fn deactivate []
  (mp.unobserve_property handle-seeking)
  (mp.unobserve_property handle-pause)
  (mp.unobserve_property handle-cheat-sub-text)
  (mp.set_property (cheat-sub-property :sub-visibility) :yes)
  (set activated? false))

(fn handle-sub-track [_ sid-primary]
  (case [sid-primary activated?]
    [sid true ] (sync-cheat-track)
    [sid false] (activate)
    [_   true ] (deactivate)
    [_   false] (mp.osd_message
                  (.. script-name " ON but no subtitle tracks selected"))))

(fn enable []
  (state-clear)
  (mp.observe_property :current-tracks/sub/id :number handle-sub-track)
  (set enabled? true))

(fn disable []
  (mp.unobserve_property handle-sub-track)
  (when activated?
    (deactivate))
  (set enabled? false))

(fn handle-sub-cheat-toggle-enabled-pressed []
  (if enabled? (disable) (enable))
  (let [state (if enabled? :ON :OFF)
        msg (.. script-name " " state)]
    (mp.osd_message msg 5)))

(fn handle-subs-peek-key-event [event-info]
  (when activated?
    (match event-info.event
      :down (subs-reveal)
      :up   (subs-hide))))

;;; --- PROCESS OPTIONS --------------------------------------------------------

(let [opt (require :mp.options)]
  (opt.read_options options script-options-prefix))

;;; Convert the `ass-filter` option value to a more convenient format
(tset options :ass-filter
  (icollect [identifier (options.ass-filter:gmatch dot-separator-pattern)]
    (.. "\\" identifier)))

;;; --- MAIN -------------------------------------------------------------------

(mp.add_key_binding
  nil
  :sub-cheat-toggle-enabled
  handle-sub-cheat-toggle-enabled-pressed)
(mp.add_key_binding
  nil
  :sub-cheat-peek
  handle-subs-peek-key-event
  {:complex true})

(when (= options.enabled :yes)
  (enable))

nil
