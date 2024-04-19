# autocue changelog

### 2024-04-19

In preparation for later merge with `integrate-with-liquidsoap` branch:

- Renamed `test_local.liq` to `test_autocue2-liq`.
- Renamed `minimal_example.liq` to `minimal_example_autocue2.liq`.
- Updated README.md

### 2024-04-14

- Added **"intelligent" tag reading** to `cue_file`. It will try to determine if enough needed data is in the tags to successfully skip the lengthy analysis stage. If so, operation can be _dramatically faster_. Depending on various tests, it is also determined if an automatic re-analysis is necessary, i.e. when the LUFS target or the desired blankskip mode have changed.
- Added **tag writing** to `cue_file`, which can also be enabled by `settings.autocue2.write_tags` in Liquidsoap. **Note:** This is potentially dangerous, since it overwrites your audio files. `ffmpeg` can’t handle every type of tag for every type of file, so your mileage may vary. The file must be _re-written_, which can take a little moment. The new copy will then replace your original, in an atomic move operation.
  **Known problems:**
  - `.m4a` audio uses Apple’s very different tagging scheme, ffmpeg can’t currently write more than some very basic tags. You might even _lose_ tags here.
  - `.flac` works well, except ffmpeg insists in aggregating multiple tags of the same name _into one_, values separated by a semicolon `;`.
  - `.mka` (Matroska audio) works well, but the stream duration has an odd format and can’t currently be read, so `cue_file` will _always_ re-analyse these.
- `cue_file` will **never** touch existing `replaygain_track_gain` or `R128_TRACK_GAIN` tags when writing, since these might have been deliberately calculated by other software. It _will_ use these when _reading tags_, though, to determine loudness correction.
- `cue_file` can now be used as an **external pre-processor** to tag your files (like in a script that goes through all your files).
- Tags written/updated, in alphabetical order:
  - _liq_amplify_ — loudness correction, like ReplayGain
  - _liq_blankskip_ — does this track use blank skipping? (true/false)
  - _liq_blank_skipped_ — have we skipped blanks? (true/false)
  - _liq_cross_duration_ — deprecated, will eventually go
  - _liq_cross_start_next_ — start of next track, in seconds from beginning of file
  - _liq_cue_duration_ — playout length, between liq_cue_in & liq_cue_out, in seconds
  - _liq_cue_in_ — cue-in point, in seconds from beginning of file
  - _liq_cue_out_ — cue-out point, in seconds from beginning of file
  - _liq_longtail_ — does this track have a long ending, and been handled differently? (true/false)
  - _liq_loudness_ — integrated EBU R128 loudness of track
  - _liq_reference_loudness_ — reference loudness target used when calculating

### 2s024-04-13

- Changed `liq_duration` to `liq_cue_duration`, upon request by toots.
- Changed to use the new typed JSON external `cue_file` (thanks @toots!).
- Updated documentation (README.md).

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
