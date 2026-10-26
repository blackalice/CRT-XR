# Nestopia boot background fix — 26 October 2026

On Steam Deck, opening Mega Man 3 (US) after earlier play crashed in
`Renderer::FilterNtsc::BlitType<unsigned int,32>`. An isolated probe reproduced
the same native crash without room rendering or input preview: load the ROM,
execute 120 frames, close the core, reopen, execute the first frame.

The pinned Nestopia revision `06a8949e0b3cf60e3a38a374b1426bf40fccb9a0`
leaves `Ppu::Output::bgColor` uninitialized in its constructor and reset.
The boot frame can complete without a palette write. `Machine::Execute`
copies this value into the renderer, whose NTSC filter uses it as a lookup
table index. Reused heap memory makes the missing initialization visible on
reopen even when the first load succeeds.

`scripts/core-patches/nestopia-boot-background.patch` initializes the value,
sets it from the actual palette on reset, and masks the backdrop index to
six bits at the NTSC filter boundary. The serialized state layout and core
identity remain unchanged.

Rebuild with Linux Python and GCC/Make:

```sh
python3 scripts/build-release-cores.py linux nestopia
python3 scripts/check-core-sources.py
```

The build applies the patch to a temporary extraction of the pinned source.
The original source archive, applied patch and their hashes are retained in
`cores/sources` and `cores/core-builds.json`, with tracked build evidence in
`third_party/cores/release-builds.json`.

`tests/nes_reopen.gd` exercises ten reloads, frame execution, save-state restore
and reset, with preview off or on (`-- --probe-preview`). Run it through an
installed Linux app with isolated `XDG_DATA_HOME`, `CRT_XR_NES_CORE` pointing
to the test binary and `CRT_XR_NES_ROM` pointing to a locally supplied game.
It never reads or writes the player's actual saves.

The patched Linux core passed both modes on the Steam Deck on 26 October:
ten open/run/restore/reset/close cycles per mode. The unpatched core crashed
on the first frame of the second load with preview off; the patched binary
SHA-256 is `4de818c05ec0376cebf436452c5040d461074146584b9dae6951b27aab2acc0b`.
