# CRT performance pass — 14 October 2026

Measured on the Steam Deck, Godot 4.5.1 Compatibility / Mesa 26.1.2, two
1920×1080 eyes. Tests use copies of the user's current preferences, leaving
the actual settings, ROM library, display layout and saves untouched.

## Finding and change

Close viewing increases the number of eye pixels covered by the tube. The
original beam filter ran eleven neighbouring texture fetches, picture grading
and Gaussian reconstruction at each covered pixel, independently in each eye.
Disabling that component in the initial close-view test saved about 3.6 ms.
Removing shadows had little effect, so lighting and shadows were retained.

The new `crt_beam.gdshader` computes the horizontal three-tap and five-tap
filters once in a shared viewport. Each source row has four horizontal samples
per source pixel (1024 wide for 256-wide input; 2048 for 512-wide input). Two
vertical bands hold the narrow/wide kernels. Each eye samples three cached rows,
then applies the original vertical Gaussian weights, derivative-based beam/mask
attenuation, effect strengths, glow, vignette and fitting guides.

The cache encodes its linear result with a gamma curve and 2× headroom before
writing to the Compatibility renderer's 8-bit target. This avoids clipping the
user's brightness/warmth before final beam reconstruction. It stops when paused,
redraws when an option changes, and is disabled when scanlines are zero.
The reference path remains accessible to tests through `shared_beam_enabled`.
There is no new quality setting or change to saved effect strengths.

## Deck results

The user's PAL settings included composite/artifacts at 1.0, brightness 1.3,
scanlines 0.35, mask 0.08, glow 0.1, glass 0.4 and curvature 0.7. The same
frozen game frame was used for each phase; composite noise/motion continued.
The game was paused to separate rendering cost from emulator CPU work.

| Distance | Reference GPU time | Shared filter GPU time | Reduction |
| --- | ---: | ---: | ---: |
| 3.4 m | 2.97 ms | 2.29 ms | 23% |
| 2.0 m | 5.98 ms | 3.85 ms | 36% |
| 1.2 m | 6.91 ms | 4.00 ms | 42% |

Each entry averages the medians of two alternating reference/shared phases,
120 measured frames after 24 warm-up frames per phase. GPU timestamps sum the
two eyes and active source/composite/beam viewports. VSync is disabled and the
resolution is verified by the test. These are rendering measurements, not
end-to-end input latency, battery life or a guaranteed gameplay FPS increase.
Head tracking, Gamescope and compositor cost are not isolated by this test.

## Appearance and regression checks

`tests/beam_fidelity.gd` compares original, asset-free ramps, sharp black/white
edges and dark tones, with maximum scanline/mask/glow strengths, brightness 1.3,
and beam sharpness 1, 3 and 8 in RGB and PAL. On Deck the user's sharpness-3 PAL
case has RGB-channel RMSE about 0.001 (0–1 scale), with maximum sampled-channel
difference 2/255. The cache is an approximation, with slightly larger edge
differences at the extreme sharpness settings. It does not change the chosen
effect strength or bake a screen-space mask that could shimmer between eyes.

The test also verifies pause stops cache redraw and a source update appears in
the same rendered frame. Deck controller-menu and picture-pipeline regressions
pass. The licensed TV model and game content are not exported as image references
for visual inspection; image fidelity tests use original diagnostic content.

`tests/crt_performance.gd` reproduces the alternating comparison. Run it only
with isolated user data, since application shutdown saves preferences. The Deck
scripts and complete baseline/comparison logs are retained under ignored build
artifacts, alongside a backup of the original preferences on the Deck.

## Second pass: live emulation and real tracking

Live SNES execution and the real XRLinuxDriver were measured with the glasses
connected, full-resolution eye viewports and a 60 Hz frame cap. At both 2.64 m
and 1.2 m, every measured phase had 180 valid tracking frames, no emulator
catch-up events and no audio overflows. Median frame intervals were 16.66 ms,
with 95th percentiles around 16.70 ms. Input preview cost roughly 2–2.4 ms per
preview on this cartridge; it remains enabled to preserve responsiveness.
These short runs cover the loaded game's early sequence, not every gameplay
scene. Loading/warm-up can emit pacing warnings outside the measured phases.

The second pass keeps the original glow sampling and reduces arithmetic:

* The 20-tap composite filter samples exactly a quarter carrier cycle apart.
  Rotating the sine/cosine carrier between taps replaces repeated trigonometry.
  PAL alternation and chroma phase noise use the same equations and controls.
* RGB/YIQ conversion, hue rotation and saturation are composed into one matrix
  when settings change. Pixel grading still uses the same contrast clamp,
  white balance, gamma and brightness operations in the same order.
* The unused test-signal viewport and animation stop during games and resume
  when returning to the test signal. Diagnostic text updates at 10 Hz when
  visible; camera tracking and game input retain their frame-by-frame updates.

Alternating pass-1/pass-2 rendering comparisons, with a frozen source and VSync
disabled as above, reduced the close-view GPU median from about 3.97 to 3.59 ms
(9.5% beyond the first pass). The warm normal-distance pair at 2.64 m was about
2.96 to 2.71 ms (8.6%); the first reference phase had a larger warm-up outlier
and is not used for that percentage. Timings exclude the XR compositor's own
work; the test does not change the display layout or require SBS switching.

`tests/composite_fidelity.gd` compares against the retained original decoder
at multiple PAL/NTSC phases with the user's strong interference/noise settings.
PC and Deck comparisons differ by at most 1/255 in a channel.
`tests/colour_fidelity.gd` compares the original grading against the composed
matrix at the user's settings and range extremes; PC and Deck 8-bit output matches
exactly. Reference fixtures retain the original notices.

A shared glow prototype was tested but rejected: it changed some high-contrast
edge pixels beyond the chosen fidelity limit. It is not in the shipped build.
The separate screen-to-cabinet light spill was disabled during this pass.
It has since been rebuilt locally; see [Screen light](screen-light.md) for
its separate tests and desktop-only measurements.

The second pass is installed as `performance2-crt-20261014` and selected by the
existing CRT XR Steam entry. Its package hash was verified and the user's
global and per-game preferences were unchanged after profiling. The previous
`performance-crt-20261014` installation is retained. The final short live run
again held 60 Hz with valid tracking and no measured-phase audio/catch-up events.
