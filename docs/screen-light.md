# Screen light: local implementation and validation

The previous effect was an additive material pass; it could lift dark plastic
independently of its albedo and initially resembled the game image overlaid on
the cabinet. That pass and its averaging viewport have been removed.

`screen_light.gd` uses two overlapping OmniLight3D sources anchored to the TV.
Their short ranges and receiver mask limit the effect to the cabinet, stand,
props and floor. Native lighting handles albedo and surface normals.
Screen-light specular is disabled: point highlights expose the approximation.
The screen lights do not cast live shadows. The 26 October test build disables
their cube-shadow passes after Steam Deck reports of an abrupt white/cyan
washout affecting the picture and clock digits after sustained play. Any nonzero
screen glow restored the fault; zero cleared it, while bloom had no effect.
This is a targeted mitigation pending a long-session hardware test, not a proven
engine diagnosis. Colour, energy, reach and ambient bounce are unchanged.
`TableOccluder` remains dormant and excluded from the lamp's caster check.
Without those live shadows, some extra light can reach beneath the tabletop.

No projector, reflection capture or full-screen bloom pass is required. The
emulator emits its already-created CPU Image by reference after upload. A
constant 192 jittered samples are graded before averaging, avoiding GPU
readback and full-frame image processing. Picture area scales emitted power;
scanline/mask detail, PAL carrier noise and fitting guides are deliberately not
sampled. They should not create flickering pools of coloured light. This is an
approximation of integrated picture radiance, not an exact integral of the
final CRT shader. A 55 ms exponential response smooths 20 Hz updates without
delaying the emulator, input or the displayed picture.

Unchanged paused pictures reuse their last radiance sample. Presenting a frame
marks it dirty even when the emulator reuses the same Image; grading and fitting
changes also trigger a new sample. Light range is written only when TV scale
changes, avoiding redundant bounds/shadow-state updates during colour changes.
The lighting response is unchanged; the two screen lights' live shadows are disabled.

## Local checks (RTX 4080, Windows, Godot 4.5.1 Compatibility)

- `tests/screen_spill.gd`: original synthetic geometry/content only. Checks black
  emission, blue light, albedo response, invariance under colour-half swaps,
  linear averaging, gamma and brightness, receiver exclusions, bounded range,
  immediate off/zero sampling and the two-light/shadowless configuration.
- CPU sampling measured 0.124 ms per 192-sample update at 20 updates/s.
- `tests/screen_spill_performance.gd`: real scene, two 1920x1080 eyes, TV at
  1.2 m, no model screenshots. Alternating off/on after warm-up measured summed
  eye GPU medians 0.176 / 0.176 ms, CPU/wall medians 0.742 / 0.741 ms. This is
  below measurement noise on this desktop, not a prediction for Steam Deck.
- `tests/room_controls.gd` checks settings persistence and no averaging viewport.
- Primitive-only preview images are generated under ignored `build/screen-light`.
  The licensed NoAI TV model and its textures were not supplied for AI visual
  inspection, altered, or added to source control.

No Steam Deck connection, transfer or hardware performance claim was made.

## Tuning and limitations

Room > Screen glow (0 = off): default 0.5, maximum 1.0 (a room lit by the TV
alone, as in the Lights off mood). Energy is 16 × radiance × glow per light, in
proportion to the picture's light, reaching 3 m with a soft falloff; each light
follows its half of the picture. The picture's bounce (radiance × glow) is added
to the room's ambient light (`set_room_ambient`), so surfaces that face away
from the lights take a faint fill in the picture's colour.
Values saved on the old 0–0.4 scale migrate once (0.4 becomes 0.5). Existing saved zero stays off; focus the slider and
press Y to restore the default. The legacy `crt/screen_spill` global preference
migrates to `room/spill_strength`, keeping this separate from per-game picture
preferences. The picture's Phosphor glow remains separate under Picture.
Increasing screen spill brightens nearby materials, not the image itself.
Existing distance blackout and the XR floor island stay in effect.

Room > Screen bloom in the dark shares these samples: `ScreenHalo`, an additive
quad masked to the casing's face, takes each half's smoothed radiance through
a steeper curve (radiance^1.4) and a level of bloom × the room's darkness × power level
(`CRTWorld.room_darkness`). The light keeps sampling while either the glow or
the bloom is on.

This is a diffuse area-source approximation, not ray-traced indirect lighting.
The sources sit 25 cm ahead of the tube (`LIGHT_DEPTH`), lighting the bezel
evenly; on the tube's face they hot-spotted its inner lip. The lower shelf and
VCR are left out of the receiver mask; the lights currently cast no live shadows.
They provide no mirror reflection of the tube. Keep the strength subtle.
