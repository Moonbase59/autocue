# test_local.liq

settings.log.level := 3

%include "fake_media_protocol.liq"
%include "autocue2.liq"

# Use YOUR base media folder here.
station_media_dir = "/home/matthias/Musik"

def show_meta(m)
  l = list.sort.natural(metadata.cover.remove(m))
  list.iter(fun(v) -> log(label="m", "#{v}"), l)
end

# testing
#settings.protocol.autocue2 := "cue_file"
#settings.protocol.autocue2.timeout := 60.
#settings.protocol.autocue2.target := -18
#settings.protocol.autocue2.silence := -42
#settings.protocol.autocue2.overlay := -8
#settings.protocol.autocue2.longtail := 15.0
#settings.protocol.autocue2.overlay_longtail := -15
settings.protocol.autocue2.blankskip := true

# Use YOUR playlist here
uri = station_media_dir ^ "/Playlists/Radio/Classic Rock.m3u"
radio = playlist(prefix="autocue2:", uri)

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
