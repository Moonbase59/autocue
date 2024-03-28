# autocue2.liq
# 2024-03-25 - Moonbase59

# --- protocol definition begin

let settings.protocol.autocue2 = settings.make.protocol("autocue2")
let settings.protocol.autocue2.path =
  settings.make(
    description=
      "Path of the autocue2 binary.",
    "cue_file"
  )

let settings.protocol.autocue2.timeout =
  settings.make(
    description=
      "Timeout (in seconds) for autocue2 executions.",
    60.
  )

let settings.protocol.autocue2.target =
  settings.make(
    description=
      "Loudness target in LUFS.",
    -18
  )

let settings.protocol.autocue2.silence =
  settings.make(
    description=
      "Silence level (for cue points) in LU/dB below track loudness.",
    -42
  )

let settings.protocol.autocue2.overlay =
  settings.make(
    description=
      "Start overlay level in LU/dB below track loudness.",
    -8
  )

let settings.protocol.autocue2.longtail =
  settings.make(
    description=
      "More than so many seconds of calculated overlay are considered a long tail.",
    15.0
  )

let settings.protocol.autocue2.overlay_longtail =
  settings.make(
    description=
      "Extra LU/dB level below overlay loudness, to recalculate songs with long tails.",
    -15
  )

let settings.protocol.autocue2.blankskip =
  settings.make(
    description=
      'Skip blank (silence) within song (get rid of "hidden tracks".)',
    false
  )


# Register the autocue2 protocol.
# @flag hidden
def protocol.autocue2(~rlog, ~maxtime=settings.protocol.autocue2.timeout(), arg) =

  def log(~level=4, s) =
    #rlog(s)
    log(label="protocol.autocue2", level=level, s)
  end
  
  def get_data(f, ~blankskip=settings.protocol.autocue2.blankskip()) =
    log('Processing file "#{f}" ...')
    
    # set up CLI arguments
    args=ref([
      '-t', string(settings.protocol.autocue2.target()),
      '-s', string(settings.protocol.autocue2.silence()),
      '-o', string(settings.protocol.autocue2.overlay()),
      '-l', string(settings.protocol.autocue2.longtail()),
      '-x', string(settings.protocol.autocue2.overlay_longtail()),
      f
    ])
    if blankskip then
      args := list.add('-b', args())
    end
    
    result = list.hd(
      default="",
      process.read.lines(
        timeout=settings.protocol.autocue2.timeout(),
        process.quote.command(
          settings.protocol.autocue2.path(),
          args=args()
        )
      )
    )
    log(result)
    
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
  end

  log(level=3, 'Autocueing "' ^ arg ^ '" ...')
  meta = ref([])
  urilocal = ref("")
  newmeta = ref([])
  a = string(string.residual(prefix="annotate:", arg))
  log(a)
  if a != "null" then
    let (m, uri) = string.annotate.parse(a)
    meta := m
    log("BEFORE:")
    log("URI: #{uri}")
    list.iter(fun(e) -> log("#{e}"), meta())
    # FIXME: AzuraCast kludge: resolve "media:" protocol manually
    urilocal := string(string.residual(prefix="media:", uri))
    if urilocal() != "null" then
      urilocal := "#{station_media_dir}/#{urilocal()}"
    else
      urilocal := uri
    end
    blankskip = ref(settings.protocol.autocue2.blankskip())
    # FIXME: AzuraCast kludge: only skip blanks if not jingle
    blankskip := list.assoc.mem("jingle_mode", meta()) ? false : (settings.protocol.autocue2.blankskip())
    # Handle annotated blankskip
    if list.assoc.mem("liq_blankskip", m) then
      blankskip := bool_of_string(default=false, m["liq_blankskip"])
    end
    newmeta := get_data(urilocal(), blankskip=blankskip())
  else
    log("URI: #{arg}")
    urilocal := arg
    # FIXME: AzuraCast kludge: only skip blanks if not jingle
    blankskip = list.assoc.mem("jingle_mode", meta()) ? false : (settings.protocol.autocue2.blankskip())
    newmeta := get_data(urilocal(), blankskip=blankskip)
  end
  
  log("NEW META:")
  list.iter(fun(e) -> log("#{e}"), newmeta())
  
  # remove duration -- we want to always replace this
  # because we believe ours is more exact
  meta := list.assoc.remove("duration", meta())
  
  # only use calculated values if not already existent in AzuraCast
  # so we don't overwrite manually set values in the database
  meta := list.fold(
    fun(result, entry) -> 
      if list.assoc.mem(fst(entry), result) then
        result
      else
        [...result, entry]
      end,
      meta(),
      newmeta()
  )

  log("AFTER:")
  log("URI: #{urilocal()}")
  list.iter(fun(e) -> log("#{e}"), meta())

  # build list of key=value pairs from combined metadata
  l = ref([])
  list.iter(fun(e) ->
    l := list.add("#{fst(e)}=\"#{snd(e)}\"", l()),
    meta()
  )

  # concatenate list to param string
  p = ref("")
  p := string.concat(separator=",", l())
  # if we got params, add "annotate:" protocol
  if p() != "" then
    p := "annotate:" ^ p() ^ ":"
  end

  # add URI
  p := p() ^ urilocal()
  
  log(level=3, "Result: #{p()}")
  
  [p()]
end

protocol.add(
  "autocue2",
  protocol.autocue2,
  syntax="autocue2:uri",
  doc=
    "Compute autocue2 values. Adds returned values as \
     annotation in metadata"
)

# --- protocol definition end
