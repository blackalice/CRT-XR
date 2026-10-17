# TV audio

Settings → Audio → TV sound contains the game sound controls. Up/down selects, left/right adjusts, A toggles, and Y resets the selected option. Preview sound works while the game stays paused.

| Option | Default | Behaviour |
|---|---|---|
| Sound mode | TV in room | Original bypasses effects. TV speakers adds EQ and narrower stereo. TV in room adds reflections and head-relative panning. |
| Room amount | 18% | Adjustable from 0–25%; short, damped bedroom reflections. |
| Speaker character | 15% | Adjustable from 0–100%; reduces deep bass/high treble and narrows the original stereo image. |
| Directional strength | 80% | Adjustable from 0–100%; gentle left/right movement relative to the TV. Zero disables it. |

The TV's position and the view orientation drive stereo panning. Turning right puts the television towards the left ear. Recenter restores the matching visual/audio reference. Placement changes also update the sound direction. This is stereo panning rather than HRTF/binaural audio; there is no simulated elevation, rear filtering or Doppler. Volume does not fall as you adjust the viewing distance.

One existing emulator stream feeds one application-specific audio bus, shared by both eyes. Native Godot EQ6, StereoEnhance (without its delay/surround features), Panner and Reverb run on existing audio blocks. Original mode routes straight to Master. Effects at zero are disabled. The direct signal stays undelayed; only quiet reflections use a 12 ms predelay. Existing generator size, input preview and emulation timing remain unchanged. Reverb memory is cleared on pause/audio restart/game switch and when enabling/disabling the room effect so old sound cannot reappear.

Audio options are stored in the global `audio` settings section. Per-game picture changes and existing named view/picture setups leave them alone. Reset all settings also resets audio. Preview sound plays the existing CC0 CRT clip through a separate short-lived playback source on the same selected bus, while the game remains paused. Bypassed controls are disabled with explanations. No extra 3D passes, room meshes or plugins are required.

The mouse cursor is hidden throughout SBS playback and menus, including the SBS startup prompt. Returning to mono restores it.

## TV power-on

Audio → TV sound also includes **TV power-on effect** (On by default), **Power-on sound volume** (60%), and **Preview TV power-on**. Preview closes the menu and replays the effect. Zero volume keeps the animation silent; switching the effect Off bypasses both picture and sound.

The first unobstructed view of the TV in each application session gets a 0.70-second tube warm-up: a dim centre line opens into the full picture. It waits until the startup menu and SBS curtain have closed. Ordinary menu visits, game changes and recentering do not replay it. The game begins/resumes immediately; animation never stalls the core or queues additional game audio. The effect uses the existing CRT shader and screen lights, then stops its controller processing. The `--capture` tooling option bypasses startup for stable comparisons.

The sound is a quiet 0.640-second, 48 kHz mono PCM excerpt of TRP's real CRT recording under CC0. It follows the TV's selected audio route. Source, editing details, hashes and the CC0 licence are in `third_party/audio/`, copied into exported builds as `licenses/audio/`. Preferences live in the global `atmosphere` section and stay independent of per-game picture settings.

`tests/tv_power_on.gd` checks first-reveal timing, immediate emulation, one-shot playback, preview, bypass, persistence and reset. `tests/tv_power_on_visual.gd` renders only a synthetic quad and checks a dark start, monotonic mean brightness and a normal final picture; it never includes the licensed TV model.

Validation: `tests/tv_audio.gd` checks routing, pose direction, bypass, defaults, persistence, UI and bus cleanup. Run it with a real display driver to check cursor hiding; the headless display cannot change cursor visibility. `tests/tv_audio_mixer.gd` uses a real audio driver, captures a diagnostic impulse after effects and mutes that process's Master output. It checks panning, reflection tails and bypass without emitting the diagnostic through speakers. Listening through the glasses remains necessary to tune subjective room strength.

Built-in effect documentation: [Reverb](https://docs.godotengine.org/en/4.5/classes/class_audioeffectreverb.html), [StereoEnhance](https://docs.godotengine.org/en/4.5/classes/class_audioeffectstereoenhance.html), [Panner](https://docs.godotengine.org/en/4.5/classes/class_audioeffectpanner.html).

## Music and web radio

Audio now has its own category, separate from Room lighting/materials. Music & radio offers a controller-friendly local MP3 browser (Music folder, drives and mounted SD cards), Play last MP3, radio URL entry, Play radio, Stop music, volume and album repeat. Music atmosphere controls reverb, direction and source position beside the TV. Radio URL entry currently requires a keyboard; ordinary playback and browsing work with a controller.

Music continues through pause/settings, game changes and stop-game actions. Game volume is independent (100% retains the existing -6 dB headroom); music defaults to 45%, 12% room reflections, 80% direction and 1.1 m left of the TV. Zero reverb/direction disables those effects. Position uses head-relative stereo panning, not HRTF. There is no added game audio buffering or rendering pass.

Local MP3 files up to 256 MiB load as compressed audio once. Only the current track is loaded; the previous stream is released before opening the next. Large files use additional memory and can take longer to open. Radio supports direct HTTP/HTTPS MP3 streams, up to five redirects, ICY metadata removal and a maximum 256 KiB encoded queue plus 0.75-second decoded mixer buffer. The decoder retains lookahead for fragmented MP3 frames and limits work per frame. Radio format changes, unavailable stations, unsupported AAC/HLS/playlists and disconnections stop cleanly with an explanation; Play radio retries. Radio never downloads an endless stream into memory. Station selection and local file path persist globally in the `music` section, along with levels/effects, but playback never starts automatically on application launch. Setup/picture presets leave music alone. Reset all stops music and restores defaults.

`tests/music.gd` checks pause independence, volumes, persistence, positioning, UI, decoder PCM quality, fragmented MP3s, bounded buffering, redirects, ICY metadata, invalid formats and disconnects against `tests/music_http_fixture.py` on localhost:18764. The fixture uses the existing ignored CC0 power-on preview MP3, never bundled user music. Run it with network access allowed for localhost. Subjective listening and real station compatibility still need review on the Deck.

## Albums and pause-menu playback

Folders are albums (MP3 files directly inside that folder; subfolders remain separately browsable). Play this album starts at its first track; selecting an individual song starts there and continues through the folder. Disc and track tags determine ordering, with natural filename ordering for untagged tracks. Tracks without a disc number are treated as disc 1; unnumbered tracks follow numbered tracks on the same disc. Repeat album replays the folder after its last track; Off stops at the end. Previous/Next stop at album boundaries unless repeat is enabled. A missing or invalid next file stops advancement with an error rather than looping silently.

The main home/pause menu offers Music & albums. While a source is selected it also shows title, artist, album, track count and elapsed/total time, plus Previous, Play/Pause, Next and Stop. Left/right moves between transport buttons; A activates; up/down returns to the regular menu actions. Local pause retains the current position. Stop followed by Play restarts the current song. Live radio has stop/reconnect rather than a buffered time-shift pause, and disables track skipping.

Read-only ID3v2.2/2.3/2.4 text frames and ID3v1.1 fallback cover title, artist, album, track and disc. Latin-1, UTF-8 and UTF-16 text are supported, including basic unsynchronisation handling. Parsing is bounded to 4 MiB tags, 256 frames and 4 KiB per text frame, and caches only small metadata dictionaries. Encrypted/compressed frames and artwork are ignored; unavailable metadata falls back to filename/folder. No files are retagged. Format references: [ID3v2.3](https://id3.org/id3v2.3.0), [ID3v2.4](https://id3.org/id3v2.4.0-structure).

`tests/music_albums.gd` covers metadata encodings/fallback, ordering, pause/resume, next/previous, end/repeat, menu controller transport and album browsing. `tests/music_album_visual.gd` captures only the menu viewport, excluding the licensed scene.

## Music panel, seeking and game-volume dip

Music occupies a separate tinted player panel in the main menu, with vector Previous/Play-Pause/Next/Stop icons, track metadata, an adjustable local-MP3 timeline and an album browser link. Hover tooltips name icons; the selected icon has an amber focus ring. Left/right moves between icons, while down exits directly to the menu row below and up selects the timeline. Left/right on the timeline seeks in 10-second steps; pointer users can click or drag to any position. Seeking while paused is retained and applied on resume. Live radio has no seek bar.

Audio → TV sound includes **Dip game during music** (Off by default) and **Game volume dip** (50% by default). This reduces the manually chosen game level multiplicatively while unpaused, non-muted music is playing. It uses a 150 ms fade down and 400 ms recovery, never changes the saved game volume, and adds no rendering passes or game-audio buffering. Stop, local pause, muted music or a radio disconnection restores the chosen game level. Preferences remain global and use the existing settings store.

## Ready-to-resume music

The last local track, its album queue and timeline position are restored on launch, with the compressed track prepared but its player stopped. Press Play to continue at that position; no sound is emitted during restoration, and game-volume dipping remains inactive. Radio restores its saved URL ready to connect, without connecting or starting audio automatically.

An independent atomic `user://music-resume.cfg` bookmark saves every five seconds, on seeking/pause/source changes, on focus loss and during settings-save/exit. Picture presets and per-game settings do not replace it. Missing removable media keeps the bookmark and displays recovery guidance; Play last MP3 retries the saved position after reconnecting the drive. Invalid positions fall back to zero and out-of-range positions clamp to the track. Existing last-file preferences migrate as ready at zero when no bookmark exists. Reset all clears the bookmark. Abrupt termination may lose up to five seconds of progress.

`tests/music_resume.gd` checks a fresh app restoration, silence, album identity, stored position, continuation, missing media, invalid data, reset and radio readiness.
