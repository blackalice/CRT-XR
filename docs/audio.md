# TV audio

Settings → Audio & Room → Audio contains four global options. A starts editing, left/right changes a value, A/B finishes, and Y restores only that option's default. The game remains paused in the menu; resume to listen.

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

Audio & Room → Audio also includes **TV power-on effect** (On by default), **Power-on sound volume** (60%), and **Preview TV power-on**. Preview closes the menu and replays the effect. Zero volume keeps the animation silent; switching the effect Off bypasses both picture and sound.

The first unobstructed view of the TV in each application session gets a 0.70-second tube warm-up: a dim centre line opens into the full picture. It waits until the startup menu and SBS curtain have closed. Ordinary menu visits, game changes and recentering do not replay it. The game begins/resumes immediately; animation never stalls the core or queues additional game audio. The effect uses the existing CRT shader and screen lights, then stops its controller processing. The `--capture` tooling option bypasses startup for stable comparisons.

The sound is a quiet 0.640-second, 48 kHz mono PCM excerpt of TRP's real CRT recording under CC0. It follows the TV's selected audio route. Source, editing details, hashes and the CC0 licence are in `third_party/audio/`, copied into exported builds as `licenses/audio/`. Preferences live in the global `atmosphere` section and stay independent of per-game picture settings.

`tests/tv_power_on.gd` checks first-reveal timing, immediate emulation, one-shot playback, preview, bypass, persistence and reset. `tests/tv_power_on_visual.gd` renders only a synthetic quad and checks a dark start, monotonic mean brightness and a normal final picture; it never includes the licensed TV model.

Validation: `tests/tv_audio.gd` checks routing, pose direction, bypass, defaults, persistence, UI and bus cleanup. Run it with a real display driver to check cursor hiding; the headless display cannot change cursor visibility. `tests/tv_audio_mixer.gd` uses a real audio driver, captures a diagnostic impulse after effects and mutes that process's Master output. It checks panning, reflection tails and bypass without emitting the diagnostic through speakers. Listening through the glasses remains necessary to tune subjective room strength.

Built-in effect documentation: [Reverb](https://docs.godotengine.org/en/4.5/classes/class_audioeffectreverb.html), [StereoEnhance](https://docs.godotengine.org/en/4.5/classes/class_audioeffectstereoenhance.html), [Panner](https://docs.godotengine.org/en/4.5/classes/class_audioeffectpanner.html).
