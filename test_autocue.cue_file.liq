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

settings.autocue.cue_file.path := "./cue_file"
# settings.autocue.cue_file.fade_in := 0.1
# settings.autocue.cue_file.fade_out := 2.5
# settings.autocue.cue_file.timeout := 60.0
settings.autocue.cue_file.target := -14.0  # not recommended
# settings.autocue.cue_file.silence := -42.0
# settings.autocue.cue_file.overlay := -8.0
# settings.autocue.cue_file.longtail := 15.0
# settings.autocue.cue_file.overlay_longtail := -15.0
settings.autocue.cue_file.noclip := true  # clipping prevention
settings.autocue.cue_file.blankskip := true
# settings.autocue.cue_file.unify_loudness_correction := true
# settings.autocue.cue_file.write_tags := false
# settings.autocue.cue_file.force_analysis := false
settings.autocue.cue_file.nice := true  # Linux/MacOS only!

# `enable_autocue_metadata()` will autocue ALL files Liquidsoap processes.
# You can disable it for selected sources using 'annotate:liq_cue_file=false'.
# Remember you won't get `liq_amplify` data then -- expect loudness jumps!
settings.autocue.preferred := "cue_file"
settings.autocue.amplify_behavior := "keep"
enable_autocue_metadata()

# --- Copy-paste END ---

# --- Use YOUR playlist here! ---
#uri = "/home/matthias/Musik/Playlists/Radio/Classic Rock.m3u"
uri = "/home/matthias/media/videostream/yyy"
#songs = playlist(prefix="autocue2:", uri)
songs = playlist(prefix='annotate:liq_dummy="DUMMY":', uri)

# --- Use YOUR playlist here! ---
uri = "/home/matthias/Musik/Other/Jingles/Short"
#uri = "/home/matthias/Musik/Other/Jingles/Programm"
# set jingle mode, no blank skipping, and some values like AzuraCast would
#jingles = playlist(prefix='autocue:annotate:jingle_mode="true",liq_blankskip="false",'
#  ^ 'liq_fade_in="0.10",liq_fade_out="0.10"'
#  ^ ':', uri)
jingles = playlist(prefix='annotate:jingle_mode="true",liq_blankskip="false",'
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
    tags = ["duration", "kind", "replaygain_track_gain", "replaygain_reference_loudness"]
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
    label = "live_aware_crossfade"
    if to_live() then
        # If going to the live show, play a simple sequence
        # fade out AutoDJ, do (almost) not fade in streamer
        sequence([fade.out(duration=2.5,old.source),fade.in(duration=0.1,new.source)])
    else
        # Otherwise, use the simple transition
        log(level=3, label=label, "Using custom crossfade")
        if (old.metadata["jingle_mode"] == "true")
          and (new.metadata["jingle_mode"] == "true") then
            log(level=3, label=label, "Jingle → Jingle transition")
        end
        if (old.metadata["jingle_mode"] == "true")
          and (new.metadata["jingle_mode"] == "") then
            log(level=3, label=label, "Jingle → Song transition")
        end
        if (old.metadata["jingle_mode"] == "")
          and (new.metadata["jingle_mode"] == "true") then
            log(level=3, label=label, "Song → Jingle transition")
        end
        if (old.metadata["jingle_mode"] == "")
          and (new.metadata["jingle_mode"] == "") then
            log(level=3, label=label, "Song → Song transition")
        end

        nd = float_of_string(default=0.1, list.assoc(default="0.1", "liq_cue_duration", new.metadata))
        xd = float_of_string(default=0.1, list.assoc(default="0.1", "liq_cross_duration", old.metadata))
        delay = max(0., xd - nd)
        log(level=3, label=label, "Cross/new/delay: #{xd} / #{nd} / #{delay} s")
        if (xd > nd) then
          log(level=2, label=label, "Cross duration #{xd} s longer than next track (#{nd} s)!")
        end

        # Starting with LS 2.2.5+git@cadd05596, we don’t need the delay anymore
        add(normalize=false,
          [fade.in(initial_metadata=new.metadata, duration=.1, new.source),
           fade.out(initial_metadata=old.metadata, duration=2.5, old.source)]
        )

        # Other options:
        # cross.simple(
        #   old.source,
        #   new.source,
        #   fade_in=0.1,
        #   fade_out=2.5,
        #   initial_fade_in_metadata=new.metadata,
        #   initial_fade_out_metadata=old.metadata
        # )
        #cross.smart(old, new, fade_in=0.1, fade_out=2.5, margin=8.)
    end
end

radio = cross(duration=2.5, live_aware_crossfade, radio)

# --- Copy-paste Azuracast LS Config, third input box END ---

radio = mksafe(radio)

output(radio)

# record to a file for later checking with Audacity or the like
# also write a .cue file so we can find tracks more easily
# --- comment out the following one line if you have a pre-2.3.0 Liquidsoap version ---
#radio = source.cue(title="test_autocue.cue_file.liq", file="test_autocue.cue_file.mp3", "test_autocue.cue_file.cue", radio)
output.file(%mp3, "test_autocue.cue_file.mp3", radio)
