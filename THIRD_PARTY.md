# Third-party components

## CRT shaders

* Timothy Lottes' `crt-lottes.glsl`, public domain. The tube shader adapts its
  Gaussian beam reconstruction and neighbouring-row sampling. The shared
  `crt_beam.gdshader` cache uses the same horizontal kernels.
* Viacheslav Slavinsky's `pal-singlepass.glsl`, Copyright 2016, BSD 2-Clause.
  The shared composite shader adapts its carrier modulation/demodulation,
  20-tap FIR filter and colour matrices. NTSC uses the supplied YIQ matrices
  with an NTSC carrier and line phase approximation.

Original sources, full notices and pinned provenance are in `third_party/shaders/`.
The export script copies them into `licenses/shaders/` alongside the application.

## Native dependencies

The app's emulator host dynamically loads an existing Libretro core. No console
BIOS, commercial ROMs or third-party game artwork are supplied.

* Godot C++ bindings, MIT license. Source commit:
  [e83fd090](https://github.com/godotengine/godot-cpp/tree/e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77).
  The bindings license is copied alongside the extension build.
* Snes9x, its own license. Source commit:
  [1bcc369e](https://github.com/snes9xgit/snes9x/tree/1bcc369e89f08243e0a462882fb1f3e42e51de3a).
  The complete license and referenced component licenses are copied into `cores/`
  and into the local Linux package. The source is fetched by a reproducible setup
  script; it is not copied into the application source tree.
* Libretro API header, MIT license, Copyright 2010–2018 The RetroArch team.
  Its full header notice is copied into `cores/libretro-header-LICENSE.txt`.

The generated diagnostic cartridge is an original, asset-free test program.
Its source generator, `tests/make_probe_rom.py`, is provided under CC0-1.0.
It is generated under ignored `build/` and is not automatically included in exports.
