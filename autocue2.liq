# autocue2.liq
# 2024-03-28 - Moonbase59

# --- Copy-paste Azuracast LS Config, second input box BEGIN ---

# Initialize settings for autocue2 protocol
let settings.autocue2 = ()

let settings.autocue2.path =
  settings.make(
    description=
      "Path of the autocue2 binary.",
    "cue_file"
  )

let settings.autocue2.timeout =
  settings.make(
    description=
      "Timeout (in seconds) for autocue2 executions.",
    60.
  )

let settings.autocue2.target =
  settings.make(
    description=
      "Loudness target in LUFS.",
    -18
  )

let settings.autocue2.silence =
  settings.make(
    description=
      "Silence level (for cue points) in LU/dB below track loudness.",
    -42
  )

let settings.autocue2.overlay =
  settings.make(
    description=
      "Start overlay level in LU/dB below track loudness.",
    -8
  )

let settings.autocue2.longtail =
  settings.make(
    description=
      "More than so many seconds of calculated overlay are considered a long tail.",
    15.0
  )

let settings.autocue2.overlay_longtail =
  settings.make(
    description=
      "Extra LU/dB level below overlay loudness, to recalculate songs with long tails.",
    -15
  )

let settings.autocue2.blankskip =
  settings.make(
    description=
      'Skip blank (silence) within song (get rid of "hidden tracks".)',
    false
  )

let file.autocue2 = ()

# Get autocue values from external cue_file executable
# @flag hidden
def file.autocue2.compute(
  ~timeout=null(),
  ~target=null(),
  ~silence=null(),
  ~overlay=null(),
  ~longtail=null(),
  ~overlay_longtail=null(),
  ~blankskip=null(),
  uri
) =
  timeout = timeout ?? settings.autocue2.timeout()
  target = target ?? settings.autocue2.target()
  silence = silence ?? settings.autocue2.silence()
  overlay = overlay ?? settings.autocue2.overlay()
  longtail = longtail ?? settings.autocue2.longtail()
  overlay_longtail = overlay_longtail ?? settings.autocue2.overlay_longtail()
  blankskip = blankskip ?? settings.autocue2.blankskip()

  r = request.create(excluded_metadata_resolvers=["autocue2"], uri)
  s = request.once(r)

  if
    s.resolve()
  then
    # resolved local filename
    fname = request.filename(r)
    meta = request.metadata(r)

    log(
      level=3,
      label="autocue2",
      'Now autocueing: "#{uri}"'
    )

    l = list.sort.natural(metadata.cover.remove(meta))
    list.iter(fun(v) -> log.important(label="autocue2", "#{v}"), l)


    # Blank skipping can be set globally using `settings.autocue2.blankskip`.
    # For AzuraCast, we override that setting if we detect "jingle_mode",
    # i.e. a track from a playlist that has "Hide Metadata from Listeners" set.
    # For standalone Liquidsoap, the ultimate override is `liq_blankskip`.
    # This can even be used to switch blank skipping ON if is globally off.
    blankskip = ref(blankskip)
    blankskip := list.assoc.mem("jingle_mode", meta) ? false : blankskip()
    # Handle annotated `liq_blankskip`
    if list.assoc.mem("liq_blankskip", meta) then
      blankskip := bool_of_string(default=false, meta["liq_blankskip"])
    end

    # set up CLI arguments
    args=ref([
      '-t', string(target),
      '-s', string(silence),
      '-o', string(overlay),
      '-l', string(longtail),
      '-x', string(overlay_longtail),
      fname
    ])
    if blankskip() then
      args := list.add('-b', args())
    end
    
    result = list.hd(
      default="",
      process.read.lines(
        timeout=timeout,
        process.quote.command(
          settings.autocue2.path(),
          args=args()
        )
      )
    )
    
    # TODO: Error handling
    log(
      level=3,
      label="autocue2",
      'Autocue2 result for "#{fname}": #{result}'
    )
    
    # TODO: How to handle an incomplete result (not all values in JSON)?
    # Could happen if cue_file only read (incomplete) file tags instead of
    # doing a full recalculation (for speed reasons).
    
    let json.parse ({
      duration,
      liq_duration,
      liq_cue_in,
      liq_cue_out,
      liq_longtail,
      liq_cross_duration,
      liq_loudness,
      liq_amplify,
      liq_blank_skipped
    } : {
      duration: string,
      liq_duration: string,
      liq_cue_in: string,
      liq_cue_out: string,
      liq_longtail: string,
      liq_cross_duration: string,
      liq_loudness: string,
      liq_amplify: string,
      liq_blank_skipped: string
    }) = result
    
    # TODO: How to return an incomplete assoc list from above?
    [
      ("duration", duration),
      ("liq_duration", liq_duration),
      ("liq_cue_in", liq_cue_in),
      ("liq_cue_out", liq_cue_out),
      ("liq_longtail", liq_longtail),
      ("liq_cross_duration", liq_cross_duration),
      ("liq_loudness", liq_loudness),
      ("liq_amplify", liq_amplify),
      ("liq_blank_skipped", liq_blank_skipped)
    ]
  else
    log(
      level=2,
      label="autocue2",
      "Couldn't resolve source for URI: #{uri}"
    )
    []
  end
end

# Compute autocue2 data
# @flag extra
# @category Source / Audio processing
# @param ~timeout Timeout
# @param ~target Loudness target in LUFS
# @param ~silence Silence level in LU/dB below track loudness
# @param ~overlay Start overlay level in LU/dB below track loudness
# @param ~longtail More than so many seconds of calculated overlay are considered a long tail.
# @param ~overlay_longtail Extra LU/dB level below overlay loudness, to recalculate songs with long tails
# @param ~blankskip Skip blank (silence) within song (get rid of "hidden tracks")
def replaces file.autocue2(
  ~timeout=null(),
  ~target=null(),
  ~silence=null(),
  ~overlay=null(),
  ~longtail=null(),
  ~overlay_longtail=null(),
  ~blankskip=null(),
  uri
) =
  timeout = timeout ?? settings.autocue2.timeout()
  target = target ?? settings.autocue2.target()
  silence = silence ?? settings.autocue2.silence()
  overlay = overlay ?? settings.autocue2.overlay()
  longtail = longtail ?? settings.autocue2.longtail()
  overlay_longtail = overlay_longtail ?? settings.autocue2.overlay_longtail()
  blankskip = blankskip ?? settings.autocue2.blankskip()

  result =
    file.autocue2.compute(
      timeout=timeout,
      target=target,
      silence=silence,
      overlay=overlay,
      longtail=longtail,
      overlay_longtail=overlay_longtail,
      blankskip=blankskip,
      uri
    )    

  if
    result == []
  then
    log(
      level=2,
      label="autocue2",
      "Autocue2 computation failed!"
    )
    #null()
    []
  else
    result
  end
end

# Return the file's autocue2 values as metadata suitable for metadata override.
# @flag extra
# @category Source / Audio processing
# @param ~timeout Timeout
# @param ~target Loudness target in LUFS
# @param ~silence Silence level in LU/dB below track loudness
# @param ~overlay Start overlay level in LU/dB below track loudness
# @param ~longtail More than so many seconds of calculated overlay are considered a long tail.
# @param ~overlay_longtail Extra LU/dB level below overlay loudness, to recalculate songs with long tails
# @param ~blankskip Skip blank (silence) within song (get rid of "hidden tracks")
def file.autocue2.metadata(
  ~timeout=null(),
  ~target=null(),
  ~silence=null(),
  ~overlay=null(),
  ~longtail=null(),
  ~overlay_longtail=null(),
  ~blankskip=null(),
  uri
) =
  let autocue2 =
    file.autocue2(
      timeout=timeout,
      target=target,
      silence=silence,
      overlay=overlay,
      longtail=longtail,
      overlay_longtail=overlay_longtail,
      blankskip=blankskip,
      uri
    )

  if
    null.defined(autocue2)
  then
    autocue2
  else
    log(
      level=2,
      label="autocue2.metadata",
      'No autocue data found for file "#{uri}"'
    )
    []
  end
end

# Enable autocue2 metadata resolver. This resolver will process any file
# decoded by Liquidsoap and add cue-in/out and crossfade metadata when these
# values can be computed. For a finer-grained processing, use the `autocue2:` protocol.
# NOTE: You might want to annotate VIDEO sources with `liq_autocue=false`!
# Autocueing a multi-GB video works, but can really eat up CPU.
# @category Liquidsoap
def enable_autocue2_metadata() =
  def autocue2_metadata(~metadata, fname) =
    if 
      metadata["liq_autocue"] == "false"
    then
      log(
        level=2,
        label="autocue2",
        'Skipping autocue for file "#{fname}" because liq_autocue=false forbids it.'
      )
      []
    else
      file.autocue2.metadata(fname)
    end
  end
  decoder.metadata.add("autocue2", autocue2_metadata)
end

# Define autocue2 protocol
# @flag hidden
def protocol.autocue2(~rlog=_, ~maxtime=_, arg) =
  cue_metadata = file.autocue2.metadata(arg)

  if
    cue_metadata != []
  then
    cue_metadata =
      list.map(fun (el) -> "#{fst(el)}=#{string.quote(snd(el))}", cue_metadata)
    cue_metadata = string.concat(separator=",", cue_metadata)
    ["annotate:#{cue_metadata}:#{arg}"]
  else
    log(
      level=2,
      label="autocue2.protocol",
      'No autocue data found for URI "#{arg}"!'
    )
    [arg]
  end
end

protocol.add(
  "autocue2",
  protocol.autocue2,
  doc=
    "Adding automatically computed cues/crossfade metadata",
  syntax="autocue2:uri"
)

# --- Copy-paste Azuracast LS Config, second input box END ---

# Don't forget to add your settings after this.
