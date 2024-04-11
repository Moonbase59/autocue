# autocue2.liq
# 2024-04-10 - Moonbase59

# Lots of debugging output for AzuraCast in this, will be removed eventually.

# --- Copy-paste Azuracast LS Config, second input box BEGIN ---

# Initialize settings for cue_file autocue implementation
let settings.cue_file = ()

let settings.cue_file.path =
  settings.make(
    description=
      "Path of the cue_file binary.",
    "cue_file"
  )

let settings.cue_file.timeout =
  settings.make(
    description=
      "Timeout (in seconds) for cue_file executions.",
    60.
  )

let settings.cue_file.target =
  settings.make(
    description=
      "Loudness target in LUFS.",
    -18
  )

let settings.cue_file.silence =
  settings.make(
    description=
      "Silence level (for cue points) in LU/dB below track loudness.",
    -42
  )

let settings.cue_file.overlay =
  settings.make(
    description=
      "Start overlay level in LU/dB below track loudness.",
    -8
  )

let settings.cue_file.longtail =
  settings.make(
    description=
      "More than so many seconds of calculated overlay are considered a long \
       tail.",
    15.0
  )

let settings.cue_file.overlay_longtail =
  settings.make(
    description=
      "Extra LU/dB level below overlay loudness, to recalculate songs with long \
       tails.",
    -15
  )

let settings.cue_file.blankskip =
  settings.make(
    description=
      'Skip blank (silence) within song (get rid of "hidden tracks".)',
    false
  )

let settings.cue_file.unify_loudness_correction =
  settings.make(
    description=
      'Unify `replaygain_track_gain` and `liq_amplify`. If enabled, this will \
       ensure both have the same value, with `replaygain_track_gain` taking \
       precedence if we can see it. Allows scripts to amplify on either value, \
       without getting loudness jumps.\nNote this can only work correctly if \
       your files have been replaygained to the same LUFS target as your \
       `settings.cue_file.target`!',
    true
  )

# Compute cue_file data
# @flag extra
def cue_file(req) =
  timeout = settings.cue_file.timeout()
  target = settings.cue_file.target()
  silence = settings.cue_file.silence()
  overlay = settings.cue_file.overlay()
  longtail = settings.cue_file.longtail()
  overlay_longtail = settings.cue_file.overlay_longtail()
  blankskip = settings.cue_file.blankskip()

  label = "cue_file"

  m = ref(request.metadata(req))

  # so we can use meta["something"]
  meta = m()

  if
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

    # Blank skipping can be set globally using `settings.cue_file.blankskip`.
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

    result = ref("")
    try
      result :=
        list.hd(
          default="",
          process.read.lines(
            timeout=timeout,
            process.quote.command(settings.cue_file.path(), args=args())
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
          liq_cue_in,
          liq_cue_out,
          liq_longtail,
          liq_cross_start_next,
          liq_loudness,
          liq_amplify,
          liq_blank_skipped
        }
      :
        {
          duration: float,
          liq_cue_in: float,
          liq_cue_out: float,
          liq_longtail: bool,
          liq_cross_start_next: float,
          liq_loudness: string,
          liq_amplify: string,
          liq_blank_skipped: bool
        }
      ) = result()

      liq_amplify = ref(liq_amplify)
      extra_metadata =
        ref(
          [
            ("duration", string(duration)),
            ("liq_longtail", string(liq_longtail)),
            ("liq_loudness", liq_loudness),
            ("liq_blank_skipped", string(liq_blank_skipped))
          ]
        )

      if
        settings.cue_file.unify_loudness_correction()
      then
        # We wish to avoid loudness jumps in all possible cases,
        # so bring `replaygain_track_gain` and `liq_amplify` in line.
        # NOTE: This can only work correctly if your files have been replaygained
        # to the same LUFS target as your `settings.cue_file.target`!
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

      {
        amplify=liq_amplify(),
        cue_in=liq_cue_in,
        cue_out=liq_cue_out,
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
