# GameCube stability: core-fix continuation, 3 November 2026

The original handover below is historical. The owner clarified the symptoms:
crashes, freezes, restarts and stutters while switching games in **Gaming Mode**,
plus the loading screen naming the wrong game. They explicitly want the core
defects fixed, rather than a process-restart workaround.

## New findings

- The journal records another SIGTRAP at **15:01:53**, in the first TimeSplitters
  boot of a fresh process, PID 40323. The old "second boot only" diagnosis was
  incomplete. Subsequent supervised switches at 15:02 really did restart.
- **Save-state race reproduced:** `tests/gamecube_state_stress.gd` crashed the
  original core on its first immediate restore. The debugger caught the CPU
  executing an INT3 in invalidated JIT code while the frontend thread was inside
  `retro_unserialize`. Dolphin marked the frontend as the CPU thread before
  `RunOnCPUThread`, bypassing its synchronization. The fix uses
  `CPUThreadGuard` for measure/save/load, retaining the frontend's GL context
  while waiting for the real CPU, DSP and FIFO to stop. The corrected core passed
  300 immediate state roundtrips. Raw evidence is retained locally in
  `build/gamecube-state-crash-original.log` and `build/gamecube-state-pass-fixed.log`.
- **No-frame unload:** Dolphin defers its emulation thread until `retro_run`,
  but unload previously skipped `Starting`. Cancel its pending boot and restore
  per-game configuration and renderer-created timing registrations explicitly,
  reset `g_emuthread_launched` on unload, and prepare the libretro GPU loop only
  when it actually runs. Skip single-core exception-handler teardown if no
  emulation thread was launched. The host's forced first frame has been removed.
- **Reused-context initialization:** a zero-frame swap exposed another abort in
  `GLExtensions::Init`. Its version probe consumed an earlier GL error and
  incorrectly fell back to GL 2.1; querying `GL_EXTENSIONS` in the actual core
  context returned null and constructed an invalid string. Drain previous errors
  before querying the version, and handle a missing extension string. A tentative
  host context-rebinding change was disproven and removed.
- **Delayed launch race reproduced and fixed:** two choices during the channel
  animation could both continue and load. New choices now supersede older waits;
  previous-game frames cannot dismiss the selected game's card, and its text is
  redrawn immediately. `tests/game_launch_race.gd` failed before and passes after.
- `deck-switch-current.sh` unexpectedly copied an older PCK over the target and
  deleted test evidence. It now only switches to an existing release and refuses
  while the app is running.

## Implementation and verification

Core changes are preserved in `scripts/core-patches/dolphin-runtime.patch` against
the same pinned Dolphin revision. `build-dolphin-deck.py` accepts a clean checkout,
the previous Game Boy Player patch, or the exact runtime patch, and rejects other
source changes. It records the patch and binary hashes in the test manifest.
The process-restart implementation and its obsolete tests/helpers are removed.

All 56 native host checks, 29 session-wrapper checks, loading-card checks,
delayed-launch checks and lifecycle checks passed locally. The Deck now uses
`releases/gamecube-corefix-20261103`; `gamecube-restart-20261103` is preserved.
`scripts/deck-dev/test-gamecube-corefix.sh` tests zero/one/30-frame unloads in both
swap/reopen modes, 300 immediate save restores, then nine menu switches including
Continue, in one process.

Final Deck validation passed:

- 36 reloads: swap/reopen, zero/one/30 frames, three games twice through, with
  no internal assertion popups. Also eight cancelled zero-frame boots followed
  by real boot and save/restore checks in both modes.
- 300 immediate save/restore cycles on the final core.
- 39 menu launches across the mono, stereo, shader-comparison, mixed-console
  and full-resolution runs, including Continue. No crash, hang or process restart;
  loading paths/titles and actual game paths were checked. GameCube coverage:
  TimeSplitters, Gotcha Force, Mario Golf, Mario Party 4 and WarioWare.
- GameCube → Dreamcast (Tech Romancer) → NES (Mega Man 2) → GameCube, in one
  process. The first test assertion incorrectly demanded a loading card for NES;
  the corrected cartridge-aware test passed all four transitions.
- Continued a **copy** of the owner's existing pre-fix TimeSplitters automatic
  save. Tests used isolated XDG folders; original saves and settings were untouched.
- Six launches with two **1920×1080** eye renders. Five post-load 300-frame
  samples stayed at 38 ms or less; Gotcha Force's cold sample had one 58 ms frame.
  Gamescope clamps SSH test windows, so the test explicitly sizes the offscreen
  eye viewports; this verifies GPU load, not the glasses' physical handoff.

Raw final evidence is in `build/gc-final-evidence/`, including matching local/Deck
build hashes. Core SHA-256 starts `733a1f905b57`; native host `d8c7368dff1e`;
PCK `c0f9923f72a6`. The verified release was activated only after the app stopped.

## Remaining performance work

Crashes and restart behavior are distinct from occasional hitches. A later
TimeSplitters resume in the mono stress run still reached 256 ms. Do not claim
long gameplay or physical glasses/tracking acceptance from these boot tests.
Async ubershaders were worse in this sample: TimeSplitters had 19 frames over
50 ms on its cold run, with up to about 180 ms in GPU readback. Keep the existing
synchronous default; do not blindly enable hybrid shaders as a stutter fix.
The five-game synchronous stereo comparison had only one frame above 50 ms.

Option values are now confirmed from the pinned `Common/Options.cpp`:
`dolphin_shader_compilation_mode`: `0` synchronous, `1` synchronous ubershaders,
`2` asynchronous ubershaders, `3` skip rendering; `dolphin_wait_for_shaders`:
`enabled`/`disabled`. Frame pacing/audio and longer gameplay remain to profile.

### Follow-up profiling after commit `40f08f2`

The lifecycle/save-state/loading fixes above are committed as `40f08f2`.
Opt-in frame tracing now captures **every** `core.run_frame` in a catch-up batch,
plus audio submission, texture presentation, process-frame gaps and draw gaps.
Earlier sampling of `core.info()` after a process frame saw only the last native
step and could miss the slow step that caused the backlog. Trace writes happen
after play stops. Profiling runs use `gamecube-profile-20261103`, separate from
the active core-fix release, with isolated saves and the normal shader default.

Evidence is retained in `build/gc-profile-evidence/`:

- `room-real`: 12 menu launches (three games, four rounds), including Continue.
  The large TimeSplitters hitch reproduced at **258.44 ms**: 255.87 ms in the
  emulation callback, 254.17 ms in Dolphin, 27.96 ms in readback across eight
  native steps, and 0.50 ms in texture presentation. About 2.58 ms was outside
  emulation. The initial stall was a **125.88 ms** native step with no video or
  readback. Subsequent four/eight-step catch-up batches prolonged the freeze.
- `perf-real`: repeated the same 12-launch sequence under userspace CPU sampling.
  The worst gap was **260.80 ms**. Clock-correlated stacks identify the initial
  130.58 ms native step as PowerPC JIT compilation (`Jit64::Jit`, `DoJit`,
  instruction analysis/emission and register-cache work). The later 255.97 ms
  native batch sampled mostly CPU memory access: `ReadFromJit`, `WriteFromJit`,
  `TranslatePageAddress` and `WriteToHardware`. These are CPU samples, not exact
  percentages of wall time; unresolved samples remain. The separate cold Gotcha
  56.17 ms gap also contains JIT compilation. This is not evidence that every
  stutter in gameplay has the same cause.
- `continuous`: one fresh TimeSplitters launch, then 1,500 uninterrupted process
  frames, without switching or loading a save. It reproduced a **260.74 ms** gap
  with **256.55 ms** across eight native steps; texture presentation was 0.47 ms.
  Switching/restore is therefore **not required** for this particular hitch.

All 25 additional launches completed. Median process-frame gaps were 16.67 ms.
The trace regression and existing state-fix checks pass locally. Active Deck
release, user saves and performance settings were not changed by this profiling.

TimeSplitters' bundled `Sys/GameSettings/G3F.ini` explicitly requires `MMU=True`
and `PageTableFastmem=False`; its comment says the latter prevents a freeze at
the second loading screen. Do not disable those compatibility settings to make
the timing numbers look better. Likewise, keeping invalid JIT blocks after a
state load would reintroduce correctness risks, not fix compilation performance.

The next core work is to profile/optimize CPU compilation and the required MMU
path at this game transition. Independently, the frontend waits synchronously
for the native worker and can run eight steps before presenting or updating the
room; its scheduling amplifies the initial stall. A proper scheduling change
must preserve emulation/audio timing while allowing presentation to continue.
Neither that architectural change nor a JIT/MMU optimization has been implemented
or claimed as fixed here. GPU readback remains a separate measured cost,
especially with hybrid ubershaders; changing shader mode does not address the
CPU-bound hitch identified in these synchronous runs.

### Async presentation continuation, 3 November 2026

Implemented a GameCube-only asynchronous frame path. RetroCore owns a persistent
native dispatch thread; the existing core thread still owns Dolphin's GL context.
Normal room processing polls completion without waiting. Only one batch can be
outstanding, with at most four sequential emulated frames; its PCM is concatenated
in order and retained until Godot's audio queue accepts it. The latest completed
picture is presented on the main thread. No Godot objects are accessed by the
worker. Other systems retain their existing synchronous execution and preview.

All native host access joins outstanding work. Session pause, state operations,
reset and teardown explicitly drain the batch. Periodic SRAM reads run between
jobs. Elapsed time remains in the async accumulator rather than dropping the
backlog at eight frames. This preserves the emulated sequence, but cannot undo
already-audible silence during a CPU stall. Audio continuity/clock recovery is
still an acceptance item: the long TimeSplitters trace carried roughly 0.4�0.7 s
of wall-clock debt, even though the room stayed smooth. Do not describe this as
eliminating the game's CPU stall or proving glitch-free sound.

`CoreThread` now owns posted tasks instead of borrowing the caller's stack
function. Ready/wait synchronize publication of native output. Deterministic
`tests/emulation_async.gd` checks four 130 ms fixture stalls, nonblocking polling,
ordered PCM retention, rejection of a second job, save/restore/close ordering,
and the actual session callback's nonblocking behavior and retained wall time.

Verification/evidence:

- Linux and Windows native modules build. Native host checks, session-wrapper
  checks, state-fix checks and opt-in trace checks pass. Linux Godot requires
  `LD_PRELOAD=libstdc++.so.6`, matching the Deck runner; without it the stock
  Godot binary's C++ runtime caused a Snes9x reload crash in the local test.
- Isolated Deck release `gamecube-async-20261103`, copied independently (no hard
  links) from the profiling release. Active release and user saves are unchanged.
- Twelve menu launches across TimeSplitters, Gotcha Force and Mario Golf,
  including nine resumes, in one process. 3,588 measured play intervals:
  median 16.67 ms, worst room draw gap 17.09 ms, zero intervals over 50 ms.
  The largest native step was 125.08 ms; main-thread emulation work peaked at
  1.19 ms. Every completed batch includes each step's native timings.
- Two further 1,500-frame TimeSplitters samples: 2,998 measured play intervals,
  median 16.67 ms, worst room draw gap 17.10 ms, zero intervals over 50 ms.
  Largest native step 90.93 ms; main-thread emulation work peaked at 0.86 ms.
- The final native lifecycle suite also passed all 36 swap/reopen reloads
  (zero/one/30 frames) and 300 immediate state roundtrips.
- Final JSONL and logs in `build/gc-async-evidence/`. Async trace steps are
  **collected worker results**, not CPU work blocking that room interval. The
  `mode`, `pending` and `backlog_us` fields distinguish async records.
- These runs selected the real tracking path, but the driver reported
  `driver_disabled_or_disconnected`; they do not validate physical tracking.

CPU compilation/MMU code, required game compatibility options and shader mode
are unchanged. Remaining work is CPU-side optimization using targeted profiles,
audio continuity/clock recovery, and physical glasses/tracking acceptance.

### Audio clock and wider hardware-core continuation

The GameCube-only async notes above describe the first experiment. The current
session enables the nonblocking path for GameCube, Dreamcast and N64. VMU rendering
reads a cached completed LCD snapshot; it no longer calls the native host while
a job may be running. All other cores retain their original path.

With a real audio device, consumed generator samples now pace emulation. The
wall-clock accumulator is used only without an audio device (including headless
tests). An underrun is elapsed silence, not a debt that should make the console
run ahead indefinitely. The generator pauses briefly to refill before audio
resumes. PCM is still retained until submission succeeds, and emulated frames
remain sequential. Work batches remain capped at four frames independently of
the audio reserve. The reserve is eight nominal frames, capped by the generator's
actual capacity; at 60 Hz this is about 133 ms of queued sound. This trades audio
latency for resilience to measured CPU stalls and is not a low-latency mode.
The configured generator length remains 0.10 s; Godot rounds its actual capacity.

Profiling now includes execution clock, queue depth, priming state, underrun
counts and recovery counts. The initial wall-clock rebase and short-buffer
experiments produced repeated underruns and were superseded by audio pacing.
Keep those experimental traces separate from final evidence.

Synchronous hardware baselines on the Deck, with fresh and resumed boots:
F-Zero X reached a 178.40 ms process gap, GoldenEye 62.18 ms and Tech Romancer
51.22 ms. N64 dropped audio batches in both tested games. These measurements
justify testing the async path on those cores; they are attract/boot sequences,
not representative long interactive gameplay.

`profile-hardware.sh` reproduces those six launches in isolated XDG directories.
Evidence is in `build/gc-audio-evidence/`; isolated final release
`hardware-async-20261103` does not change `current` or the owner's saves. VMU
snapshot/display checks and async lifecycle checks cover the new cached path.

Final validation on the eight-frame audio reserve:

- TimeSplitters: 1,500 process frames (25 s of sampled play), worst room draw
  gap 17.02 ms. Native CPU step still reached 89.69 ms. During sampled play,
  underrun callbacks increased by 13, grouped into two refill recoveries, versus
  114 callbacks in the original same-length async wall-clock baseline. Sound is
  not claimed uninterrupted. The audio-clock path carries no wall-clock debt.
- Six more hardware-core launches (three fresh, three resumed), 600 process
  frames per phase. Worst process gaps: Tech Romancer 17.22 ms, GoldenEye
  20.86 ms, F-Zero X 21.57 ms; zero gaps above 50 ms and zero dropped audio
  batches. F-Zero still had a 113.14 ms native step on its worker. The earlier
  synchronous baseline used 900 process frames per phase; compare workloads
  with that duration difference in mind.
- Async fixture/session tests, the VMU snapshot/display tests, existing session
  wrapper tests and lifecycle state-fix checks all pass. The source exports
  through the Windows editor and runs with the unchanged native module built
  for both platforms in the preceding continuation. Headless display tests
  still print resource-leak diagnostics at exit; assertions pass.
- Final logs/JSONL and `hardware-comparison.json` are in
  `build/gc-audio-evidence/`; `deck-hashes.txt` records the tested PCK/native
  hashes and confirms `current` is still `gamecube-corefix-20261103`.

Long interactive play, listening/headset acceptance, physical tracking and CPU
JIT/MMU optimization remain separate follow-ups. Avoid describing audio pacing
as a fix for Dolphin's compilation or required memory-translation workload.

---

# Historical handover: GameCube / Dreamcast stability on the Steam Deck

Written 3 November 2026, branch `codex/gamecube-integration`. The owner's last
word: the build is **"still very buggy"**. No specifics were given after the last
fix, so the first job is to find out what is still going wrong (see "Start here").

## Where things stand

Deck `~/Applications/CRT-XR/current` points at `releases/gamecube-restart-20261103`.
Rollbacks, newest first: `gamecube-hardened-20261103`, `gamecube-native-20261103`,
`gamecube-test-20261103`. GameCube is on in these builds because `crt-xr.x86_64`
exports `CRT_XR_EXPERIMENTAL_GAMECUBE=1` (the standard export does not do this).

Commits this session, oldest first:

| Commit | What |
|---|---|
| `2ae9480` | State-machine fixes from the review table (failed core stays stopped, run-ahead no longer overwritten, loading-card timeout, startup guards, video/music/native edge cases) |
| `6d60ed2` | Video has its own pause-restore value (`video_was_paused_before_menu`) |
| `588b10b` | Native `close_game` runs one frame before unloading a hardware core; GameCube/Dreamcast use the loading card |
| `b66d2e4` | Fresh process for every GameCube game after the first; boot waits for the channel static |

## What was found

1. **Unloading Dolphin before it has run a frame corrupts the process.** The next
   `load_game` crashes (SIGSEGV inside `retro_load_game`). Deterministic in
   `tests/gamecube_reload.gd` with `CRT_XR_GC_FRAMES=0`; one frame is enough to avoid
   it. Typical trigger: load a game while the menu is open (the game is paused and has
   never run), then pick another. Fixed in `native/emulation/libretro_host.cpp`
   (`ran_frame`).
2. **Dolphin crashes while booting when started a second time in one process.**
   Signature: kernel `traps: CPU thread[...] trap int3`, SIGTRAP, right after
   `OGLConfig.cpp ... Video Info` and before any `DVDRead` line; the app then hangs
   until killed. Seen at 12:52 and 14:05 (GC → GC after real play) and 14:36 (GC → DC →
   NES → GC). It did **not** reproduce in the in-process stress tests (18 menu-launched
   switches passed), so it is timing/state dependent. **Not root-caused.** The
   workaround is `restart_into()` in `scripts/main.gd`: once `emulator.cores_used`
   contains `dolphin`, any further GameCube game starts a new process.
3. **The channel-change static** (`tv_effects`, 0.45 s) froze because the blocking boot
   started ~50 ms in. `menu_games.launch_game` now waits 0.55 s first.
4. Hitches after boot (240-583 ms frames in the first 5 s) are mostly gone behind the
   loading card, which is held 3 s for GameCube (`LOADING_HOLD_MSEC`).

## The restart mechanism (needs real-world verification)

- App side: `main.gd` `needs_fresh_process()` / `restart_into()`; `menu_games.launch_game`
  calls it after the card is up and the old game is saved and stopped. The new process
  starts with `--rom <path> --rom-play [--rom-continue]`.
- If `CRT_XR_RESTART_FILE` is set, the app writes those arguments there and exits with
  code **86**. `steam-session.py` and `linux-session.py` relaunch on 86. Any other exit
  code (including a crash) passes straight through, so it cannot loop.
- With no supervisor the app relaunches itself from `/proc/self/cmdline`.
- `glasses-session.py` (Desktop-mode glasses) sets `CRT_XR_NO_SELF_RESTART=1`, so it
  still loads in-process and **can still hit crash 2**.
- Verified on the Deck with `tests/gamecube_restart.gd` (both modes) and a fake-app
  loop test. **Not verified through real Steam Gaming Mode.** Check: does the relaunch
  pass the SBS handoff without asking again, how long it takes, whether tracking/driver
  state survives, whether music or other state is lost.

## Start here

1. **Ask the owner what is still buggy** (symptom, which games, in which order, menu
   open or not). Then capture evidence straight after it happens:
   - `~/.local/state/crt_xr/godot-steam.log` (overwritten each launch)
   - `journalctl --since "-30min" | grep -E "traps:|segfault|terminated abnormally|CRT XR|\[Libretro\]"`
   - `coredumpctl list`. The dumps are root-only (`COREFILE inaccessible`), so no
     backtrace is available. Either get a root shell to read `/var/lib/systemd/coredump`,
     or run under gdb with `scripts/deck-dev/gdb-last-fault.py`.
2. Look for restart-specific problems first, since that is the newest and least tested
   code: a restart loop, a black screen after relaunch, the SBS prompt reappearing, a
   wrong resume state (`--rom-continue` uses `emulator.load_auto()`).
3. If Dolphin still crashes: the robust fix is to host Dolphin in a helper process
   (frames and audio over shared memory) so a crash only loses the game. Large job,
   but the restart workaround already shows in-process Dolphin is the weak point.

## Open items

- **Stutter in play** is untested territory: the logs show `Audio buffer full` and
  `Emulator cannot keep up with real time` during GameCube play. Dolphin options in
  `core_registry.gd` (`dolphin_efb_scale=1`, `cpu_core=1`, `dsp_hle`, `main_cpu_thread`,
  `call_back_audio_method=1`) were not tuned. `dolphin_shader_compilation_mode` and
  `dolphin_wait_for_shaders` exist in the core but their valid values could not be read
  offline; list them from a running core and test.
- The unlocked shared fields written by Dolphin's own threads (`video()`/`environment()`
  in `libretro_host.cpp`) are still unexamined; a thread-sanitizer run is needed.
- Not done from the original state-machine review: one function for the picture source
  (item 1), a menu page enum with back stack (item 2). Both are large refactors.
- `export-linux.ps1` does not include Dolphin. `scripts/deck-dev/assemble-gamecube.ps1`
  adds the core, `core-data/dolphin-emu`, licences and the launcher flag by hand.
  No Windows Dolphin core exists.
- PS1 zips use the older unpack path and were not re-tested after the loading-card
  change. Mega-CD (Sonic CD) needs its BIOS present; it failed only in an isolated test
  folder without one.

## Tools

Tests (run on the Deck with a display; none are in the exported pack, so load them with
`--script /tmp/x.gd` against a release's `crt-xr.pck`):

| Test | Purpose |
|---|---|
| `tests/state_fixes.gd` | Headless lifecycle checks (also runs on Windows with `build/crt-xr-probe.sfc`) |
| `tests/gamecube_switch.gd` | Many game switches in one process; prints load time, card frames, worst frame. `CRT_XR_GC_DIRECT=menu` uses the real menu path |
| `tests/gamecube_reload.gd` | Isolated core reopen/swap; `CRT_XR_GC_FRAMES=0` reproduces crash 1 |
| `tests/gamecube_restart.gd` | Restart path, supervised and self-relaunch |
| `tests/gamecube_runtime.gd` | Original single-game Dolphin check |

Helper scripts are in `scripts/deck-dev/` (`assemble-gamecube.ps1`, `deck-install.sh`,
`deck-newrel.sh`, `deck-switch-current.sh`, `deck-gc-*.sh`, `deck-logs.sh`,
`gdb-last-fault.py`, `wrapper-loop-test.py`). They hard-code the SSH control socket
`/tmp/retrocrt-deck-01a139ee.sock` and `deck@192.168.1.6`, and expect the repo at
`/mnt/d/git/XR-CRT` in WSL. See the `deck-ssh-deploy` memory for the SSH setup.

Typical cycle: rebuild natives in WSL (`bash scripts/build-emulation.sh linux`), run
`scripts/deck-dev/assemble-gamecube.ps1`, `deck-install.sh <tag> <dist dir>`, test,
then `deck-switch-current.sh <tag>` only when the app is not running.

## Gotchas learned the hard way

- Scripts written from Windows get CRLF; shell scripts for the Deck must be LF
  (`sed -i 's/\r$//'`). Python edits of repo files: open with `encoding='utf-8'` and
  keep each file's line endings.
- Never overwrite a release's `crt-xr.pck` in place if it is hard-linked (`cp -al`) or
  running: `rm` first, then copy.
- gdb stops on Dolphin's normal fastmem SIGSEGVs; it makes a crash look like it is in
  `retro_load_game`. Use `handle SIGSEGV nostop noprint pass`, or the Python hook.
- Godot reports `/proc` files as zero length (use `get_buffer`), and
  `get_string_from_utf8` stops at the first NUL (split the bytes yourself).
- `pkill -f` over SSH matches its own command line; use a `[c]rt-xr` style pattern.
- The app is rarely stopped on the Deck: check `pgrep -a crt-xr-engine` before touching
  `current`, and use an isolated `XDG_DATA_HOME` for tests so saves are untouched.
