# autocue.cue_file.liq
# 2024-04-10 - Moonbase59
# 2024-04-12 - Toots: re-organize to integrate as core autocue implementation.
# 2024-04-12 - Moonbase59 - re-introduce `liq_duration` as `liq_cue_duration`.
# 2024-04-19 - Moonbase59 - rename to "autocue.cue_file.liq"
#                         - update to use same `cue_file` as master branch
# 2024-04-20 - Moonbase59 - allow floats as loudness values
# 2024-04-24 - Moonbase59 - rework to follow same logic as autocue2
# 2024-04-25 - Moonbase59 - handle old RG1/mp3gain positive loudness reference
#                         - add nice option (+10) for Linux users
# 2024-04-30 - Toots & Moonbase59 - Fix extra_metadata bug, make these optional
#                                   replaygain_track_gain,
#                                   replaygain_reference_loudness

# Lots of debugging output for AzuraCast in this, will be removed eventually.

# --- Copy-paste Azuracast LS Config, second input box BEGIN ---

# Initialize settings for cue_file autocue implementation
let settings.autocue.cue_file = ()

let settings.autocue.cue_file.path =
  settings.make(
    description=
      "Path of the cue_file binary.",
    "cue_file"
  )

let settings.autocue.cue_file.fade_in =
  settings.make(
    description=
      "Default fade-in duration if no specified by the user.",
    0.1
  )

let settings.autocue.cue_file.fade_out =
  settings.make(
    description=
      "Default fade-out duration if no specified by the user.",
    2.5
  )

let settings.autocue.cue_file.timeout =
  settings.make(
    description=
      "Timeout (in seconds) for cue_file executions.",
    60.0
  )

let settings.autocue.cue_file.target =
  settings.make(
    description=
      "Loudness target in LUFS.",
    -18.0
  )

let settings.autocue.cue_file.silence =
  settings.make(
    description=
      "Silence level (for cue points) in LU/dB below track loudness.",
    -42.0
  )

let settings.autocue.cue_file.overlay =
  settings.make(
    description=
      "Start overlay level in LU/dB below track loudness.",
    -8.0
  )

let settings.autocue.cue_file.longtail =
  settings.make(
    description=
      "More than so many seconds of calculated overlay are considered a long \
       tail.",
    15.0
  )

let settings.autocue.cue_file.overlay_longtail =
  settings.make(
    description=
      "Extra LU/dB level below overlay loudness, to recalculate songs with long \
       tails.",
    -15.0
  )

let settings.autocue.cue_file.blankskip =
  settings.make(
    description=
      'Skip blank (silence) within song (get rid of "hidden tracks".)',
    false
  )

let settings.autocue.cue_file.unify_loudness_correction =
  settings.make(
    description=
      'Unify `replaygain_track_gain` and `liq_amplify`. If enabled, this will \
       ensure both have the same value, with `replaygain_track_gain` taking \
       precedence if see it and we have a `replaygain_reference_loudness`. \
       Allows scripts to amplify on either value, without loudness jumps.',
    true
  )

let settings.autocue.cue_file.write_tags =
  settings.make(
    description=
      "Write back `liq_*` tags to original audio file. Use with care, as \
       ffmpeg can't write all tags to all file types! Ensure you have enough \
       free space to hold a copy of the original file.",
    false
  )

let settings.autocue.cue_file.force_analysis =
  settings.make(
    description=
      'Force re-analysis even when all needed data could be read from file tags.',
    false
  )

let settings.autocue.cue_file.nice =
  settings.make(
    description=
      'Linux only: Use nice for `cue_file` operations?',
    false
  )

stdlib_metadata = metadata

# Compute cue_file data
# @flag extra
def cue_file(~request_metadata, ~file_metadata, filename) =
  timeout = settings.autocue.cue_file.timeout()
  target = settings.autocue.cue_file.target()
  silence = settings.autocue.cue_file.silence()
  overlay = settings.autocue.cue_file.overlay()
  longtail = settings.autocue.cue_file.longtail()
  overlay_longtail = settings.autocue.cue_file.overlay_longtail()
  blankskip = settings.autocue.cue_file.blankskip()
  write_tags = settings.autocue.cue_file.write_tags()
  force_analysis = settings.autocue.cue_file.force_analysis()
  nice = settings.autocue.cue_file.nice()

  label = "autocue.cue_file"

  # combine request & file metadata into one list, where
  # request_metadata (annotations) takes precedence
  metadata = list.fold(
    fun(res, entry) ->
      if list.assoc.mem(fst(entry), res) then
        res
      else
        [...res, entry]
      end,
      request_metadata,
      file_metadata
  )

  m = ref(metadata)

  # so we can use meta["something"]
  meta = m()

  if
    meta["liq_cue_file"] == "false"
  then
    log(
      level=2,
      label=label,
      'Skipping cue_file for "#{filename}" because liq_cue_file=false \
       forbids it.'
    )
    null()
  else
    log(
      level=3,
      label=label,
      'Now autocueing: "#{filename}"'
    )

    l = list.sort.natural(stdlib_metadata.cover.remove(meta))
    log(
      level=4,
      label=label,
      'Metadata seen for "#{filename}":'
    )
    list.iter(fun (v) -> log(level=4, label=label, "#{v}"), l)

    log(
      level=4,
      label=label,
      'liq_blankskip=#{meta["liq_blankskip"]}, songtype=#{meta["songtype"]}, \
       jingle_mode=#{meta["jingle_mode"]}'
    )

    # Blank skipping can be set globally using `settings.autocue.cue_file.blankskip`.
    # For AzuraCast, we override that setting if we detect "jingle_mode",
    # i.e. a track from a playlist that has "Hide Metadata from Listeners" set.
    # For standalone Liquidsoap, the ultimate override is `liq_blankskip`.
    # This can even be used to switch blank skipping ON if is globally off.
    blankskip = ref(blankskip)
    blankskip := list.assoc.mem("jingle_mode", meta) ? false : blankskip()

    # SAM Broadcaster compat: Switch blankskip off for all songtypes != "S"
    if list.assoc.mem("songtype", meta) then
      if meta["songtype"] != "S" then
        blankskip := false
      end
    end

    # Handle annotated `liq_blankskip`, the ultimate switch
    if list.assoc.mem("liq_blankskip", meta) then
      blankskip := bool_of_string(default=false, meta["liq_blankskip"])
    end

    log(
      level=3,
      label=label,
      "Blank (silence) skipping active: #{blankskip()}"
    )

    # set up CLI arguments
    args =
      ref(
        [
          '-t',
          string.float(target, decimal_places=2),
          '-s',
          string.float(silence, decimal_places=2),
          '-o',
          string.float(overlay, decimal_places=2),
          '-l',
          string.float(longtail, decimal_places=2),
          '-x',
          string.float(overlay_longtail, decimal_places=2),
          filename
        ]
      )
    if blankskip() then args := list.add('-b', args()) end
    if write_tags then args := list.add('-w', args()) end
    if force_analysis then args := list.add('-f', args()) end
    if nice then args := list.add('-n', args()) end

    res = ref("")
    try
      res :=
        list.hd(
          default="",
          process.read.lines(
            timeout=timeout,
            process.quote.command(settings.autocue.cue_file.path(), args=args())
          )
        )
    catch err do
      log(
        level=2,
        label=label,
        'cue_file error: #{err}'
      )
      res := ""
    end

    if
      res() != ""
    then
      log(
        level=3,
        label=label,
        'cue_file result for "#{filename}": #{res()}'
      )

      let json.parse (
        {
          duration,
          liq_cue_duration,
          liq_cue_in,
          liq_cue_out,
          liq_cross_start_next,
          liq_longtail,
          #liq_cross_duration,
          liq_loudness,
          liq_amplify,
          liq_reference_loudness,
          liq_blankskip,
          liq_blank_skipped
        }
      :
        {
          duration: float,
          liq_cue_duration: float,
          liq_cue_in: float,
          liq_cue_out: float,
          liq_cross_start_next: float,
          liq_longtail: bool,
          #liq_cross_duration: float,
          liq_loudness: string,
          liq_amplify: string,
          liq_reference_loudness: string,
          liq_blankskip: bool,
          liq_blank_skipped: bool
        }
      ) = res()

      # must stringify, because metadata & annotations are strings
      result = ref(
        [
          ("duration", string(duration)),
          ("liq_cue_duration", string(liq_cue_duration)),
          ("liq_cue_in", string(liq_cue_in)),
          ("liq_cue_out", string(liq_cue_out)),
          ("liq_cross_start_next", string(liq_cross_start_next)),
          ("liq_longtail", string(liq_longtail)),
          #("liq_cross_duration", string(liq_cross_duration)),
          ("liq_loudness", liq_loudness),
          ("liq_amplify", liq_amplify),
          ("liq_reference_loudness", liq_reference_loudness),
          ("liq_blankskip", string(liq_blankskip)),
          ("liq_blank_skipped", string(liq_blank_skipped))
        ]
      )

      # only use calculated values if not already annotated in AzuraCast
      # so we don't overwrite manually set values in the database
      result := list.fold(
        fun(res, entry) ->
          if list.assoc.mem(fst(entry), res) then
            res
          else
            [...res, entry]
          end,
          meta,
          result()
      )

      # Override liq_amplify, liq_reference_loudness if target changed
      # adjust liq_amplify by loudness target difference, set reference
      if list.assoc.mem("liq_amplify", result()) and list.assoc.mem("liq_reference_loudness", result()) then
        la = list.assoc(default="0.00 dB", "liq_amplify", result())
        laf = float_of_string(string.replace(pattern=" (dB|LU)", fun(_) -> "", la))
        lr = list.assoc(default=string.float(decimal_places=2, target)^" dB", "liq_reference_loudness", result())
        lrf = float_of_string(string.replace(pattern=" (dB|dBFS|LUFS)", fun(_) -> "", lr))

        result := list.assoc.remove("liq_amplify", result())
        result := list.add(("liq_amplify", string.float(decimal_places=2, laf + (target - lrf)) ^ " dB"), result())

        result := list.assoc.remove("liq_reference_loudness", result())
        result := list.add(("liq_reference_loudness", string.float(decimal_places=2, target) ^ " LUFS"), result())
      end

      if settings.autocue.cue_file.unify_loudness_correction() then
        # We wish to avoid loudness jumps in all possible cases,
        # so bring `replaygain_track_gain` and `liq_amplify` in line.
        # NOTE: This also works for different loudness targets, if
        # files have been tagged with a valid replaygain_reference_loudness.
        # This does NOT include mp3gain’s ominous positive dB SPL values!
        if list.assoc.mem("replaygain_track_gain", result()) then
          if list.assoc.mem("replaygain_reference_loudness", result()) then
            la = list.assoc(default="0.00 dB", "liq_amplify", result())
            rg = list.assoc(default="0.00 dB", "replaygain_track_gain", result())
            rgf = float_of_string(string.replace(pattern=" (dB|LU)", fun(_) -> "", rg))
            rgr = list.assoc(default=string.float(decimal_places=2, target)^" dB", "replaygain_reference_loudness", result())
            rgrf = ref(float_of_string(string.replace(pattern=" (dB|dBFS|LUFS)", fun(_) -> "", rgr)))
            # Handle old RG1/mp3gain positive loudness reference
            # "89 dB" (SPL) should actually be -14 LUFS, but as a reference
            # it is usually set equal to the RG2 -18 LUFS reference point
            if rgrf() > 0. then rgrf := rgrf() - 107. end
            # adjust replaygain_track_gain by loudness target difference, set reference
            # we can safely do that since we NEVER write back replaygain_* tags
            rg = string.float(decimal_places=2, rgf + (target - rgrf())) ^ " dB"
            rgr = string.float(decimal_places=2, target) ^ " LUFS"
            result := list.assoc.remove("replaygain_track_gain", result())
            result := list.add(("replaygain_track_gain", rg), result())
            result := list.assoc.remove("replaygain_reference_loudness", result())
            result := list.add(("replaygain_reference_loudness", rgr), result())
            # Now set liq_amplify to the same value
            result := list.assoc.remove("liq_amplify", result())
            result := list.add(("liq_amplify", rg), result())
            log(level=3, label=label, 'Replaced liq_amplify=#{la} with #{rg} from adjusted replaygain_track_gain')
          else
            log(level=3, label=label, "Can't override liq_amplify from replaygain_track_gain, replaygain_reference_loudness missing.")
          end
        else
          # no `replaygain_track_gain` seen? insert one, using calculated `liq_amplify`
          rg = list.assoc(default="0.00 dB", "liq_amplify", result())
          result := list.add(("replaygain_track_gain", rg), result())
          # also insert a `replaygain_reference_loudness`
          rgr = string.float(decimal_places=2, target) ^ " LUFS"
          result := list.assoc.remove("replaygain_reference_loudness", result())
          result := list.add(("replaygain_reference_loudness", rgr), result())
          log(level=3, label=label, 'Inserted replaygain_track_gain #{rg} and replaygain_reference_loudness #{rgr}')
        end
      end

      # Adjust fades and cue-out, if necessary
      liq_cue_in = float_of_string(list.assoc("liq_cue_in", result()))
      liq_cue_out = float_of_string(list.assoc("liq_cue_out", result()))
      liq_cross_start_next = float_of_string(list.assoc("liq_cross_start_next", result()))
      liq_fade_in =
        try
          float_of_string(list.assoc("liq_fade_in", result()))
        catch _ do
          log(
            level=3,
            label=label,
            "No fade-in duration given, using default setting \
             (#{settings.autocue.cue_file.fade_in()} s)."
          )
          settings.autocue.cue_file.fade_in()
        end

      liq_fade_out =
        try
          float_of_string(list.assoc("liq_fade_out", result()))
        catch _ do
          log(
            level=3,
            label=label,
            "No fade-out duration given, using default setting \
             (#{settings.autocue.cue_file.fade_out()} s)."
          )
          settings.autocue.cue_file.fade_out()
        end

      # User might have set cue-out but not start_next, correct
      liq_cross_start_next =
        if liq_cross_start_next <= liq_cue_out
        then
          liq_cross_start_next
        else
          start_next = liq_cue_out - liq_fade_out
          if start_next > liq_cue_in
          then
            # we have enough room for the fade-out
            log(
              level=3,
              label=label,
              "Given liq_cross_start_next (#{liq_cross_start_next} s) > \
               cue-out point (#{liq_cue_out} s), set to #{start_next} s."
            )
            start_next
          else
            # not enough room for fade-out, set to cue-out
            log(
              level=3,
              label=label,
              "Given liq_cross_start_next (#{liq_cross_start_next} s) > \
               cue-out point (#{liq_cue_out} s), set to #{liq_cue_out} s."
            )
            liq_cue_out
          end
        end

      # Adjust cue_out according to user-supplied fade_out
      let (liq_fade_out, liq_cue_out) =
        if
          liq_cross_start_next + liq_fade_out < liq_cue_out
        then
          cue_out = liq_cross_start_next + liq_fade_out
          overlay_duration = liq_cue_out - liq_cross_start_next
          log(
            level=3,
            label=label,
            "Given fade-out (#{liq_fade_out} s) < \
             overlay duration (#{overlay_duration} s), moving cue-out point \
             from #{liq_cue_out} s to #{cue_out} s."
          )
          (liq_fade_out, cue_out)
        else
          fade_out = liq_cue_out - liq_cross_start_next
          log(
            level=2,
            label=label,
            "Given fade-out duration (#{liq_fade_out} s) exceeds \
             available time, using #{fade_out} s."
          )
          (fade_out, liq_cue_out)
        end

      # Check for invalid fade.in
      let liq_fade_in =
        if
          liq_fade_in < liq_cue_out - liq_cue_in
        then
          liq_fade_in
        else
          log(
            level=2,
            label=label,
            "Given fade-in duration (#{liq_fade_in} s) exceeds \
             available time, using 0.1 s."
          )
          0.1
        end

      # correct `liq_cue_duration`
      liq_cue_duration = liq_cue_out - liq_cue_in
      result := list.assoc.remove("liq_cue_duration", result())
      result := list.add(("liq_cue_duration",
        string.float(decimal_places=2, liq_cue_duration)), result())

      # Update result
      result := list.assoc.remove("liq_cue_out", result())
      result := list.add(("liq_cue_out", string(liq_cue_out)), result())
      result := list.assoc.remove("liq_cross_start_next", result())
      result := list.add(("liq_cross_start_next", string(liq_cross_start_next)), result())
      result := list.assoc.remove("liq_fade_in", result())
      result := list.add(("liq_fade_in", string(liq_fade_in)), result())
      result := list.assoc.remove("liq_fade_out", result())
      result := list.add(("liq_fade_out", string(liq_fade_out)), result())

      # now remove everything that’s not autocue-relevant
      # so we don’t blow up decoder and annotation metadata
      def fl(k, _) =
        tags = ["duration", "replaygain_track_gain", "replaygain_reference_loudness"]
        string.contains(prefix="liq_", k) or list.mem(k, tags)
      end
      result := list.assoc.filter((fl), result())

      l = list.sort.natural(stdlib_metadata.cover.remove(result()))
      log.important(label=label, 'Metadata added/corrected for "#{filename}":')
      list.iter(fun(v) -> log.important(label=label, "#{v}"), l)

      # for optional meta elements that aren’t guaranteed to be in result,
      # like replaygain_track_gain, replaygain_reference_loudness
      def optional_meta(lbl, meta) =
        if list.assoc.mem(lbl, meta) then
          [(lbl, list.assoc(lbl, meta))]
        else
          []
        end
      end

      extra_metadata =
        [
          ("duration", list.assoc("duration", result())),
          ("liq_amplify", list.assoc("liq_amplify", result())),
          ("liq_cue_duration", list.assoc("liq_cue_duration", result())),
          ("liq_longtail", list.assoc("liq_longtail", result())),
          ("liq_loudness", list.assoc("liq_loudness", result())),
          ("liq_reference_loudness", list.assoc("liq_reference_loudness", result())),
          ("liq_blank_skipped", list.assoc("liq_blank_skipped", result())),
          ...optional_meta("replaygain_track_gain", result()),
          ...optional_meta("replaygain_reference_loudness", result())
        ]

      {
        amplify = list.assoc("liq_amplify", result()),
        cue_in = float_of_string(list.assoc("liq_cue_in", result())),
        cue_out = float_of_string(list.assoc("liq_cue_out", result())),
        fade_in = float_of_string(list.assoc("liq_fade_in", result())),
        fade_out = float_of_string(list.assoc("liq_fade_out", result())),
        start_next = float_of_string(list.assoc("liq_cross_start_next", result())),
        extra_metadata=extra_metadata
      }
    else
      log(
        level=2,
        label=label,
        'No autocue data found for "#{filename}"'
      )
      null()
    end
  end
end

autocue.register(name="cue_file", cue_file)
# set this so annotations (priority 5) can still override autocue values
settings.autocue.metadata.priority := 10
settings.autocue.preferred := "cue_file"
# avoid dead air from reconcile, reset default 3.0s to our fade_out duration
settings.autocue.target_cross_duration := settings.autocue.cue_file.fade_out()

# --- Copy-paste Azuracast LS Config, second input box END ---

# Don't forget to add your settings after this.
