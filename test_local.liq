# test_local.liq

settings.log.level := 3

%include "fake_media_protocol.liq"
%include "autocue.liq"

# Use YOUR base media folder here.
station_media_dir = "/home/matthias/Musik"

def show_meta(m)
  l = list.sort.natural(metadata.cover.remove(m))
  list.iter(fun(v) -> log(label="m", "#{v}"), l)
end

# testing
#settings.protocol.autocue := "cue_file"
#settings.protocol.autocue.timeout := 60.
#settings.protocol.autocue.target := -18
#settings.protocol.autocue.silence := -40
#settings.protocol.autocue.overlay := -8
#settings.protocol.autocue.longtail := 15.0
#settings.protocol.autocue.overlay_longtail := -15
settings.protocol.autocue.blankskip := true

uri = station_media_dir ^ "/Playlists/Radio/Classic Rock.m3u"
radio = playlist(prefix="autocue:", uri)

# Be sure to have ReplayGain applied before crossing.
radio = amplify(1.,override="liq_amplify",radio)

# Show metadata in log
radio.on_metadata(show_meta)

# Fading/crossing/segueing
def live_aware_crossfade(old, new) =
    log(label="crossfade", "Using custom crossfade")
    cross.smart(old, new, fade_in=0.1, fade_out=2.5, margin=8.)
end
radio = cross(duration=3.00, width=2.00, live_aware_crossfade, radio)

radio = mksafe(radio)

output.ao(radio)
# record to a file for later checking with Audacity or the like
output.file(%mp3, "test_local.mp3", radio)
