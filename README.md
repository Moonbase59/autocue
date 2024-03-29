# autocue
On-the-fly JSON song cue-in, cue-out, overlay, replaygain calculation for Liquidsoap, AzuraCast and other AutoDJ software.

Work in progress.
- **_Liquidsoap documentation not up-to-date, will fix._**
- You also don’t need the plugin anymore and can simply use `enable_autocue2_metadata()`.

Requires Python3 and `ffmpeg` with the _ebur128_ filter. (The AzuraCast Docker already has these.)

Tested on Linux and Mac, with several `ffmpeg` versions ranging from 4.4.2–6.1.1, and running on several stations since a few weeks.

## Install

Put `cue_file` in your path locally (i.e., into `~/bin`, `~/.local/bin` or `/usr/local/bin`) and `chmod+x` it.

On your AzuraCast host, you can put it into `/var/azuracast/bin` and overlay it into the Docker by adding a line to your `docker-compose.override.yml`, like so:

```yaml
services:
  web:
    volumes:
      - /var/azuracast/bin/cue_file:/usr/local/bin/cue_file
```

With AzuraCast, you’ll need to change the auto-generated Liquidsoap Configuration to handle my `autocue2:` protocol. This can be done by installing @RM-FM’s [`ls-config-replace`](https://github.com/RM-FM/ls-config-replace) plugin, and copying over the `ls-config-replace/liq/10_audodj_next_song_add_autocue` folder into your `/var/azuracast/plugins/ls-config-replace/liq` folder after installing the plugin.

If you wish to disable AzuraCast’s built-in `liq_amplify` handling and rather use your tagged ReplayGain data, also copy over the `12_remove_amplify` folder.

Then copy-paste the contents of the `autocue2.liq` file into the second input box in your station’s Liquidsoap Config.

If you want to enable skipping silence _within tracks_, add the following line at the end of this input box:

```
settings.protocol.autocue2.blankskip := true
```

**Note:** If you had used ReplayGain adjustment before like so (third input box)

```
# Be sure to have ReplayGain applied before crossing.
radio = amplify(1.,override="replaygain_track_gain",radio)
```

you might want to _delete_ or _comment out_ these lines. The `autocue2:` protocol already calculates a `liq_amplify` value that is recognized by AzuraCast and roughly equals a ReplayGain "track gain". If you would leave _both_ in, you’d get a much too quiet playout.

**ReplayGain vs. `liq_amplify`**

If you have disabled AzuraCast’s built-in `liq_amplify` handler (by copying `12_remove_amplify` above), _you_ have the choice. But you _must_ define your own adjustment (start of third input box).

Example, to use your own tagged _ReplayGain Track Gain_ instead:

```
# Be sure to have ReplayGain or "liq_amplify" applied before crossing.
radio = amplify(1.,override="replaygain_track_gain",radio)
#radio = amplify(1.,override="liq_amplify",radio)
```

Pros & Cons:
- ReplayGain can be more exact (and prevent clipping) if pre-tagged with a tool like [`loudgain`](https://github.com/Moonbase59/loudgain).
- ReplayGain values _must exist as tags_ in your audio files
- `cue_file` (and thus the `autocue2:` protocol) will _always_ calculate a `liq_amplify` value _on the fly_, so it can be used with any audio file (even when not pre-tagged)
- `liq_amplify` has no means of clipping prevention or EBU-recommended -1 dB/LU margin. The value still resembles a _ReplayGain Track Gain_ closely, in most cases.
- _Both_ can be used with `autocue2:`.

Save and _Restart Broadcasting_.

**Note:** Liquidsoap recently introduced a _bultin_ `autocue:` protocol. I had to rename my `autocue:` protocol to `autocue2:` so it doesn’t clash with the other one.

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

Works, but the code is a little kludgy. I might want the help of the Liquidsoap devs to clean this up a little, especially the parts marked `TODO:` and `FIXME:`.

The protocol is invoked by prefixing a playlist or request with `autocue2:` like so:

```
radio = playlist(prefix="autocue2:", "/home/matthias/Musik/Playlists/Radio/Classic Rock.m3u")
```

It offers the following settings (defaults shown):

```
settings.protocol.autocue2 := "cue_file"
settings.protocol.autocue2.timeout := 60.
settings.protocol.autocue2.target := -18
settings.protocol.autocue2.silence := -42
settings.protocol.autocue2.overlay := -8
settings.protocol.autocue2.longtail := 15.0
settings.protocol.autocue2.overlay_longtail := -15
# The following can be overridden by the `liq_blankskip` annotation
# on a per-request or per-playlist basis
settings.protocol.autocue2.blankskip := false
```

You can _override_ the "blankskip" behaviour on a per-request or per-playlist basis using a special `liq_blankskip` annotation.

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

### AzuraCast Notes

- `media:` URIs will be resolved.
- Works well with smart crossfades. (But these are definitely not needed, see code below!)
- Even when `settings.protocol.autocue2.blankskip := true`, hidden jingles (those with a `jingle_mode="true"` annotation) will be _excluded_ from blank detection within the track, because the chance is too high that spoken text gets cut.
- User settings in the AzuraCast UI ("Edit Song") always "win" over the calculated values.
- Currently needs a patch to the AzuraCast-generated Liquidsoap code, see above.
- Currently generates lots of log data, for debugging. But hey, you can see what it does!

Typical log sample (level 3; level 4 gives much more details):

```
2024/03/25 14:50:50 [protocol.autocue2:3] Autocueing "annotate:title="Secret Love",artist="Bee Gees",duration="215.00",song_id="91d8c994c8741b1bb0716834a0849c4a",media_id="169415",playlist_id="226":media:Tagged/Bee Gees/Bee Gees - Their Greatest Hits_ The Record (2001 album, compilation, GB)/Bee Gees - Secret Love.mp3" ...

...

2024/03/25 14:50:51 [protocol.autocue2:3] Result: annotate:liq_blank_skipped="false",liq_amplify="5.11 dB",liq_loudness="-23.11 dB",liq_cross_duration="12.90",liq_longtail="false",liq_cue_out="209.10",liq_cue_in="0.00",liq_duration="209.10",duration="215.60",media_id="169415",playlist_id="226",title="Secret Love",artist="Bee Gees",song_id="91d8c994c8741b1bb0716834a0849c4a":/var/azuracast/stations/niteradio/media/Tagged/Bee Gees/Bee Gees - Their Greatest Hits_ The Record (2001 album, compilation, GB)/Bee Gees - Secret Love.mp3
```

I currently use these crossfade settings (third input box in AzuraCast; lots of debugging info here, could be much shorter):

```
# Be sure to have ReplayGain or "liq_amplify" applied before crossing.
#radio = amplify(1.,override="replaygain_track_gain",radio)
radio = amplify(1.,override="liq_amplify",radio)

def show_meta(m)
  label="show_meta"
  l = list.sort.natural(metadata.cover.remove(m))
  list.iter(fun(v) -> log.info(label=label, "#{v}"), l)
  nowplaying = ref(m["artist"] ^ " - " ^ m["title"])
  if m["artist"] == "" then
    if string.contains(substring=" - ", m["title"]) then
      let (a, t) = string.split.first(separator=" - ", m["title"])
      nowplaying := a ^ " - " ^ t
    end
  end
  log.important(label=label, "Now playing: #{nowplaying()}")
  if m["liq_amplify"] == "" then
    log.severe(label=label, "Warning: No liq_amplify found, expect loudness jumps!")
  end
  if m["liq_blank_skipped"] == "true" then
    log.severe(label=label, "Blank (silence) detected in track, ending early.")
  end
end

radio.on_metadata(show_meta)

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

        nd = float_of_string(default=0.1, list.assoc(default="0.1", "duration", new.metadata))
        xd = float_of_string(default=0.1, list.assoc(default="0.1", "liq_cross_duration", old.metadata))
        delay = max(0., xd - nd)
        log.important(label=label, "Cross/new/delay: #{xd} / #{nd} / #{delay} s")
        if (xd > nd) then
          log.severe(label=label, "Cross duration #{xd} s longer than next track (#{nd} s)!")
          log.severe(label=label, "Delaying fade-out & next track fade-in by #{delay} s.")
        end

        # If needed, delay BOTH fade-out and fade-in, to avoid dead air.
        # This ensures a better transition for jingles shorter than cross_duration.
        add(normalize=false, [fade.in(duration=.1, delay=delay, new.source), fade.out(duration=2.5, delay=delay, old.source)])
    end
end

radio = cross(duration=3.0, width=2.0, live_aware_crossfade, radio)
```

**Note:** The `cross` parameter `reconcile_duration=true` is new since _Liquidsoap 2.2.5+git@4a3770d7a_, and still under development. We hope this can eventually help automating things further (= less user coding).

If you have a long `liq_cross_duration` and a jingle following that is _shorter_ than the computed crossing duration, setting this to `true` ensures the jingle can be played correctly by effectively _shifting it to the right within the crossing duration window_, thus playing it _later than originally computed_ and ensuring correct playout for the following track.

We currently do this in above shown crossfading code. If this happens, a message will be logged:

```
2024/03/26 17:07:56 [live_aware_crossfade:3] Song → Jingle transition
2024/03/26 17:07:56 [live_aware_crossfade:2] Cross duration 5.9 s longer than next track (3.4 s)!
2024/03/26 17:07:56 [live_aware_crossfade:2] Delaying fade-out & next track fade-in by 2.5 s.
```

The 2.5 s fade-out helps tuning long overlap durations down, so they won’t distract the listener by overlaying songs and possibly jingles too long. The increased margin (8 dB/LU) helps making the smart crossfades sound much better.

~~Jingles should not be shorter than the duration specified in `cross`.~~

