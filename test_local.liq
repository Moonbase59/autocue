# test_local.liq
# 2024-03-31 - Moonbase59

# Test the `autocue2:` protocol and crossfading code locally,
# using a "songs" and a "jingles" playlist.
# Output to speakers and the following files:
#   test_local.log -- the Liquidsoap log file
#   test_local.mp3 -- recording, for later checking
#   test_local.cue -- cue file to better find songs (open THIS in your audio player)
#                     Note: `source.cue` support in LS 2.3.0+ only!

# For a certain test duration, like 120 minutes, use
#   timeout 120m liquidsoap test_local.liq

# Log to file, for later diagnosis. To follow the log in another terminal, use
#   tail -f test_local.log
settings.log.file := true
settings.log.file.path := "test_local.log"
settings.log.file.append := false

# 3=important, 4=info
settings.log.level := 3

# no "live" in the local test
to_live = ref(false)

# --- Copy-paste the CONTENTS of `autocue2.liq` into AzuraCast, second input box ---
%include "autocue2.liq"

# --- Copy-paste your settings into AzuraCast, second input box AFTER above file ---
#settings.autocue2.path := "cue_file"
#settings.autocue2.timeout := 60.
#settings.autocue2.target := -18
#settings.autocue2.silence := -42
#settings.autocue2.overlay := -8
#settings.autocue2.longtail := 15.0
#settings.autocue2.overlay_longtail := -15
# The following can be overridden by the `liq_blankskip` annotation
# on a per-request or per-playlist basis
settings.autocue2.blankskip := true
#settings.autocue2.unify_loudness_correction := true

# `enable_autocue2_metadata()` will autocue ALL files Liquidsoap processes.
# You can disable it for selected sources using 'annotate:liq_autocue="false"'.
# Remember you won't get `liq_amplify` data then -- expect loudness jumps!
enable_autocue2_metadata()

# --- Copy-paste END ---

# --- Use YOUR playlist here! ---
uri = "/home/matthias/Musik/Playlists/Radio/Classic Rock.m3u"
#songs = playlist(prefix="autocue2:", uri)
songs = playlist(uri)

# --- Use YOUR playlist here! ---
#uri = "/home/matthias/Musik/Other/Jingles/Short"
uri = "/home/matthias/Musik/Other/Jingles/Programm"
# set jingle mode, no blank skipping, and some values like AzuraCast would
#jingles = playlist(prefix='autocue2:annotate:jingle_mode="true",liq_blankskip="false",'
#  ^ 'liq_cross_duration="0.10",liq_fade_in="0.10",liq_fade_out="0.10"'
#  ^ ':', uri)
jingles = playlist(prefix='annotate:jingle_mode="true",liq_blankskip="false",'
  ^ 'liq_cross_duration="0.10",liq_fade_in="0.10",liq_fade_out="0.10"'
  ^ ':', uri)

# --- Use YOUR single here! ---
# Trying to exclude a single from autocue processing here, just for testing.
# Should say "Skipping autocue..." in log
uri = "/home/matthias/Musik/Other/Jingles/Short/Magenta - How sentimental.flac"
single = single('annotate:liq_autocue="false",dummy="A Test!":#{uri}')

radio = random(weights=[1,1,1], [songs, jingles, single])
radio = amplify(1.,override="liq_amplify",radio)


# --- Copy-paste Azuracast LS Config, third input box BEGIN ---

# Be sure to have ReplayGain or "liq_amplify" applied before crossing.
#radio = amplify(1.,override="replaygain_track_gain",radio)
# AzuraCast already has the following line enabled:
#radio = amplify(1.,override="liq_amplify",radio)

# Show metadata in log
def show_meta(m)
  label="show_meta"
  l = list.sort.natural(metadata.cover.remove(m))
  list.iter(fun(v) -> log.info(label=label, "#{v}"), l)
  nowplaying = ref(m["artist"] ^ " - " ^ m["title"])
  if m["artist"] == "" then
    if string.contains(substring=" - ", m["title"]) then
      let (a, t) = string.split.first(separator=" - ", m["title"])
      nowplaying := a ^ " - " ^ t
    end
  end

  # show `liq_` & other metadata in level 3
  def fl(k, _) =
    tags = ["duration", "kind", "replaygain_track_gain"]
    string.contains(prefix="liq_", k) or list.mem(k, tags)
  end
  liq = list.assoc.filter((fl), l)
  list.iter(fun(v) -> log.important(label=label, "#{v}"), liq)

  log.important(label=label, "Now playing: #{nowplaying()}")
  if m["liq_amplify"] == "" then
    log.severe(label=label, "Warning: No liq_amplify found, expect loudness jumps!")
  end
  if m["liq_blank_skipped"] == "true" then
    log.severe(label=label, "Blank (silence) detected in track, ending early.")
  end
end

radio.on_metadata(show_meta)

# Fading/crossing/segueing
def live_aware_crossfade(old, new) =
    label = "live_aware_crossfade"
    if to_live() then
        # If going to the live show, play a simple sequence
        # fade out AutoDJ, do (almost) not fade in streamer
        sequence([fade.out(duration=2.5,old.source),fade.in(duration=0.1,new.source)])
    else
        # Otherwise, use the simple transition
        log.important(label=label, "Using custom crossfade")
        if (old.metadata["jingle_mode"] == "true")
          and (new.metadata["jingle_mode"] == "true") then
            log.important(label=label, "Jingle → Jingle transition")
        end
        if (old.metadata["jingle_mode"] == "true")
          and (new.metadata["jingle_mode"] == "") then
            log.important(label=label, "Jingle → Song transition")
        end
        if (old.metadata["jingle_mode"] == "")
          and (new.metadata["jingle_mode"] == "true") then
            log.important(label=label, "Song → Jingle transition")
        end
        if (old.metadata["jingle_mode"] == "")
          and (new.metadata["jingle_mode"] == "") then
            log.important(label=label, "Song → Song transition")
        end

        nd = float_of_string(default=0.1, list.assoc(default="0.1", "liq_duration", new.metadata))
        xd = float_of_string(default=0.1, list.assoc(default="0.1", "liq_cross_duration", old.metadata))
        delay = max(0., xd - nd)
        log.important(label=label, "Cross/new/delay: #{xd} / #{nd} / #{delay} s")
        if (xd > nd) then
          log.severe(label=label, "Cross duration #{xd} s longer than next track (#{nd} s)!")
          log.severe(label=label, "Delaying fade-out & next track fade-in by #{delay} s.")
        end

        # If needed, delay BOTH fade-out and fade-in, to avoid dead air.
        # This ensures a better transition for jingles shorter than cross_duration.
        add(normalize=false, [fade.in(initial_metadata=new.metadata, duration=.1, delay=delay, new.source), fade.out(initial_metadata=old.metadata, duration=2.5, delay=delay, old.source)])
        #cross.simple(old.source, new.source, fade_in=0.1, fade_out=2.5)
        #cross.smart(old, new, fade_in=0.1, fade_out=2.5, margin=8.)
    end
end

#radio = cross(reconcile_duration=true, duration=3.0, width=2.0, live_aware_crossfade_simple, radio)
radio = cross(duration=3.0, width=2.0, live_aware_crossfade, radio)

# --- Copy-paste Azuracast LS Config, third input box END ---

radio = mksafe(radio)

output.ao(radio)

# record to a file for later checking with Audacity or the like
# also write a .cue file so we can find tracks more easily
# --- comment out the following one line if you have a pre-2.3.0 Liquidsoap version ---
#radio = source.cue(title="test_local.liq", file="test_local.mp3", "test_local.cue", radio)
output.file(%mp3, "test_local.mp3", radio)
