# autocue2.liq
# 2024-04-10 - Moonbase59
# 2024-04-12 - Toots: re-organize to integrate as core autocue implementation.
# 2024-04-12 - Moonbase59 - re-introduce `liq_duration` as `liq_cue_duration`.
# 2024-04-19 - Moonbase59 - rename to "autocue.cue_file.liq"
#                         - update to use same `cue_file` as master branch

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

let settings.autocue.cue_file.metadata_override =
  settings.make(
    description=
      "Disable processing when one of these metadata is found",
    []
  )

let settings.autocue.cue_file.timeout =
  settings.make(
    description=
      "Timeout (in seconds) for cue_file executions.",
    60.
  )

let settings.autocue.cue_file.target =
  settings.make(
    description=
      "Loudness target in LUFS.",
    -18
  )

let settings.autocue.cue_file.silence =
  settings.make(
    description=
      "Silence level (for cue points) in LU/dB below track loudness.",
    -42
  )

let settings.autocue.cue_file.overlay =
  settings.make(
    description=
      "Start overlay level in LU/dB below track loudness.",
    -8
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
    -15
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
       precedence if we can see it. Allows scripts to amplify on either value, \
       without getting loudness jumps.\nNote this can only work correctly if \
       your files have been replaygained to the same LUFS target as your \
       `settings.autocue.cue_file.target`!',
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

# Compute cue_file data
# @flag extra
def cue_file(req) =
  timeout = settings.autocue.cue_file.timeout()
  target = settings.autocue.cue_file.target()
  silence = settings.autocue.cue_file.silence()
  overlay = settings.autocue.cue_file.overlay()
  longtail = settings.autocue.cue_file.longtail()
  overlay_longtail = settings.autocue.cue_file.overlay_longtail()
  blankskip = settings.autocue.cue_file.blankskip()
  write_tags = settings.autocue.cue_file.write_tags()
  force_analysis = settings.autocue.cue_file.force_analysis()

  label = "cue_file"

  m = ref(request.metadata(req))

  # so we can use meta["something"]
  meta = m()

  liq_fade_in =
    try
      float_of_string(list.assoc("liq_fade_in", meta))
    catch _ do
      log(
        level=3,
        label="autocue.cue_file.metadata",
        "Could not find user-supplied value for fade-in duration, using default \
         setting (#{settings.autocue.cue_file.fade_in()} s)."
      )
      settings.autocue.cue_file.fade_in()
    end

  liq_fade_out =
    try
      float_of_string(list.assoc("liq_fade_out", meta))
    catch _ do
      log(
        level=3,
        label="autocue.cue_file.metadata",
        "Could not find user-supplied value for fade-out duration, using default \
         setting (#{settings.autocue.cue_file.fade_out()} s)."
      )
      settings.autocue.cue_file.fade_out()
    end

  metadata_overrides = settings.autocue.cue_file.metadata_override()

  if
    list.exists(fun (el) -> list.mem(fst(el), metadata_overrides), meta)
  then
    log(
      level=2,
      label="autocue.cue_file.metadata",
      "Override metadata detected for #{request.uri(req)}, disabling autocue!"
    )
    null()
  elsif
    meta["liq_cue_file"] == "false"
  then
    log(
      level=2,
      label=label,
      'Skipping cue_file for "#{request.uri(req)}" because liq_cue_file=false \
       forbids it.'
    )
    null()
  else
    log(
      level=3,
      label=label,
      'Now autocueing: "#{request.uri(req)}"'
    )

    l = list.sort.natural(metadata.cover.remove(meta))
    log(
      level=4,
      label=label,
      "Metadata seen:"
    )
    list.iter(fun (v) -> log(level=4, label=label, "#{v}"), l)

    log(
      level=3,
      label=label,
      'jingle_mode=#{meta["jingle_mode"]}, liq_blankskip=#{
        meta["liq_blankskip"]
      }'
    )

    # Blank skipping can be set globally using `settings.autocue.cue_file.blankskip`.
    # For AzuraCast, we override that setting if we detect "jingle_mode",
    # i.e. a track from a playlist that has "Hide Metadata from Listeners" set.
    # For standalone Liquidsoap, the ultimate override is `liq_blankskip`.
    # This can even be used to switch blank skipping ON if is globally off.
    blankskip = ref(blankskip)
    blankskip := list.assoc.mem("jingle_mode", meta) ? false : blankskip()

    # Handle annotated `liq_blankskip`
    if
      list.assoc.mem("liq_blankskip", meta)
    then
      blankskip := bool_of_string(default=false, meta["liq_blankskip"])
    end

    log.important(
      label=label,
      "Blank (silence) skipping active: #{blankskip()}"
    )

    # set up CLI arguments
    args =
      ref(
        [
          '-t',
          string(target),
          '-s',
          string(silence),
          '-o',
          string(overlay),
          '-l',
          string(longtail),
          '-x',
          string(overlay_longtail),
          request.filename(req)
        ]
      )
    if blankskip() then args := list.add('-b', args()) end
    if write_tags then args := list.add('-w', args()) end
    if force_analysis then args := list.add('-f', args()) end

    result = ref("")
    try
      result :=
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
        'cue_file autocue Error: #{err}'
      )
      result := ""
    end

    if
      result() != ""
    then
      log(
        level=3,
        label=label,
        'cue_file autocue result for "#{request.uri(req)}": #{result()}'
      )

      # TODO: How to handle an incomplete result (not all values in JSON)?
      # Could happen if cue_file only read (incomplete) file tags instead of
      # doing a full recalculation (for speed reasons).

      let json.parse (
        {
          duration,
          liq_cue_duration,
          liq_cue_in,
          liq_cue_out,
          liq_cross_start_next,
          liq_longtail,
          liq_cross_duration,
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
          liq_cross_duration: float,
          liq_loudness: string,
          liq_amplify: string,
          liq_reference_loudness: string,
          liq_blankskip: bool,
          liq_blank_skipped: bool
        }
      ) = result()

      liq_amplify = ref(liq_amplify)
      extra_metadata =
        ref(
          [
            ("duration", string(duration)),
            ("liq_cue_duration", string(liq_cue_duration)),
            ("liq_longtail", string(liq_longtail)),
            ("liq_loudness", liq_loudness),
            ("liq_reference_loudness", liq_reference_loudness),
            ("liq_blank_skipped", string(liq_blank_skipped))
          ]
        )

      if
        settings.autocue.cue_file.unify_loudness_correction()
      then
        # We wish to avoid loudness jumps in all possible cases,
        # so bring `replaygain_track_gain` and `liq_amplify` in line.
        # NOTE: This can only work correctly if your files have been replaygained
        # to the same LUFS target as your `settings.autocue.cue_file.target`!
        if
          list.assoc.mem("replaygain_track_gain", meta)
        then
          rg =
            list.assoc(
              default=
                "0.00 dB",
              "replaygain_track_gain",
              meta
            )
          log(
            level=3,
            label=label,
            'Replaced liq_amplify=#{liq_amplify()} with #{rg} from \
             replaygain_track_gain'
          )
          liq_amplify := rg
        else
          # no `replaygain_track_gain` seen? insert one, using calculated `liq_amplify`
          log(
            level=3,
            label=label,
            'Inserted replaygain_track_gain: #{liq_amplify()}'
          )
          extra_metadata :=
            [...extra_metadata(), ("replaygain_track_gain", liq_amplify())]
        end
      end

      # Adjust cue_out according to user-supplied fade_out
      let (liq_fade_out, liq_cue_out) =
        if
          liq_cross_start_next + liq_fade_out < liq_cue_out
        then
          (liq_fade_out, liq_cross_start_next + liq_fade_out)
        else
          log(
            level=2,
            label=label,
            "User-supplied fade-out duration exceeds available time!"
          )
          (liq_cue_out - liq_cross_start_next, liq_cue_out)
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
            "User-supplied fade-in duration exceeds available time!"
          )
          0.1
        end

      {
        amplify=liq_amplify(),
        cue_in=liq_cue_in,
        cue_out=liq_cue_out,
        fade_in=liq_fade_in,
        fade_out=liq_fade_out,
        start_next=liq_cross_start_next,
        extra_metadata=extra_metadata()
      }
    else
      log(
        level=2,
        label=label,
        'No autocue data found for "#{request.uri(req)}"'
      )
      null()
    end
  end
end

autocue.register(name="cue_file", cue_file)

# --- Copy-paste Azuracast LS Config, second input box END ---

# Don't forget to add your settings after this.
