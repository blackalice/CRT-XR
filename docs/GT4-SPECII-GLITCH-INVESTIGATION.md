# GT4 Spec II picture glitches — 16 November 2026

Reported: letters sometimes disappear, the picture sometimes flashes. Game:
Gran Turismo 4 Spec II v1.10 (xdelta of the NTSC-U Online Public Beta,
SCUS-97436), on LRPS2 / "ParaLLEl PS2 v2.0.0-444c3e5", OpenGL, native
resolution, MTVU on (`scripts/emulation/core_registry.gd`).

Status: static investigation only. No ISO or Deck access from this session
(192.168.1.6:22 unreachable from the VM), so nothing below is confirmed at
runtime. Two candidate causes, one per symptom, plus the tests that separate them.

## 1. Missing letters → VU1 clamping (known GT4 issue)

Upstream PCSX2 knows this one: every GT4 entry in GameIndex.yaml, including
`SCUS-97436 Gran Turismo 4 [Online Public Beta]`, carries
`clampModes: vuClampMode: 2 # Text in GT mode works.` The PCSX2 forum thread
"Gran Turismo 4 - text issues" describes missing pit/gap/"Ready" text that only
VU clamping "Extra" fixed.

LRPS2 applies it automatically (`VMManager::ApplyGameFixes` →
`GameDatabase_ApplyGameFixes`, `EnableGameFixes` defaults true) **only if the
disc serial read from SYSTEM.CNF is in the database**. Lookup is by serial, not
CRC, so Spec II's new CRC (4CE521F2) does not matter by itself; a changed boot
ELF name would. Unverified because:

- the app drops core INFO logs (`LibretroHost::log` keeps WARN+), so the
  `(GameDB) Changing VU1 clamp mode [mode=2]` line never reaches core.log;
- the ISO isn't reachable from here.

Check on the Deck: `isoinfo -i "Gran Turismo 4 Spec II v1.10.iso" -x '/SYSTEM.CNF;1'`
— expect `BOOT2 = cdrom0:\SCUS_974.36;1`. If it differs, the clamp (and the
blending/HPO fixes) are not being applied: fix by mapping the serial in our
GameIndex (core option `pcsx2_use_external_gameindex` + `<system>/resources/GameIndex.yaml`)
or a local DB patch like `lrps2-recommended-blending.patch`.

## 2. Flashing → this core's render-target budget (new to libretro/ps2)

core.log has, during the two GT4 sessions of 6 Nov, both at race start:

    14:05:05 WARN GS: targets still over budget after dropping what could be dropped (8 MB against 8 MB).
    14:18:26 WARN GS: targets still over budget ... (8 MB against 8 MB).

`GSTextureCache::EnforceTargetBudget` (not in upstream PCSX2) caps render
targets at `VM_SIZE × scale² × TARGET_LIVE_SETS` = 4 MB × 1 × 2 = **8 MB** at
native, and evicts every target idle ≥2 frames (`GSTargetBudget.c`,
`GS_TARGET_LIVE_AGE 1`). "Still over" means everything evictable was evicted
and the live set alone exceeds 8 MB. Upstream keeps targets 60 frames and its
own comment lists games that flicker on scene transitions when targets die
early (Xenosaga 2, FFX). Evicted targets are written back to GS memory under
the default Accurate download mode (`DropTarget`), but only the pages
`DropKeepsPage` keeps; anything reformatted, partially overlapped or
re-read in a different format can come back stale — a plausible source of
one-frame flashes and of the blue patch noted in GT4-DISPLAY-INVESTIGATION.md.

Also relevant: the PCSX2 thread "Gran Turismo 4 graphical bugs (solved)"
reports random flashes before/after races on the OpenGL renderer that went away
on Direct3D. We build with `-DUSE_VULKAN=OFF`, so OpenGL is the only HW option.

## Tests that separate the causes (in order of cost)

1. **SYSTEM.CNF serial** (above). Settles whether cause 1 is live.
2. **Log GameDB lines**: let `LibretroHost::log` keep INFO lines starting
   `(GameDB)` / `[GameDB]`. Cheap, permanent diagnostic value for every PS2 game.
3. **Software renderer A/B**: run the same menu/race with `pcsx2_renderer`
   = `Software (SW)`. Glitches gone → HW texture cache (cause 2 or GL);
   letters still missing → VU/EE (cause 1). Expect lower speed; it's a probe only.
4. **Budget A/B**: core build with `TARGET_LIVE_SETS` 2 → 8 (32 MB at native,
   negligible on the Deck). If the flashes and the WARN line go, ship it as
   `cores/sources/lrps2-target-budget.patch` and report upstream.

## Test build prepared (16 Nov, uncommitted)

- `native/emulation/libretro_host.cpp`: INFO lines whose format starts
  `(GameDB)` or `[GameDB]` now also go to core.log, marked INFO. The next GT4
  launch logs `[GameDB] Serial: "..."` and each fix applied (look for
  `(GameDB) Changing VU1 clamp mode [mode=2]`). Needs the extension rebuilt
  (`scripts/build-emulation.sh`) to take effect.
- `scripts/core-patches/lrps2-target-budget.patch`: `TARGET_LIVE_SETS` 2 → 8.
  Built with `scripts/build-lrps2-deck.py` in the Dolphin image (Ubuntu 22.04,
  g++-12): `cores/pcsx2_libretro.so` sha256 `7f3f3be6…`, recorded in
  `cores/` and `third_party/cores/lrps2-test-build.json`. Source archive
  unchanged (same tar content; the original archive and its hash were kept).
  The previous core and record are in `build/lrps2-before-target-budget/` for
  an A/B on the same race.

What to look for on the Deck: the over-budget WARN gone from core.log at race
start, and whether the flashes go with it. If they persist with the new core,
cause 2 is ruled out and the software-renderer A/B is next.
