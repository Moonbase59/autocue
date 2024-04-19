# minimal_example_autocue.cue_file.liq
# 2024-04-09 - Moonbase59
# 2024-04-19 - Moonbase59 - renamed to "minimal_example_autocue.cue_file.liq"

# Minimal example for the `autocue2` protocol.
# Uses one playlist and outputs to sound card.

%include "autocue.cue_file.liq"

settings.autocue.cue_file.path := "./cue_file"
#settings.autocue.cue_file.fade_in := 0.1
#settings.autocue.cue_file.fade_out := 2.5
#settings.autocue.cue_file.blankskip := true
settings.autocue.preferred := "cue_file"
settings.autocue.amplify_behavior := "keep"
enable_autocue_metadata()

# --- Use YOUR playlist here! ---
radio = playlist("/home/matthias/Musik/Playlists/Radio/Classic Rock.m3u")

# Use calculated `liq_amplify` for loudness correction
radio = amplify(1.,override="liq_amplify",radio)

# simplest crossfade possible, using `autocue.cue_file` calculated data
# and default settings
radio = crossfade(radio)

radio = mksafe(radio)
output(radio)
