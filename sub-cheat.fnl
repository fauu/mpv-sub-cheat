;; mpv-sub-cheat
;;
;; Target: Fennel 1.5.0
;;-----------------------------------------------------------------------------

;; OPTIONS

(local script-options-prefix :sub-cheat)

;; Defaults. Can be overriden like so:
;;   `--script-opts=sub-cheat-margin-bottom=3,sub-cheat-style="\fs30\1a&H55&"`
;; For style codes see https://aegisub.org/docs/latest/ass_tags/
(local options {
  :margin-bottom 9 ;; (text lines)
  :lifetime 8 ;; (seconds)
  ;; Ignore subtitles containing the following codes (dot-separated)
  :ass-filter "move.fr.kf.fad.k"
  :style "\\an2\\fs36\\bord1.5\\shad1\\be2\\1c&HFFFFFF&" ;; Base style
  ;; NOTE: The styles also apply to all the following lines unless overridden
  :style-1 "\\3c&H333333&\\4c&H333333&\\1a&H77&" ;; Style for line 1 (top)
  :style-2 "\\bord1.5\\3c&H663399&\\4c&H000000&\\1a&H00&" ;; ... line 2 (mid)
  :style-3 "\\3c&H663300&" ;; ... line 3 (bottom)
})

;; STATE

(var fallback-sid nil)
(var fallback-ass-overlay nil)
(var fallback-lines [])
(var fallback-lines-expire-timers [])
(var subs-we-revealed-primary? false)
(fn state-clear []
  (set fallback-sid nil)
  (set fallback-ass-overlay nil)
  (set fallback-lines [])
  (set fallback-lines-expire-timers [])
  (set subs-we-revealed-primary? true))

;; A failed macro version: the names inside the `state-clear` fn are mangled and
;; don't match the outer names
;;
;;(macro define-state [state-map]
;;  (let [names []
;;        vals []
;;        clear-body []]
;;    (each [k v (pairs state-map)]
;;      (table.insert names (sym k))
;;      (table.insert vals v))
;;
;;    (table.insert vals
;;      `(fn []
;;        (set ,(list (unpack names)) (values ,(unpack vals)))))
;;    (table.insert names (sym :state-clear))
;;
;;    `(var ,(list (unpack names)) (values ,(unpack vals)))))
;;(define-state {
;;  :fallback-sid nil
;;  :fallback-ass-overlay nil
;;  :fallback-lines []
;;  :fallback-lines-expire-timers []
;;  :subs-we-revealed-primary? false
;;})

;; GENERAL UTILITIES

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

;; SUB UTILITIES

(fn sub-track-property [sub-track property-base]
  (.. (if (= sub-track 2) :secondary- "") property-base))

(fn has-special-ass-code? [s]
  (var found false)
  (each [_ code (ipairs options.ass-filter) &until found]
    (when (s:find code)
      (set found true)))
  found)

;; CORE LOGIC

(fn fallback-text-showing? []
  "Whether the fallback subtitle overlay is showing (this can be true even if
  it's empty)"
  (and fallback-ass-overlay (not fallback-ass-overlay.hidden)))

(fn fallback-text-empty? []
  (or (not fallback-ass-overlay) (= fallback-ass-overlay.data "")))

(fn fallback-text-show []
  (let [num-lines (length fallback-lines)
        data (if (= num-lines 0)
               ""
               (let [lines-with-nl (map #(.. (. $1 :text) "\\N") fallback-lines)
                     padded-lines  (array-pad-left lines-with-nl 3 "")
                     margin        (string.rep "\\N" options.margin-bottom)
                     data*         (string.format
                                     "{%s%s}%s{%s}%s{%s}%s%s"
                                     options.style
                                     options.style-1 (. padded-lines 1)
                                     options.style-2 (. padded-lines 2)
                                     options.style-3 (. padded-lines 3)
                                     margin)]
                 data*))]
    (doto fallback-ass-overlay
      (tset :data data)
      ;; We don't hide it even when it's empty to make other logic simpler
      (tset :hidden false)
      (: :update))))

(fn fallback-text-hide []
  (doto fallback-ass-overlay
    (tset :hidden true)
    (: :update)))

(fn subs-reveal []
  (fallback-text-show)
  (when (and
          (= fallback-sid 2)
          (= (mp.get_property :sub-visibility) :no))
    (mp.set_property :sub-visibility :yes)
    (set subs-we-revealed-primary? true)))

(fn subs-hide []
  (fallback-text-hide)
  (when subs-we-revealed-primary?
    (mp.set_property :sub-visibility :no)
    (set subs-we-revealed-primary? false)))

(fn fallback-lines-expire-timers-remove [timer]
  (for [i 1 (length fallback-lines-expire-timers)]
    (let [i-timer (. fallback-lines-expire-timers i)]
      (when (= i-timer timer)
        (table.remove fallback-lines-expire-timers i)
        (lua :break)))))

(fn fallback-lines-expire [timer target-hash]
  (fallback-lines-expire-timers-remove timer)
  (for [i 1 (length fallback-lines)]
    (let [i-hash (-> fallback-lines (. i) (. :hash))]
      (when (= i-hash target-hash)
        (table.remove fallback-lines i)
        (when (and fallback-text-showing? (not fallback-text-empty?))
          (fallback-text-show))
        (lua :break)))))

(fn fallback-lines-add [sub-text]
  ;; Using a string representation of time to avoid surprises
  (let [time       (mp.get_property :time-pos/full)
        first-char (sub-text:sub 1 1)
        poor-hash  (.. time (length sub-text) first-char)]
    (table.insert fallback-lines {:hash poor-hash :text sub-text})
    ;; Keep `fallback-lines` size capped to 3
    (when (> (length fallback-lines) 3)
      (table.remove fallback-lines 1))
    ;; Schedule line expiration. Keep the timer around to pause it if
    ;; the playback is paused
    (let [timer (mp.add_timeout
                  options.lifetime
                  #(fallback-lines-expire timer poor-hash))]
      (table.insert fallback-lines-expire-timers timer))))

(fn fallback-lines-clear []
  (set fallback-lines []))

;; EVENT HANDLERS

(fn handle-subs-reveal-key-event [event-info]
  (match event-info.event
    :down (subs-reveal)
    :up   (subs-hide)))

(fn handle-fallback-sub-text [_ sub-text]
  (when (string-and-non-empty? sub-text)
    ;; TODO: No `secondary-sub-text-ass` on current mpv ver. so the filtering
    ;;       is pointless if `fallback-sid` is 2. v0.39 might have
    ;;       `secondary-sub-text/ass`?
    (let [ass (mp.get_property (sub-track-property fallback-sid :sub-text-ass))]
      (when (or (not ass) (not (has-special-ass-code? ass))) ;; Skip signs etc.
        (-> sub-text
          (: :gsub "\n" "\\N") ;; Breaks display formatting otherwise
          (fallback-lines-add))
        ;; If text is showing, update to show the new line too
        (when (fallback-text-showing?)
          (subs-reveal))))))

(fn handle-seeking []
  (when (fallback-text-showing?)
    (fallback-text-hide))
  (fallback-lines-clear)
  (when fallback-ass-overlay
    (fallback-ass-overlay:update)))

(fn handle-pause [_ paused?]
  ;; Pressing a pause key while the fallback reveal key is being held causes
  ;; a fake depress event for the latter (why?), causing the fallback text to
  ;; disappear. Which is why we re-show it here when pause is activated
  (when fallback-ass-overlay
    (if paused?
      (fallback-text-show)
      (fallback-text-hide)))
  ;; Pause expire timers so that fallback subtitles don't disappear during pause
  (each [_ timer (ipairs fallback-lines-expire-timers)]
    (if paused?
      (timer:stop)
      (timer:resume))))

(fn activate []
  (let [sid-secondary (mp.get_property :current-tracks/sub2/id)]
    (set fallback-sid (if sid-secondary 2 1)))
  (mp.set_property_bool
    (sub-track-property fallback-sid :sub-visibility)
    false)
  (doto fallback-ass-overlay
    (set (mp.create_osd_overlay :ass-events))
    (tset :hidden true))
  (mp.observe_property
    (sub-track-property fallback-sid :sub-text)
    :string
    handle-fallback-sub-text))

(fn handle-sub-track-change [_ sid-primary]
  (state-clear)
  ;; TODO: Deactivate otherwise?
  (when sid-primary
    (activate)))

;; MAIN

((. (require :mp.options) :read_options) options script-options-prefix)

;; Convert the `ass-filter` option value to a more convenient format
(tset options :ass-filter
  (icollect [identifier (options.ass-filter:gmatch "[^%.]+")]
    (.. "\\" identifier)))

(mp.observe_property :current-tracks/sub/id :number handle-sub-track-change)
(mp.observe_property :seeking :bool handle-seeking)
(mp.observe_property :pause :bool handle-pause)

(mp.add_key_binding
  nil
  :peek-cheat-subs
  handle-subs-reveal-key-event
  {:complex true})

nil
