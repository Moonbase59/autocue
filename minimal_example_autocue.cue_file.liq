# minimal_example_autocue.cue_file.liq
# 2024-04-09 - Moonbase59
# 2024-04-19 - Moonbase59 - renamed to "minimal_example_autocue.cue_file.liq"
# 2024-06-14 - Moonbase59 - update for autocue v4.0.0

# Minimal example for `autocue.cue_file`
# Uses one playlist and outputs to sound card.

%include "autocue.cue_file.liq"

# Your special non-default settings go here
# settings.autocue.cue_file.path := "cue_file"
# settings.autocue.cue_file.fade_in := 0.1
# settings.autocue.cue_file.fade_out := 2.5
# settings.autocue.cue_file.blankskip := 0.0

# Check Autocue setup, print result, shutdown if problems
# The check results will also be in the log.
# Returns a bool: true=ok, false=error. We ignore that here.
# set `print=true` for standalone scripts, `false` for AzuraCast
ignore(check_autocue_setup(shutdown=true, print=true))

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
