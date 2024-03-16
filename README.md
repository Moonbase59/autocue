# autocue
On-the-fly JSON song cue-in, cue-out, overlay, replaygain calculation for Liquidsoap, AzuraCast and other AutoDJ software.

Work in progress.

Requires Python3 and `ffmpeg` with the _ebur128_ filter.

## Command-line interface

```
usage: cue_file [-h]
                [-t {-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0}]
                [-s SILENCE] [-o OVERLAY] [-l LONGTAIL] [-x EXTRA] [-b] [-w]
                [-f]
                file

Return cue-in, cue-out, overlay and replaygain data for an audio file as JSON.
To be used with my Liquidsoap "autocue:" protocol.

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
- _liq_blank_skipped_ — flag to show that we have an early cue-out, caused by silence in the song
