# Shader provenance

Adapted from libretro/glsl-shaders commit
`148ce728155232a6b63be772c1810bd84728f359`:

* [crt-lottes.glsl](https://github.com/libretro/glsl-shaders/blob/148ce728155232a6b63be772c1810bd84728f359/crt/shaders/crt-lottes.glsl)
  — Timothy Lottes, public domain; the original notice remains in the file.
* [pal-singlepass.glsl](https://github.com/libretro/glsl-shaders/blob/148ce728155232a6b63be772c1810bd84728f359/pal/shaders/pal-singlepass.glsl)
  — Viacheslav Slavinsky, Copyright 2016, BSD 2-Clause. Full license in the
  source and `PAL-LICENSE.txt`.

These files preserve the upstream implementations as references. Runtime Godot
adaptations are `shaders/crt.gdshader`, `shaders/crt_beam.gdshader` and
`shaders/analog_signal.gdshader`.
The latter retains the complete BSD notice. Both Compatibility shaders operate
on the game image before each eye's curved surface is rendered. They do not
filter the room or the combined SBS frame.

SHA-256 of the unchanged upstream files:

* `crt-lottes.glsl`: `699a947fc2744eb7e2dc4adb2c08a8b74e31685baa77cbc1face9593106b57ef`.
* `pal-singlepass.glsl`: `f8a5e4cb97cfb2166631c62b362ecfc15bf1b3d903b554c19be617b50838f01c`.

Changes include safe full-frame fitting, Godot colour-space handling, beam/mask
minification fades, optional controls, a shared 1024-wide composite pass, and
an NTSC approximation using the original YIQ conversion matrices. This is not
a complete port of the upstream presets or an electrically calibrated SNES
video encoder. No history buffer, persistence or extra emulation frame is used.
