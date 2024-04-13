# autocue changelog

### 2024-04-13

- Changed `liq_duration` to `liq_cue_duration`, upon request by toots.
- Changed to use the new typed JSON external `cue_file` (thanks @toots!).

### 2024-04-10

- Started a CHANGELOG.md, so interested parties can follow.
- Streamlined `autocue2` code, removed unnecessary stuff.
- Change and solidify metadata handling. It now ensures that:
  - Metadata seen in both `autocue2:` protocol and `enable_autocue2_metadata()` mode.
  - All "processing flags" always seen, like
    - `liq_autocue2`
    - `liq_blankskip`
    - `jingle_mode`
  - `replaygain_track_gain` & `liq_amplify` always unified when `settings.autocue2.unify_loudness_correction` is `true`. ReplayGain, if it exists, takes precedence.
  - All possible combinations of `enable_autocue2_metadata()`, `autocue2:` protocol, and `annotate:` actually work correctly. It is still considered a user error if `enable_autocue2_metadata()` is used in conjunction with `autocue2:`, since this would invoke processing _twice_.
  - _Priorities_ are always respected, so the user can _override_ automatically calculated values using _tags_ in the files, _annotations_ or _AzuraCast’s Visual Cue Editor_, for example. Priorities are, from lowest to highest:
    - Calculated values from `cue_file`/`autocue2`.
    - `liq_*` and `replaygain_track_gain` as _tags_ in the audio file.
    - Annotated settings like `liq_blankskip=false`. These include all settings coming from _AzuraCast’s Visual Cue Editor_ and _Advanced Edit Media_ settings.

You can now do really wild things, like enabling `autocue2` processing globally, and _still_ create something like a "sampling" playlist which plays 30s-snippets of a list of songs. And even with the simplest crossfade command possible!

```ruby
enable_autocue2_metadata()

...

radio = playlist(
  prefix='annotate:liq_cue_in=30.,liq_cue_out=60.,liq_cross_duration=2.5:',
  'Classic Rock.m3u'
)

radio = crossfade(radio, fade_in=0.1, fade_out=2.5)
```

Or you can _exclude_ your video files from processing, for example:

```ruby
video_playlist_night = playlist(
  id="video_playlist_night",
  prefix="annotate:liq_autocue2=false:",
  mode="randomize", reload_mode="watch", videos_night_folder)
```

The sky is the limit!
