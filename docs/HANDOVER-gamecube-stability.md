# Handover: GameCube / Dreamcast stability on the Steam Deck

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
