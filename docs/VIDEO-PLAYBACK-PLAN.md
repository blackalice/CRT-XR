# Video playback plan

Status, 23 October 2026: phases 1–4 and 6–7 implemented, plus subtitles,
interlaced video, library extras and the VCR (on-screen text, tape look and
mechanism sounds). Phases 1–4 run on the Deck (SteamOS 3.8.28,
system FFmpeg 7.1). Phase 5 (long-play acceptance in the glasses) is being
tested over time by the owner.

Since phase 4:
- **FFmpeg 8 (phase 6).** The decoder is compiled once per FFmpeg major, each in
  its own namespace against that major's headers (`third_party/ffmpeg-61` for 7.1,
  `ffmpeg-62` for 8.x); `video_backend.cpp` loads the newest the system has. Both
  pass the full native suite, including GPU decoding.
- **Windows (phase 7).** Library locations offers *Set up video playback*: it reads
  the directory of BtbN's LGPL release zip from its end, fetches only the five
  libraries by byte range (52 of 77 MB for 8.1), checks each CRC-32, installs them
  in the user folder and loads them without a restart. GitHub's file host refuses
  suffix ranges, so the size comes from a one-byte range first.
- **Interlaced video.** Field motion shows each field in turn at the field rate;
  Blend averages the fields. Both are settings; progressive video is untouched.
- **Subtitles.** Embedded text (SRT, ASS, mov_text, WebVTT) and picture (DVD, PGS,
  DVB) tracks, and `.srt` files beside the video, drawn into the picture before
  the CRT through a subtitle layer. Picture subtitles follow the picture shape.
  With subtitles on, seeks start up to 5 s early so a line already showing is
  read again. Picture subtitles have no test clip yet (FFmpeg cannot make one
  from text).
- **Library extras.** Continue watching (list section and library card), search
  across the video folder (keyboard or on-screen keys) and cached thumbnails made
  on a background thread.
- **The VCR.** Videos play as if from the recorder under the TV:
  - *On-screen text*: green PLAY, PAUSE, FF, REW and STOP in VCR OSD Mono, drawn
    into the picture through the subtitle layer so the CRT treats it like the
    programme. Pauses the menu causes are quiet: no text and no clunk.
  - *Tape look* (Off, VHS, Worn VHS): `shaders/vhs_tape.gdshader` runs on the
    decoded frame inside the same layer, before the composite pass. It softens and
    sharpens luma, smears and delays chroma, adds timebase wobble, grain, the
    head-switching tear and (worn) dropouts; seeks roll noise bars, and a worn
    tape's pause shivers. The VCR's text stays clean on top. Off costs nothing:
    the picture skips the layer whenever it has nothing to draw.
  - *Mechanism sounds*: clunks for play, pause, resume and stop and a looping
    FF/REW whir, synthesised by `scripts/make-vcr-sounds.py` (original, CC0).
  - The VCR prop's display shows the tape counter with a transport icon
    (play, pause, FF, REW).
  - Settings live in their own **Videos** category (Picture, VCR, Playback), and
    the tape look is also in the video's Start menu.
- **Fixes.** The video picture profile was saved as the global picture when
  per-game picture was off (the default); video-to-video switching; CRT effects
  hidden at 480 lines (240 is now the default).

Phase 4 on the Deck, from the release's own smoke test (10 s decoded flat out,
output 640x240):

| Source | Path | Speed | CPU per second of video |
|---|---|---|---|
| Brass Eye episode, H.264 854x480 | VA-API | 10.3x real time | 5% of one core |
| Brass Eye episode, H.264 854x480 | software | 39.1x | 6% |
| Test clip, H.264 1920x1080 | VA-API | 3.4x | 19% |
| Test clip, H.264 1920x1080 | software | 9.3x | 31% |

GPU decoding saves about 40% of the CPU at 1080p and little at DVD resolution;
both paths are well above real time. What remains at 1080p on the GPU path is
mostly copying full frames back and scaling them on the CPU; scaling on the GPU
(VA-API video processing) before the copy would cut that further.

Changes after the first Deck run:
- Video is drawn as 240 lines by default (one broadcast field) at 640 wide. At
  480 lines the scanline and mask effects fade out by design, because each line
  covers less than a screen pixel on the virtual tube; 480 stays as an option.
- Going from one video straight to another kept the test signal on the TV.
- The pause menu has a Now playing panel with a scrubbable timeline (the TV
  follows while paused), and an on-screen bar shows position while watching.
  Holding the D-pad scrubs.

Phase 4 as built: VA-API on Linux, D3D11VA on Windows, chosen through FFmpeg's
`get_format`. Frames are copied back once and scaled as before. AV1 uses FFmpeg's
own `av1` decoder on the GPU (dav1d has no GPU path). Software takes over when
the device or codec cannot be used, or when a GPU frame fails mid-stream. The
sound player starts only once decoded sound exists, so a slow GPU start never
runs the mixer dry. The setting is Videos → Playback → Hardware video decoding.

Development: `python tests/make_video_fixtures.py <ffmpeg>` makes the clips;
`crt-xr-video-test build/video-fixtures` (native) and `tests/video.gd` (Godot)
check them. On Windows, point `CRT_XR_FFMPEG_DIR` at a local FFmpeg 7.1 shared
build's `bin` folder; it is a development aid and is never packaged.

Play the user's own MP4 and MKV files on the virtual CRT, through the same picture
pipeline, screen light, glass and TV audio as games. High resolution is not a goal:
video is scaled to standard definition while decoding, which is both cheaper and
what the composite and beam passes are tuned for.

## Decisions

- **Steam Deck first** (lead platform). Windows follows as a separate phase.
- **Use the system FFmpeg on SteamOS; ship no codecs.** CRT XR loads the OS copy at
  runtime with `dlopen` and never links or bundles FFmpeg, so the package contains
  no patented decoders. Codec patent licensing stays with the OS vendor.
- **A native decoder in the existing GDExtension**, not a libretro core. The host in
  `native/emulation/libretro_host.cpp` has no hardware-render support, a core would
  always hand over full-resolution frames, and seeking/resume are awkward through
  the libretro API. The extension already hosts `RadioMP3Decoder`, so a
  `VideoDecoder` class sits naturally beside it.
- **Hardware decoding (VA-API) when available, software fallback.** Software decoding
  is fast enough on its own; VA-API mainly frees CPU for rendering and tracking.
- **Missing or incompatible FFmpeg hides the feature.** The Videos entry is shown
  only when the decoder loads; nothing else changes.
- **Opt-in, inside the game library.** No Home card and no default folder. A user
  picks a video folder in Library locations; only then does a Videos card appear,
  after the last console card.
- **Composite by default.** Video uses the auto composite mode, PAL or NTSC from
  the source's rate, like a broadcast or VHS feed.
- **Display styles for widescreen sources:** letterbox (default), 14:9, fill 4:3
  (centre crop) and stretch. The bars are part of the signal, not the frame.

## Deck findings (22 October 2026)

Read-only checks over SSH, SteamOS 3.8.28 (build 20260922.1), in Gaming Mode.

| Check | Result |
|---|---|
| System FFmpeg | 7.1.1: `libavcodec.so.61`, `libavformat.so.61`, `libavutil.so.59`, `libswscale.so.8`, `libswresample.so.5`, in the read-only OS image |
| Video decoders | H.264, HEVC, AV1 (dav1d and native), VP8, VP9, MPEG-2, MPEG-4 Part 2 |
| Audio decoders | AAC, AC-3, E-AC-3, DTS, TrueHD, Opus, Vorbis, FLAC, MP3 |
| Build | `--enable-gpl --enable-version3`, VA-API, Vulkan and DRM hwaccels |
| Library path | Shortcuts inherit Steam's `LD_LIBRARY_PATH`. Steam's folders hold `libavcodec` `.53`, `.58` and `.62` but not `.61`; the 32-bit copies cannot load into a 64-bit process anyway |
| Dependency resolution | With Steam's path and CRT XR's `libstdc++` preload, every dependency of all five libraries resolves to `/usr/lib`; none missing |
| `dlopen` in that environment | All five load; versions as above |
| 1080p H.264/AAC MP4, 10 s, scaled to 480 lines | Software 0.73 s (about 14x real time); VA-API 1.15 s |
| 1080p HEVC MKV, 10 s, scaled to 480 lines | Software 0.82 s (about 12x real time); VA-API 0.91 s |
| VA-API | `radeonsi_drv_video.so` initialised for both codecs with no fallback warnings |

The clips were synthetic (`testsrc2`), which decode more easily than film. VA-API
times include copying every 1080p frame back from the GPU before scaling; the app
copies once per displayed frame. The scripts used are reproduced in phase 0 below.

## Architecture

```
file ─► VideoDecoder (native, worker thread)
          demux ─► decode (VA-API or software) ─► scale to ≤480 lines, RGBA
                                               └► resample audio to 48 kHz stereo float
        │ ring of ~4 frames + audio ring
        ▼
VideoSession (GDScript, same signals as EmulationSession)
  content_changed(texture) ─► picture.set_source(texture, true)
  frame_presented(image)   ─► screen_light.set_image, picture.frame_presented
  audio ─► AudioStreamGenerator on the TV audio bus (tv_audio.gd)
```

### Native: `VideoDecoder` (`native/emulation/video_decoder.{h,cpp}`)

- **Loading.** `dlopen` the exact sonames for one FFmpeg major (61 now, 62 when
  SteamOS moves to FFmpeg 8) and resolve the functions used into a table. FFmpeg
  struct layouts change between majors, so the decoding unit is compiled once per
  supported header set (`video_ffmpeg61.cpp`, `video_ffmpeg62.cpp` from one source)
  and the loader picks whichever major loads. Pinned FFmpeg headers (LGPL) are
  vendored under `native/emulation/third_party/ffmpeg-<major>/` with their notices;
  no FFmpeg binary or library is built or linked.
- **API to GDScript** (bound like `RadioMP3Decoder`):
  `available() -> bool`, `open(path, max_lines, hardware) -> Dictionary`
  (width, height, display aspect, frame rate, duration, audio tracks, codec names),
  `next_frame(clock_seconds) -> bool` plus `frame() -> PackedByteArray`,
  `push_audio(playback) -> int`, `seek(seconds)`, `set_audio_track(index)`,
  `set_paused(bool)`, `close()`, `last_error()`.
- **Worker thread** owns demuxing and decoding, keeps about four scaled frames and
  about half a second of audio ahead, and blocks when full. The main thread only
  copies a ready frame and audio; it never waits on decoding.
- **Scaling.** `sws_scale` to RGBA into a fixed 4:3 output frame at the target
  height (640x480 by default, 320x240 optional), applying the display style (see
  below). Display aspect includes anamorphic sample aspect ratios. 10-bit and HDR
  sources convert to 8-bit; no tone mapping (see risks).
- **Hardware path.** VA-API device on `/dev/dri/renderD128`; on any hardware error
  the file reopens in software and the session reports it once.
- **Audio.** `swr` resamples to 48 kHz stereo float, downmixing 5.1/7.1.

### GDScript: `VideoSession` (`scripts/video/video_session.gd`)

- Mirrors the parts of `scripts/emulation/emulation_session.gd` that `main.gd`
  already wires (`content_changed`, `frame_presented`, `status_changed` and an
  active flag), so the existing handlers in `main.gd` (around line 280) are reused.
  The texture is refilled in place exactly like `update_texture`.
- **Clock.** Audio is the master: position = samples consumed by the generator
  minus `AudioServer.get_output_latency()`. Frames due at or before the clock are
  shown and older ones dropped. Files without audio use a monotonic wall clock.
- **Signal mode.** The video picture profile defaults to the auto composite mode
  (`MODES[3]` in `picture_pipeline.gd`), so video looks like a broadcast or VHS
  feed rather than a clean RGB source. `picture.source_rate` drives that mode,
  which treats rates under 55 as PAL. Video rates are frame rates, so pass the
  field rate instead: 25 and 50 fps → 50 (PAL); 23.976, 24, 29.97, 30 and 60 fps
  → 60 (NTSC). The user can still pick RGB or a fixed standard in the video
  profile.
- **Exclusivity.** One programme source at a time. Starting a video auto-saves
  and unloads the running game (as switching games does today) and pauses music;
  the test pattern is hidden the same way `game_changed` hides it.
- **Audio routing.** Its own generator player on the TV bus created by
  `tv_audio.gd`, so speaker character, room and direction apply unchanged.

### Display styles

The tube is 4:3; most video files are 16:9 or wider. The decoder always produces
a 4:3 frame, so `picture.source_aspect` stays 4:3 and the existing fitting in
`picture_rect()` is unchanged. The style decides how the source fills that frame:

| Style | 16:9 source on the 4:3 tube | Done in the scaler as |
|---|---|---|
| **Letterbox** (default) | Whole picture, black bars top and bottom | Scale to full width, pad top/bottom |
| **14:9** | The broadcast compromise: thinner bars, slight trim at the sides | Crop sides to 14:9, scale to width, pad |
| **Fill 4:3** | Fills the tube, sides cut off (centre cut) | Crop sides to 4:3, scale to full frame |
| **Stretch** | Fills the tube, picture squeezed horizontally | Scale whole source to the full frame |

- Sources at 4:3 or narrower look the same in every style; wider sources (2.39:1)
  get deeper bars in letterbox and 14:9 and keep the same crop rule in fill 4:3.
- The bars are black at the signal's black level and are drawn into the frame
  before the composite pass, so bar edges pick up the same bleed and ringing as a
  real letterboxed broadcast, and the screen light sees the true picture.
- Cropping happens before scaling, so fill 4:3 and 14:9 also decode-scale less.
- Changing style reconfigures the scaler; the next frame shows it, with no reopen.
- **Where it is set:** a global default on the video Picture page, plus a
  per-file choice remembered with the resume position. During playback, Y cycles
  the style with a short on-screen label, and the pause panel lists it.
- Later, possibly: automatic detection of bars already burnt into the source
  (a 4:3 programme inside a 16:9 file), offered as a fifth "Zoom" style.

### Menus and controls (controller first)

- **Opt-in folder:** a new "Video folder" row in Library locations
  (`open_library_tools()` in `scripts/ui/menu_games.gd`), using the same
  folder picker as the ROM folder; stored next to `default_rom_dir` in the
  preferences `main.gd` already writes. There is no default folder, and choosing
  "Remove video folder" hides the feature again.
- **Library card:** in `library_items()`, a "Videos" card after the last console
  card and before "Library locations", shown only when a video folder is set and
  `VideoDecoder.available()`. Its caption follows the console cards' style (for
  example "YOUR VIDEOS") with a count of files. Note: `library_items()` currently
  returns early with only the setup card when no ROMs are found; that branch must
  still add the Videos card so a video-only user is not locked out.
- **Video list:** folder navigation modelled on the music browser
  (`scripts/ui/menu_videos.gd`). Lists `.mp4`, `.m4v` and `.mkv` with duration and
  resume point, probed on a worker thread and cached by the folder scan.
- **Playback:** A play/pause; D-pad left/right seek 10 s; D-pad up/down seek 60 s
  (not L/R, which would fire while the L+R+Start menu chord is pressed); Y cycles
  the display style; X cycles the audio track; B or Start opens a pause panel (Resume, Restart,
  Display style, Audio track, Stop). A brief timeline overlay on seek/pause reuses
  `scripts/ui/music_timeline.gd`.
- **Resume:** per file (path, size, modification time) in `user://video_resume.cfg`;
  "Continue from 42:10" on reopening. Saved on pause, stop, quit and every 30 s.
- **Settings** (as built: a **Videos** category, after Room, with Picture, VCR and
  Playback tabs; before a video folder is chosen it offers setup): picture shape,
  240/480 lines, interlacing, tape look, VCR text and sounds, subtitles, hardware
  decoding and the video folder. Picture preferences
  use a separate video profile, defaulting to auto composite, the way
  `change_game_preferences` keeps game and test-signal settings apart.

## Phases

0. **Capability spike — done.** Findings above. Keep the check as
   `tests/deck_video_capability.sh` (read-only) for future SteamOS releases.
1. **Native decoder, software, video only (Linux).** `VideoDecoder` with FFmpeg 61,
   worker thread, scaling into the 4:3 frame with all four display styles. A
   developer flag `--video <file>` in `main.gd` plays a
   file on the TV with a wall clock. Native test in the style of
   `native/emulation/tests/host_test.cpp` against generated fixtures.
2. **Audio and sync.** Audio ring, generator on the TV bus, audio-master clock,
   frame dropping, field-rate mapping for the signal mode, track selection.
3. **Menus, controls, resume and settings.** Video folder in Library locations,
   the Videos card, the video list, playback controls, per-file display style and
   resume, and the composite video profile, with GDScript tests in the style of
   `tests/music_resume.gd` and `tests/library_cards.gd`.
4. **VA-API.** Hardware path with automatic software fallback; CPU comparison on
   the Deck.
5. **Deck acceptance.** Gaming Mode through the normal shortcut: real MP4/MKV files
   (H.264/AAC, HEVC/AC-3, AV1/Opus, 25 and 23.976 fps, 5.1 audio, anamorphic SD),
   a 30-minute run with A/V drift under one frame, resume across restarts, and
   hiding the feature when FFmpeg is renamed away in a test environment.
6. **FFmpeg 62.** Second header set and loader entry, tested against Arch's
   FFmpeg 8 before SteamOS ships it.
7. **Windows (separate decision).** Options: Media Foundation (OS-licensed H.264
   and AAC; HEVC needs Microsoft's paid extension), or a bundled LGPL FFmpeg
   limited to royalty-free codecs, or both. Decide after the Deck version ships.

Each phase is deployable to the Deck; phases 1 and 2 stay behind the developer
flag until phase 3 adds the menu.

## Fixtures and tests

- `tests/make_video_fixtures.py` generates short clips with the developer's
  FFmpeg: colour bars with a burnt-in frame counter and a tone, at 25, 29.97 and
  23.976 fps, in H.264/AAC MP4, HEVC/AC-3 MKV and AV1/Opus MKV, plus an anamorphic
  720x576 16:9 clip, a 2.39:1 clip, a 4:3 clip and one without audio. Frames carry
  a border grid so cropping and bars can be measured. Fixtures are generated, not committed.
- Native test: open each fixture, check reported size, rate, duration and sample
  aspect, decode all frames, seek to known frames and read the counter back.
  For each display style, check the output is 4:3 and measure bar rows/columns
  (letterbox and 14:9 bar heights, no bars in fill 4:3 and stretch, the expected
  side crop), including the anamorphic and 2.39:1 fixtures.
- GDScript test: output height ≤ the setting, field-rate mapping, clock never moves
  backwards, resume round trip (position and display style), video profile
  defaults to auto composite, and the library: no Videos card without a folder,
  card after the last console when set, card present when the folder holds videos
  but no ROMs were found, hidden when `available()` is false.

## Packaging and licensing

- No FFmpeg binaries in any package. `THIRD_PARTY.md` and the vendored header
  notices record that the headers are LGPL and that playback uses the system
  libraries at runtime.
- `docs/CORE-DISTRIBUTION.md` gains a short section: CRT XR ships no video or audio
  decoders on Linux; codec availability depends on the OS. Revisit for Windows.
- User docs: a "Videos" section in `docs/emulation.md` (packaged as `PLAYING.md`)
  covering supported files, controls and resume.

## Risks

| Risk | Mitigation |
|---|---|
| SteamOS moves to FFmpeg 8 | Per-major builds (phase 6); otherwise the feature hides cleanly |
| A future Steam client puts a conflicting library first on the path | Phase 0 check rerun each SteamOS release; load failures hide the feature, never crash |
| HDR/10-bit HEVC looks washed out without tone mapping | Detect HDR transfer characteristics and show a one-line notice; tone mapping later if wanted |
| Variable frame rate files | Timestamps drive presentation, not a fixed period |
| Slow seeking in MKVs without an index | Seek on the worker thread; show the timeline while it lands |
| Interlaced SD sources (DVD rips) | Phase 1 shows frames as decoded; showing fields natively on the CRT is a natural later improvement |
| CPU contention with rendering | VA-API default; 240-line option; frame dropping before audio ever starves |

## Settled

- Videos live in the game library, opt-in through a chosen folder, after the
  consoles (22 October 2026).
- Video defaults to the composite look (22 October 2026).
- Widescreen display styles: letterbox, 14:9, fill 4:3, stretch (22 October 2026).

## Open questions

1. Is a 240-line option wanted, or is 480 the only sensible setting?
2. Subtitles: out of scope for now?
