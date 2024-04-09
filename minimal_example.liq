# minimal_example.liq
# 2024-04-09 - Moonbase59

# Minimal example for the `autocue2` protocol.
# Uses one playlist and outputs to sound card.

%include "autocue2.liq"
enable_autocue2_metadata()

# --- Use YOUR playlist here! ---
radio = playlist("/home/matthias/Musik/Playlists/Radio/Classic Rock.m3u")

# Use calculated `liq_amplify` for loudness correction
radio = amplify(1.,override="liq_amplify",radio)

# simplest crossfade possible, using `autocue2` calculated data
# set fades to your preference
radio = crossfade(radio, fade_in=0.1, fade_out=2.5)

radio = mksafe(radio)
output(radio)
