# Third-party notices

The root MIT license covers this project's original code and original modifications; it does not replace third-party licenses.

## proxy-audio-device

The HAL driver in `Vendor/` is derived from [briankendall/proxy-audio-device](https://github.com/briankendall/proxy-audio-device), revision `be390f7956858cac64640f7cdb8fe65d700ec37e`.
The upstream Unlicense is preserved in [Vendor/LICENSE](Vendor/LICENSE).

Local modifications include separate bundle/device identifiers, hardware-volume pass-through, a timed playback lease, configurable dB mapping, removal of automatic fallback routing, output-only stream configuration, and playback error reporting/retry.

## Apple sample code

Apple license and copyright notices remain in the individual files under `Vendor/proxyAudioDevice/PublicUtility/` and other applicable vendor files. Those files remain subject to their own notices.

## RME protocol reference

The implementation uses the [RME ADI-2 Remote MIDI protocol](https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip). This is an independent project, not an official RME product and not affiliated with or endorsed by RME or Apple.
