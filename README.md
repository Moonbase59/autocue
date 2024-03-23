# autocue
On-the-fly JSON song cue-in, cue-out, overlay, replaygain calculation for Liquidsoap, AzuraCast and other AutoDJ software.

Work in progress.

Requires Python3 and `ffmpeg` with the _ebur128_ filter.

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
                        a track) (default: -40.0)
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

## Example

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
settings.protocol.autocue2.silence := -40
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
- Works well with smart crossfades.
- Even when `settings.protocol.autocue2.blankskip := true`, hidden jingles (those with a `jingle_mode="true"` annotation) will be _excluded_ from blank detection within the track, because the chance is too high that spoken text gets cut.
- User settings in the AzuraCast UI ("Edit Song") always "win" over the calculated values.
- Currently needs a patch to the AzuraCast-generated Liquidsoap code, see above.
- Currently generates lots of log data, for debugging. But hey, you can see what it does!

Typical log sample:

```
2024/03/16 13:39:05 [protocol.autocue2:3] /var/azuracast/stations/niteradio/media/Tagged/Dion, Céline/Dion, Céline - Let's Talk About Love/Dion, Céline - Let's Talk About Love.mp3
2024/03/16 13:39:05 [protocol.autocue2:3] ("song_id", "b61044493bcc39e3cbd6df2a1f451cf9")
2024/03/16 13:39:05 [protocol.autocue2:3] ("artist", "Céline Dion")
2024/03/16 13:39:05 [protocol.autocue2:3] ("title", "Let's Talk About Love")
2024/03/16 13:39:05 [protocol.autocue2:3] ("playlist_id", "226")
2024/03/16 13:39:05 [protocol.autocue2:3] ("media_id", "194809")
2024/03/16 13:39:05 [protocol.autocue2:3] ("duration", "312.30")
2024/03/16 13:39:05 [protocol.autocue2:3] ("liq_duration", "304.20")
2024/03/16 13:39:05 [protocol.autocue2:3] ("liq_cue_in", "0.00")
2024/03/16 13:39:05 [protocol.autocue2:3] ("liq_cue_out", "304.20")
2024/03/16 13:39:05 [protocol.autocue2:3] ("liq_longtail", "true")
2024/03/16 13:39:05 [protocol.autocue2:3] ("liq_cross_duration", "8.80")
2024/03/16 13:39:05 [protocol.autocue2:3] ("liq_loudness", "-12.17 dB")
2024/03/16 13:39:05 [protocol.autocue2:3] ("liq_amplify", "-5.83 dB")
2024/03/16 13:39:05 [protocol.autocue2:3] ("liq_blank_skipped", "true")
```

I currently use these crossfade settings:

```
def live_aware_crossfade(old, new) =
    if to_live() then
        # If going to the live show, play a simple sequence
        # fade out AutoDJ, do (almost) not fade in streamer
        sequence([fade.out(duration=2.5,old.source),fade.in(duration=0.1,new.source)])
    else
        # Otherwise, use a smart crossfade/overlap/segue
        log(label="crossfade", "Using custom crossfade")
        cross.smart(old, new, fade_in=0.1, fade_out=2.5, margin=8.)
    end
end

radio = cross(reconcile_duration=true, duration=3.0, width=2.0, live_aware_crossfade, radio)
```

**Note:** The option `reconcile_duration=true` is new since _Liquidsoap 2.2.5+git@4a3770d7a_.

If you have a long `liq_cross_duration` and a jingle following that is _shorter_ than the computed crossing duration, setting this to `true` ensures the jingle can be played correctly by effectively _shifting it to the right within the crossing duration window_, thus playing it _later than originally computed_ and ensuring correct playout for the following track.

The 2.5 s fade-out helps tuning long overlap durations down, so they won’t distract the listener by overlaying songs and possibly jingles too long. The increased margin (8 dB/LU) helps making the smart crossfades sound much better.

~~Jingles should not be shorter than the duration specified in `cross`.~~

