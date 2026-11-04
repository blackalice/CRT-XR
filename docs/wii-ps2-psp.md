# Wii, PlayStation 2 and PSP (experimental)

Three consoles beyond GameCube, each behind a development opt-in like GameCube's
(see `gamecube-integration.md`). Without the opt-in a console stays out of
discovery, its folder names stay unsupported, and its settings do not appear.

| Console | Opt-in | Core | Pinned source |
|---|---|---|---|
| Wii | `CRT_XR_EXPERIMENTAL_GAMECUBE=1` (shared) | Dolphin, the GameCube build | libretro/dolphin `b93001e` |
| PlayStation 2 | `CRT_XR_EXPERIMENTAL_PS2=1` | LRPS2 (`pcsx2_libretro.so`) | libretro/ps2 `88098c4` + `lrps2-image-maps.patch` |
| PSP | `CRT_XR_EXPERIMENTAL_PSP=1` | PPSSPP (`ppsspp_libretro.so`) | hrydgard/ppsspp `v1.20.4` |

Builds: `scripts/build-lrps2-deck.py` (in the Dolphin image) and
`scripts/build-ppsspp-deck.py` (in `Dockerfile.ppsspp`). Each archives its source
in `cores/sources/` and records binary, source and patch hashes in
`third_party/cores/*-test-build.json`. Linux (Steam Deck) only for now.

## Discovery

- **Wii:** ISO, RVZ, WIA and WBFS images whose header carries the Wii magic (RVZ/WIA
  must also declare a Wii disc). GameCube images are unaffected.
- **PS2:** ISO images and cue sheets whose `SYSTEM.CNF` boots with `BOOT2`; CHDs in a
  PS2 folder. PS1 discs keep their own detection.
- **PSP:** ISOs whose volume names `PSP GAME`, `.cso`, and `.pbp` eboots that are not
  PS1 ones. 7z archives are not opened: extract them first.

## Runtime

- **Wii** uses a Wii Remote with Classic Controller in port 1 and shares the
  GameCube option definitions (stored per console). Widescreen stays off for the 4:3 TV.
- **PS2** runs OpenGL at native resolution with fast boot and MTVU. It needs a real
  BIOS in the bios folder; the first one listed in the registry that is present is
  staged to `pcsx2/bios` and chosen through `pcsx2_bios`. Port 1 must be
  `RETRO_DEVICE_JOYPAD`: LRPS2 leaves the port empty for any other device.
- **PSP** runs OpenGL at 480x272, uncropped, with no frame duplication. Its assets are
  staged from `core-data/ppsspp/PPSSPP`.
- LRPS2 and PPSSPP both destroy their GL context before unloading the game
  (registry `context_first`, as RetroArch orders it); LRPS2 otherwise hangs on close.
- PPSSPP links libstdc++ statically and exports only `retro_*`: the launcher's
  `LD_PRELOAD` of the system libstdc++ otherwise breaks it.
- LRPS2's recompilers need their memory within 2 GB of the core. When no hole near
  the core is free, the local patch maps it inside the core's own `.bss` and logs
  a warning; `CRT_XR_LRPS2_IMAGE_MAPS=1` forces that path for testing.
- Cores' warnings and errors also go to `~/.local/state/crt_xr/core.log`.

## Testing

`tests/core_runtime.gd` boots any console's real core with a caller-supplied game in
an isolated folder (several games with `;`, `CRT_XR_TEST_PACE=1` for real-time
pacing). Deck results, 4 November 2026, room at 1080p SBS: Brawl, Gran Turismo PSP,
GT4, Burnout 2 and Burnout 3 all play at full speed. Step time p50 is 4 ms (Brawl),
1.5 ms (PSP) and 6-9 ms (PS2). PS2 still shows uneven frame pacing and occasional
audio dropouts.
