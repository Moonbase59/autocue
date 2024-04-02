# autocue
On-the-fly JSON song cue-in, cue-out, overlay, replaygain calculation for Liquidsoap, AzuraCast and other AutoDJ software.

Work in progress.

Requires Python3 and `ffmpeg` with the _ebur128_ filter. (The AzuraCast Docker already has these.)

Tested on Linux and Mac, with several `ffmpeg` versions ranging from 4.4.2–6.1.1, and running on several stations since a few weeks.

Basically, `autocue` consists of two parts:
- `cue_file`, a Python3 script, that returns JSON cueing, loudness and overlay data for an audio file. This can be used standalone, as part of some pre-processing or AutoDJ software, or in conjunction with below.
- The [Liquidsoap](https://www.liquidsoap.info/) `autocue2:` protocol, for full integration into Liquidsoap, which in turn can be used standalone or as part of a larger playout system like [AzuraCast](https://www.azuracast.com/) or others.

**Note:** Liquidsoap recently introduced a _bultin_ `autocue:` protocol. I had to rename my `autocue:` protocol to `autocue2:` so it doesn’t clash with the other one.

## Install

### `cue_file`

Put `cue_file` in your path locally (i.e., into `~/bin`, `~/.local/bin` or `/usr/local/bin`) and `chmod+x` it.

### Local testing

Use the code in `test_local.liq` for some local testing, if you have Liquidsoap installed on your machine.

Look for
```
# --- Use YOUR ... here! ---
```
and put in _your_ song and jingle playlist, and a `single` for testing.

Then run
```
$ liquidsoap test_local.liq
```

Depending on your settings, you’ll get some result files for further study:

- `test_local.log` -- Log file, use `tail -f test_local.liq` in another terminal to follow
- `test_local.mp3` -- an MP3 recording, to see how well the track transitions worked out
- `test_local.cue` -- a `.cue` file to go with the MP3 recording, for finding tracks easier (open _this_ in your audio player)

### AzuraCast

#### `cue_file`

On your AzuraCast host, you can put it into `/var/azuracast/bin` and overlay it into the Docker by adding a line to your `docker-compose.override.yml`, like so:

```yaml
services:
  web:
    volumes:
      - /var/azuracast/bin/cue_file:/usr/local/bin/cue_file
```

#### Use Plugin or not?

With AzuraCast, you now have two options for installing:

1. Without modifying the generated AzuraCast Liquidsoap config. Use `enable_autocue2_metadata()` for that. _Drawback:_ You can’t use `settings.autocue2.blankskip := true` and expect "hidden" jingles to be automatically exempted from finding silent parts in the tracks.
2. You can modify the AzuraCast Liquidsoap config by installing @RM-FM’s [`ls-config-replace`](https://github.com/RM-FM/ls-config-replace) plugin, and copying over the `ls-config-replace/liq/10_audodj_next_song_add_autocue` folder into your `/var/azuracast/plugins/ls-config-replace/liq` folder after installing the plugin. This will allow using _all features_.

If you wish to disable AzuraCast’s built-in `liq_amplify` handling and rather use your tagged ReplayGain data, also copy over the `12_remove_amplify` folder.

#### Add the `autocue2` protocol code

Then copy-paste the contents of the `autocue2.liq` file into _the second input box_ in your station’s Liquidsoap Config.

If you want to enable skipping silence _within tracks_, add the following line at the end of this input box:

```
settings.autocue2.blankskip := true
```

**Note:** This should only be used with installation variant 2 (plugin/modify config).

#### Custom crossfading code

Use the example in `test_local.liq` and add your custom `amplify` and `live_aware_crossfade` code in the _third input box_ of AzuraCast’s Liquidsoap Config. You might already have modified this in your local testing above.

To find the relevant parts, look out for

```
# --- Copy-paste ...
```

**Note:** If you had used ReplayGain adjustment before like so (third input box)

```
# Be sure to have ReplayGain applied before crossing.
radio = amplify(1.,override="replaygain_track_gain",radio)
```

you might want to _delete_ or _comment out_ these lines. The `autocue2:` protocol already calculates a `liq_amplify` value that is recognized by AzuraCast and roughly equals a ReplayGain "track gain". If you would leave _both_ in, you’d get a much too quiet playout.

#### ReplayGain vs. `liq_amplify`

If you have disabled AzuraCast’s built-in `liq_amplify` handler (by copying `12_remove_amplify` above), _you_ have the choice. But you _must_ define your own adjustment (start of third input box).

Example, to use your own tagged _ReplayGain Track Gain_ instead:

```
# Be sure to have ReplayGain or "liq_amplify" applied before crossing.
radio = amplify(1.,override="replaygain_track_gain",radio)
#radio = amplify(1.,override="liq_amplify",radio)
```

Pros & Cons:
- ReplayGain can be more exact (and prevent clipping) if pre-tagged with a tool like [`loudgain`](https://github.com/Moonbase59/loudgain).
- ReplayGain values _should exist as tags_ in your audio files. If not, and `settings.autocue2.unify_loudness_correction := true`, `autocue2` will insert an (internal) `replaygain_track_gain` value.
- `cue_file` (and thus the `autocue2:` protocol) will _always_ calculate a `liq_amplify` value _on the fly_, so it can be used with any audio file (even when not pre-tagged)
- `liq_amplify` has no means of clipping prevention or EBU-recommended -1 dB/LU margin. The value still resembles a _ReplayGain Track Gain_ closely, in most cases.
- _Both_ can be used with `autocue2:`.

Save and _Restart Broadcasting_.

## Command-line interface

```
usage: cue_file [-h]
                [-t {-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0}]
                [-s SILENCE] [-o OVERLAY] [-l LONGTAIL] [-x EXTRA] [-b] [-w]
                [-f]
                file

Return cue-in, cue-out, overlay and replaygain data for an audio file as JSON.
To be used with my Liquidsoap "autocue2:" protocol.

positional arguments:
  file                  File to be processed

options:
  -h, --help            show this help message and exit
  -t {-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0}, --target {-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0}
                        LUFS reference target (default: -18.0)
  -s SILENCE, --silence SILENCE
                        LU/dB below integrated track loudness for cue-in &
                        cue-out points (silence removal at beginning & end of
                        a track) (default: -42.0)
  -o OVERLAY, --overlay OVERLAY
                        LU/dB below integrated track loudness to trigger next
                        track (default: -8.0)
  -l LONGTAIL, --longtail LONGTAIL
                        More than so many seconds of calculated overlay
                        duration are considered a long tail, and will force a
                        recalculation using --extra, thus keeping long song
                        endings intact (default: 15.0)
  -x EXTRA, --extra EXTRA
                        Extra LU/dB below overlay loudness to trigger next
                        track for songs with long tail (default: -15.0)
  -b, --blankskip       Skip blank (silence) within song (get rid of "hidden
                        tracks"). Sets the cue-out point to where the silence
                        begins. Don't use this with spoken or TTS-generated
                        text, as it will often cut the message short.
                        (default: False)
  -w, --write           Write Liquidsoap tags to file (default: False)
  -f, --force           Force re-calculation, even if tags exist (default:
                        False)
```

## Examples

### Hidden track

The well-known _Nirvana_ song _Something in the Way / Endless, Nameless_ from their 1991 album _Nevermind_:

![Auswahl_352](https://github.com/Moonbase59/autocue/assets/3706922/fa7e66e9-ccd8-42f3-8051-fa2fc060a939)

It contains the 3:48 song _Something in the Way_, followed by 10:03 of silence, followed by the "hidden track" _Endless, Nameless_.

**Normal mode (no blank detection):**

```
$ cue_file "Nirvana - Something in the Way _ Endless, Nameless.mp3" 
{"duration": "1235.10", "liq_duration": "1231.60", "liq_cue_in": "0.40", "liq_cue_out": "1232.00", "liq_longtail": "false", "liq_cross_duration": "9.80", "liq_loudness": "-10.47 dB", "liq_amplify": "-7.53 dB", "liq_blank_skipped": "false"}
```

**With blank detection (cue-out at start of silence):**

```
$ cue_file -b "Nirvana - Something in the Way _ Endless, Nameless.mp3" 
{"duration": "1235.10", "liq_duration": "227.10", "liq_cue_in": "0.40", "liq_cue_out": "227.50", "liq_longtail": "false", "liq_cross_duration": "3.50", "liq_loudness": "-10.47 dB", "liq_amplify": "-7.53 dB", "liq_blank_skipped": "true"}
```

where
- _duration_ — the real file duration (including silence at start/end of song), in seconds
- _liq_duration_ — the actual playout duration (cue-in to cue-out), in seconds
- _liq_cue_in_ — cue-in point, in seconds
- _liq_cue_out_ — cue-out point, in seconds
- _liq_longtail_ — flag to show if song has a "long tail", i.e. a very long fade-out (true/false)
- _liq_cross_duration_ — suggested crossing duration for next song, in seconds backwards from cue-out point
- _liq_loudness_ — song’s EBU R128 loudness, in dB (=LU)
- _liq_amplify_ — simple "ReplayGain" value, offset to desired loudness target (i.e., -18 LUFS). This is intentionally _not_ called _replaygain_track_gain_, since that tag might already exist and have been calculated using more exact tools like [`loudgain`](https://github.com/Moonbase59/loudgain).
- _liq_blank_skipped_ — flag to show that we have an early cue-out, caused by silence in the song (true/false)

### Long tail handling

_Bohemian Rhapsody_ by _Queen_ has a rather long ending, which we don’t want to destroy by overlaying the next song too early. This is where `cue_file`’s automatic "long tail" handling comes into play. Let’s see how the end of the song looks like:

![Auswahl_363](https://github.com/Moonbase59/autocue/assets/3706922/28f82f63-6341-4064-aaed-36339b0a2d4d)

Here are the values we get from `cue_file`:

```
$ cue_file "Queen - Bohemian Rhapsody.flac" 
{"duration": "355.10", "liq_duration": "353.10", "liq_cue_in": "0.00", "liq_cue_out": "353.10", "liq_longtail": "true", "liq_cross_duration": "4.70", "liq_loudness": "-15.50 dB", "liq_amplify": "-2.50 dB", "liq_blank_skipped": "false"}
```

We notice the `liq_longtail` flag is `true`, and the `liq_cross_duration` is `4.70` seconds.

Let’s follow the steps `cue_file` took to arrive at this result.

#### Cue-out point

`cue_file` uses the `-s`/`--silence` parameter value (-42 LU default) to scan _backwards from the end_ for something that is louder than -42 LU below the _average (integrated) song loudness_, using the EBU R128 momentary loudness algorithm. This is _not_ a simple "level check"! Using the default (playout) reference loudness target of `-18 LUFS` (`-t`/`--target` parameter), we thus arrive at a noise floor of -60 LU, which is a good silence level to use.

![Auswahl_359](https://github.com/Moonbase59/autocue/assets/3706922/c745989a-5f32-4aa1-a5b7-ac4bc955e568)

`cue_file` has determined the _cue-out point_ at `353.10` seconds (5:53.1).

#### Cross duration (where the next track could start and be overlaid)

Liquidsoap uses a `liq_cross_duration` concept instead of an abolute "start next" point, since that could be ambiguous (start counting at the beginning of the file or at the cue-in point?). The cross duration is measured in seconds _backwards from the cue-out point_.

`cue_file` uses the `-o`/`--overlay` parameter value (-8 LU default) to scan _backwards from the cue-out point_ for something that is louder than -8 LU below the _average (integrated) song loudness_, thus finding a good point where the next song could start and be overlaid.

![Auswahl_360](https://github.com/Moonbase59/autocue/assets/3706922/20a9396b-a31a-4a11-87b4-641d6868cc49)

`cue_file` has determined a _cross duration_ of `16.70` seconds, starting at 336.4 seconds (5:36.4).

We can see this would destroy an important part of the song’s end.

#### A long tail!

Finding that the calculated cross duration of `16.70` seconds is longer than 15 seconds (the `-l`/`--longtail` parameter), `cue_file` now _recalculates the cross duration_ automatically, using an extra -15 LU loudness offset (`-x`/`--extra` parameter), and arrives at this:

![Auswahl_361](https://github.com/Moonbase59/autocue/assets/3706922/9f9ec3af-89d4-4edc-9316-d53ed1fcf000)

`cue_file` has now set `liq_cross_duration` to `4.70` seconds and `liq_longtail` to `true` so we know this song has a "long tail" and been calculated differently.

Much better!

#### Avoiding too much overlap

We possibly don’t want the previous song to play "too much" into the next song, so we can set a _default fade-out_ in our custom crossfading. This will ensure a limit in case no user-defined fade-out has been set. We use `2.5` seconds in the example below (under _AzuraCast Notes_, in `live_aware_crossfade`):

```
add(normalize=false, [fade.in(duration=.1, delay=delay, new.source), fade.out(duration=2.5, delay=delay, old.source)])
```

![Auswahl_362](https://github.com/Moonbase59/autocue/assets/3706922/f1e96db6-2f23-4cdd-9693-24711fe91895)

Fading area, using above settings. The rest of the ending won’t be heard.

### Blank (silence) detection

**Note:** Blank detection _within a song_ is experimental. It will most certainly _fail_ on spoken or TTS-generated messages (since spoken text has long pauses), and it can fail on some songs with very smooth beginnings, like _Sarah McLachlan’s Fallen_:

![Auswahl_353](https://github.com/Moonbase59/autocue/assets/3706922/c1085156-5483-4474-afd8-cb437d0d2e4b)

This song works fine in "normal mode", but only a 0.6 second portion (marked) of the beginning is played in "blank detection" mode when using the default settings:

```
$ cue_file -b "McLachlan, Sarah - Fallen (radio mix).flac" 
{"duration": "229.00", "liq_duration": "0.60", "liq_cue_in": "2.30", "liq_cue_out": "2.90", "liq_longtail": "false", "liq_cross_duration": "0.10", "liq_loudness": "-8.97 dB", "liq_amplify": "-9.03 dB", "liq_blank_skipped": "true"}
```

You can avoid such issues in several ways:
- Don’t use the `-b`/`--blankstrip` option (default).
- Lower the silence level: `-s -50`/`--silence -50`.
- Manually assign later cue-in/cue-out points in the AzuraCast UI (user settings here overrule the automatic values).

Example result when reducing the silence level to -50 LU below average:

```
$ cue_file -b -s -50 "McLachlan, Sarah - Fallen (radio mix).flac" 
{"duration": "229.00", "liq_duration": "221.90", "liq_cue_in": "1.90", "liq_cue_out": "223.80", "liq_longtail": "false", "liq_cross_duration": "8.30", "liq_loudness": "-8.97 dB", "liq_amplify": "-9.03 dB", "liq_blank_skipped": "false"}
```

Notice the new cue-in and cue-out times as well as the long cross duration with this change!


## Liquidsoap protocol

**Note: The `autocue2:` protocol is meant to be used with [Liquidsoap 2.2.5](https://github.com/savonet/liquidsoap/releases) or newer.**

The protocol is invoked by prefixing a playlist or request with `autocue2:` like so:

```
radio = playlist(prefix="autocue2:", "/home/matthias/Musik/Playlists/Radio/Classic Rock.m3u")
```

Alternatively, you can set `enable_autocue2_metadata()` and it will process _all files_ Liquidsoap handles. Use _either_—_or_, but not _both_ variants together. If running video streams, you might also want to _exclude_ the video files from processing, by annotating `liq_autocue=false` for them, for instance as a playlist prefix. `autocue2` _can_ handle multi-gigabyte video files, but that will eat up _lots_ of CPU (and bandwidth) and might bring your station down.

`autocue2` offers the following settings (defaults shown):

```
settings.autocue2.path := "cue_file"
settings.autocue2.timeout := 60.
settings.autocue2.target := -18
settings.autocue2.silence := -42
settings.autocue2.overlay := -8
settings.autocue2.longtail := 15.0
settings.autocue2.overlay_longtail := -15
# The following can be overridden by the `liq_blankskip` annotation
# on a per-request or per-playlist basis
settings.autocue2.blankskip := false
# Unify can only work correctly if your files have been replaygained
# to the same LUFS target as your `settings.autocue2.target`,
# usually -23 or -18 LUFS (-18 corresponds to the now obsolete `mp3gain` value "89 dB").
settings.autocue2.unify_loudness_correction := true
```

### Tags/Annotations that influence `autocue2`’s behaviour

There are three possible _annotations_ (or tags from a file) that can influence `autocue2`’s behaviour. In an annotation string, these must occur _to the right_ of the protcol, i.e. `autocue2:annotate:...` to work as intended. Think of these as "switches" to enable or disable features.

#### `liq_autocue` (`true`/`false`)

You can _disable_ autocueing for selected sources, like maybe a playlist of large video files, even when `autocue2` is globally enabled.

So if you’ve used

```
enable_autocue2_metadata()
```

to globally enable `autocue2`, and want to _exclude_ a playlist from processing, use:

```
p = playlist(prefix='annotate:liq_autocue="false":', '/path/to/playlist.ext')
```

If a track has been skipped, it will be shown in the logs like this:

```
2024/04/01 10:47:00 [autocue2_metadata:2] Skipping autocue2 for file "/home/matthias/Musik/Other/Jingles/Short/Magenta - How sentimental.flac" because liq_autocue=false forbids it.
```

**Note:** Using this makes only sense if you used `enable_autocue2_metadata()`. When using the `autocue2:` _protocol_ in your annotations, you’d simply leave the `autocue2:` part off the annotation instead.

#### `liq_blankskip` (`true`/`false`)

You can _override_ the "blankskip" behaviour (early cue-out of a song when silence is detected) on a per-request or per-playlist basis using a special `liq_blankskip` annotation. This is an "ultimate override" which overrides both `settings.autocue2.blankskip` and `jingle_mode`.

For a `playlist`, you could use its `prefix`, like in

```
p = playlist(prefix='autocue2:annotate:liq_blankskip="false":', '/path/to/playlist.ext')
```

For a `single`, this would look like

```
s = single('autocue2:annotate:liq_blankskip="false":/path/to/file.ext')
```

Or for a `request` like

```
r = request.create('autocue2:annotate:liq_blankskip="false":/path/to/file.ext')
```

This allows for a general protocol-wide setting, but exceptions for special content, like a playlist containing spoken content that would otherwise be cut.

The logs will show if blank skipping has been used on a track:

```
2024/04/01 06:43:40 [autocue2.compute:3] Blank (silence) skipping active: true
```

In the returned _metadata_, in `liq_blank_skipped`, you’ll also receive information if something actually _has_ been skipped. So for the _Nirvana_ song above, it would show:

```
2024/04/01 11:00:47 [autocue2.metadata:3] ("liq_blank_skipped", "true")
```

`liq_blankskip` is the _switch_ that controls `autocue2`’s behaviour, while `liq_blank_skipped` is the _result_ of the operation.

#### AzuraCast: `jingle_mode` (`"true"`)

This is a convenience feature for AzuraCast users. If you set _Hide Metadata from Listeners ("Jingle Mode")_ to ON for a playlist in AzuraCast, it will annotate requests for this playlist with `jingle_mode="true"`. Even if blank skipping for songs is globally enabled, we would not want this to happen for jingles. They might contain pauses in speech that could cut them off early.

So if `autocue2` sees this annotation (or tag in a file), it will automatically _disable_ "blankskip" for this track.

Note this setting is superceded by `liq_blankskip`, the "ultimate blankskip switch". So if _both_ are there, the setting from `liq_blankskip` will "win".

### AzuraCast Notes

- `media:` URIs will be resolved.
- Works well with smart crossfades. (But these are definitely not needed, see code below!)
- Even when `settings.autocue2.blankskip := true`, hidden jingles (those with a `jingle_mode="true"` annotation) will be _excluded_ from blank detection within the track, because the chance is too high that spoken text gets cut.
- User settings in the AzuraCast UI ("Edit Song") always "win" over the calculated values.
- Currently needs a patch to the AzuraCast-generated Liquidsoap code to enable _all features_, but you can also opt to use `enable_autocue2_metadata()` instead, _not_ use `settings.autocue2.blankskip := true` and skip all the plugin-related things.
- Currently generates _lots_ of log data, for debugging. This will eventually change. But hey, you can see what it does!

Typical log sample (level 3; level 4 gives much more details):

```
2024/04/01 06:43:40 [autocue2.compute:3] Now autocueing: "annotate:title="Dancing in the Street",artist="David Bowie & Mick Jagger",duration="190.00",song_id="c7ea81945a4b20b2905cee98b05af5c3",media_id="277242",playlist_id="533":media:Tagged/Bowie, David/Bowie, David - The Singles Collection (1993 album, compilation, GB)/Bowie, David & Jagger, Mick - Dancing in the Street.flac"

...

2024/04/01 06:43:40 [autocue2.compute:3] Blank (silence) skipping active: true
2024/04/01 06:43:42 [autocue2.compute:3] Autocue2 result for "/var/azuracast/stations/niteradio/media/Tagged/Bowie, David/Bowie, David - The Singles Collection (1993 album, compilation, GB)/Bowie, David & Jagger, Mick - Dancing in the Street.flac": {"duration": "190.70", "liq_duration": "187.50", "liq_cue_in": "0.50", "liq_cue_out": "188.00", "liq_longtail": "false", "liq_cross_duration": "6.60", "liq_loudness": "-7.78 dB", "liq_amplify": "-10.22 dB", "liq_blank_skipped": "false"}
2024/04/01 06:43:42 [autocue2.metadata:3] Inserted replaygain_track_gain: -10.22 dB
```

I currently[^1] use these crossfade settings (third input box in AzuraCast; lots of debugging info here, could be much shorter):

```
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

radio = cross(duration=3.0, width=2.0, live_aware_crossfade, radio)
```

If you have a long `liq_cross_duration` and a jingle following that is _shorter_ than the computed crossing duration, above ensures the jingle can be played correctly by effectively _shifting it to the right within the crossing duration window_, thus playing it _later than originally computed_ and ensuring correct playout for the following track.

We currently do this in above shown crossfading code. If this happens, a message will be logged:

```
2024/03/26 17:07:56 [live_aware_crossfade:3] Song → Jingle transition
2024/03/26 17:07:56 [live_aware_crossfade:2] Cross duration 5.9 s longer than next track (3.4 s)!
2024/03/26 17:07:56 [live_aware_crossfade:2] Delaying fade-out & next track fade-in by 2.5 s.
```

The 2.5 s fade-out helps tuning long overlap durations down, so they won’t distract the listener by overlaying songs and possibly jingles too long. The increased margin (8 dB/LU) helps making the smart crossfades sound much better.

~~Jingles should not be shorter than the duration specified in `cross`.~~


[^1]: As of 2024-04-02. _Liquidsoap_ has a very active development, so things might change.
