# test_autocue.cue_file.liq
# 2024-04-02 - Moonbase59
# 2024-04-19 - Moonbase59 - rename to "test_autocue.cue_file.liq"

# Test the `autocue2:` protocol and crossfading code locally,
# using a "songs" and a "jingles" playlist.
# Output to speakers and the following files:
#   test_autocue.cue_file.log -- the Liquidsoap log file
#   test_autocue.cue_file.mp3 -- recording, for later checking
#   test_autocue.cue_file.cue -- cue file to better find songs (open THIS in your audio player)
#                     Note: `source.cue` support in LS 2.3.0+ only!

# For a certain test duration, like 120 minutes, use
#   timeout 120m liquidsoap test_autocue.cue_file.liq

# Log to file, for later diagnosis. To follow the log in another terminal, use
#   tail -f test_autocue.cue_file.log
settings.log.file := true
settings.log.file.path := "test_autocue.cue_file.log"
settings.log.file.append := false

# 3=important, 4=info
settings.log.level := 3

# no "live" in the local test
to_live = ref(false)

# --- Copy-paste the CONTENTS of `autocue2.liq` into AzuraCast, second input box ---
%include "autocue.cue_file.liq"

# --- Copy-paste your settings into AzuraCast, second input box AFTER above file ---

# settings.autocue.cue_file.path := "cue_file"
# settings.autocue.cue_file.fade_in := 0.1
# settings.autocue.cue_file.fade_out := 2.5
settings.autocue.cue_file.timeout := 120.0
# settings.autocue.cue_file.target := -14.0  # not recommended
# settings.autocue.cue_file.silence := -42.0
# settings.autocue.cue_file.overlay := -8.0
# settings.autocue.cue_file.longtail := 15.0
# settings.autocue.cue_file.overlay_longtail := -12.0
# settings.autocue.cue_file.sustained_loudness_drop := 40.0
settings.autocue.cue_file.noclip := true  # clipping prevention
settings.autocue.cue_file.blankskip := 5.0
# settings.autocue.cue_file.unify_loudness_correction := true
# settings.autocue.cue_file.write_tags := false  # testing
# settings.autocue.cue_file.write_replaygain := false  # testing
# settings.autocue.cue_file.force_analysis := false  # testing
settings.autocue.cue_file.nice := true  # Linux/MacOS only!
# settings.autocue.cue_file.use_json_metadata := true  # pass metadata to `cue_file` as JSON

# Check Autocue setup, print result, shutdown if problems
# The check results will also be in the log.
# Returns a bool: true=ok, false=error. We ignore that here.
# Set `print=true` for standalone scripts, `false` for AzuraCast.
ignore(check_autocue_setup(shutdown=true, print=true))

# `enable_autocue_metadata()` will autocue ALL files Liquidsoap processes.
# You can disable it for selected sources using 'annotate:liq_cue_file=false'.
# Remember you won't get `liq_amplify` data then -- expect loudness jumps!
enable_autocue_metadata()

# --- Copy-paste END ---

# --- Use YOUR playlist here! ---
#uri = "/home/matthias/Musik/Playlists/Radio/Classic Rock.m3u"
uri = "/home/matthias/media/videostream/yyy"
#songs = playlist(prefix="autocue2:", uri)
songs = playlist(prefix='annotate:liq_dummy="DUMMY":', uri)
# Test: Play 15s snippets by overriding some settings!
#songs = playlist(prefix='annotate:liq_dummy="DUMMY",liq_cue_in=30.0,liq_cue_out=45.0,liq_cross_start_next=44.0,liq_fade_in=1.0,liq_fade_out=2.5:', uri)

# --- Use YOUR playlist here! ---
uri = "/home/matthias/Musik/Other/Jingles/Short"
#uri = "/home/matthias/Musik/Other/Jingles/Programm"
# set jingle mode, no blank skipping, and some values like AzuraCast would
#jingles = playlist(prefix='autocue:annotate:jingle_mode="true",liq_blankskip="false",'
#  ^ 'liq_fade_in="0.10",liq_fade_out="0.10"'
#  ^ ':', uri)
jingles = playlist(prefix='annotate:jingle_mode="true",liq_blankskip=0.00,'
  ^ 'liq_fade_in="0.10",liq_fade_out="0.10"'
  ^ ':', uri)

# --- Use YOUR single here! ---
# Trying to exclude a single from autocue processing here, just for testing.
# Should say "Skipping autocue..." in log
#uri = "/home/matthias/Musik/Other/Jingles/Short/Magenta - How sentimental.flac"
#single = single('annotate:liq_cue_file=true,liq_blankskip=false,liq_dummy="A single!":#{uri}')

#radio = random(weights=[1,1,1], [songs, jingles, single])
radio = random(weights=[1,1], [songs, jingles])
radio = amplify(1.,override="liq_amplify",radio)

# "Fake" LUFS playout adjust. Calculate at -18, play at -14 ;-)
# Good to use if you write tags (at -18 LUFS standard).
# radio = amplify(lin_of_dB(4.0), override=null(), radio)


# --- Copy-paste Azuracast LS Config, third input box BEGIN ---

# Be sure to have ReplayGain or "liq_amplify" applied before crossing.
#radio = amplify(1.,override="replaygain_track_gain",radio)
# AzuraCast already has the following line enabled:
#radio = amplify(1.,override="liq_amplify",radio)

# Show metadata in log
def show_meta(m)
  label="show_meta"
  l = list.sort.natural(metadata.cover.remove(m))
  list.iter(fun(v) -> log(level=4, label=label, "#{v}"), l)
  nowplaying = ref(m["artist"] ^ " - " ^ m["title"])
  if m["artist"] == "" then
    if string.contains(substring=" - ", m["title"]) then
      let (a, t) = string.split.first(separator=" - ", m["title"])
      nowplaying := a ^ " - " ^ t
    end
  end

  # show `liq_` & other metadata in level 3
  def fl(k, _) =
    tags = [
      "duration",
      "replaygain_track_gain",
      "replaygain_track_peak",
      "replaygain_track_range",
      "replaygain_reference_loudness"
    ]
    string.contains(prefix="liq_", k) or list.mem(k, tags)
  end
  liq = list.assoc.filter((fl), l)
  list.iter(fun(v) -> log(level=3, label=label, "#{v}"), liq)

  log(level=3, label=label, "Now playing: #{nowplaying()}")
  if m["liq_amplify"] == "" then
    log(level=2, label=label, "Warning: No liq_amplify found, expect loudness jumps!")
  end
  if m["liq_blank_skipped"] == "true" then
    log(level=2, label=label, "Blank (silence) detected in track, ending early.")
  end
end

radio.on_metadata(show_meta)

# Fading/crossing/segueing
def live_aware_crossfade(old, new) =
    if to_live() then
        # If going to the live show, play a simple sequence
        # fade out AutoDJ, do (almost) not fade in streamer
        sequence([
          fade.out(duration=settings.autocue.cue_file.fade_out(), old.source),
          fade.in(duration=settings.autocue.cue_file.fade_in(), new.source)
        ])
    else
        # Otherwise, use a beautiful add
        add(normalize=false, [
          fade.in(
            initial_metadata=new.metadata,
            duration=settings.autocue.cue_file.fade_in(),
            new.source
          ),
          fade.out(
            initial_metadata=old.metadata,
            duration=settings.autocue.cue_file.fade_out(),
            old.source
          )
        ])
    end
end

radio = cross(
  duration=settings.autocue.cue_file.fade_out(),
  live_aware_crossfade,
  radio
)

# --- Copy-paste Azuracast LS Config, third input box END ---

radio = mksafe(radio)

output(radio)

# record to a file for later checking with Audacity or the like
# also write a .cue file so we can find tracks more easily
# --- comment out the following one line if you have a pre-2.3.0 Liquidsoap version ---
#radio = source.cue(title="test_autocue.cue_file.liq", file="test_autocue.cue_file.mp3", "test_autocue.cue_file.cue", radio)
output.file(%mp3, "test_autocue.cue_file.mp3", radio)
