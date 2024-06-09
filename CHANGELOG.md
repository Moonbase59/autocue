# autocue changelog

### 2024-06-09 – v2.1.0

- Prepare for third-party pre-processing software:
  - A JSON file (or stdin) can now be used to set or override any of the
    known tags (see help). Values from JSON override values read from the
    audio file’s tags.
  - This can be used, for example, to set values from a database (like
    AzuraCast’s cue and fade data from their Visual Cue Editor).
  - `cue_file` might _still_ decide a re-analysis being necessary, so it’s
    wise to re-consolidate the data after `cue_file` has returned its results.
- More robust variable reading from tags or JSON:
  - Booleans can be bool or string
  - Typechecking on tags with unit suffixes, especially `liq_true_peak`,
    which was a "dbFS"-suffixed string in v1.2.3 and now is a linear float.
- Added `liq_fade_in` & `liq_fade_out` to known tags. We don’t use these,
  but pre-processors might want to set them.
- More advance example in `test_autocue.cue_file.liq` that shows how
  annotations can be used to play 15-second snippets of songs.

### 2024-06-08 – v2.0.3

- Fix ffmpeg erroneously treating `.ogg` files with cover image as video.
  The `.ogg` filetype is now handled by Mutagen.

### 2024-06-05 – v2.0.2

- Show autocue.cue_file version number in Liquidsoap log on startup,
  to ease bug hunting. Your `cue_file` should use the same version.

The log entry looks like this:

```
2024/06/05 16:16:03 [autocue.cue_file:2] You are using autocue.cue_file version 2.0.2.
2024/06/05 16:16:03 [autocue.cue_file:2] Assure that the external "cue_file" has the same version!
```

### 2024-06-04 - v2.0.1

- Fix small bug when reading already stored `liq_true_peak` that contained
  a ` dBFS` value from v1.2.3.

### 2024-06-04 – v2.0.0

Version 2.0.0 is out! It offers the chance to write ReplayGain data to
audio files, in addition to the Liquidsoap/Autocue tags.

This is useful for station owners that can’t or don’t want to use audio tracks
that have been pre-replaygained. You can now add ReplayGain data to songs and
thus ensure the analysis won’t be done over and over again.

This is an _additional_ option to the existing
write_tags feature and will only work when `write_tags` is enabled. Based on
our file analysis, it will save (and overwrite) ReplayGain Track data, such as
the gain value, the reference loudness, integrated loudness and true peak info.

The logic is inside `cue_file`, so it can as well be used for pre-processing
your files without the need of other tools. Autocue & ReplayGain—all in one!

The `cue_file` help now shows the file formats it supports, and the tags it
knows about. `cue_file` will automatically detect if Mutagen is installed and
offer you a whopping **20 more filetypes** to work with!

#### Breaking Changes:

- `liq_true_peak` (in dBFS) has been renamed to `liq_true_peak_db`.
- A new `liq_true_peak` has been added that stores the peak value as expected
  and needed by ReplayGain.
- Both `cue_file` and `autocue.cue_file.liq` must be updated to v2.0.0 for
  everything to work correctly.
- It is advisable to install Mutagen on the system running Liquidsoap, or in
  the AzuraCast Docker container. Doing this gets you more file and tag types
  you can work with, and safer/more compatible tagging.
  Mutagen can usually be installed with `pip3 install mutagen` (preferred), or
  `sudo apt install python3-mutagen` (often older versions, distros don’t
  update that often).


### 2024-06-04 – v1.2.3

First public version with a numbering scheme. We use SemVer:

- MAJOR.MINOR.PATCH
- MAJOR increments when API-breaking changes are released.
- MINOR increments with new functionality compatible with the existing API.
- PATCH increments when API-compatible bugfixes and minor changes are done.

The version numbers of `autocue.cue_file` and the external `cue_file` binary
should usually be the same.

Introducing:

- Mutagen (Pyhon tagging library) should be installed and allows writing tags
  to _many_ file and tagging formats.
- ffmpeg is now only used for tagging where we know it’s safe.
- Much better error checking:
  - Writing tags only to "known good" file types.
  - Gracefully skip writing to write-protected files/folders/drives.
  - `cue_file` has got better CLI params checking and much improved help.

### 2024-04-19

In preparation for later merge with `master` branch:

- Rename `autocue2.liq` to `autocue.cue_file.liq`.
- Rename `test_local.liq` to `test_autocue.cue_file.liq`.
- Use same `cue_file` as in `master` branch, update `autocue.cue_file.liq`.
- Add settings to `test_autocue.cue_file.liq` so `autocue` does the right thing (hopefully).

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
