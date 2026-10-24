# Screen light: local implementation and validation

The previous effect was an additive material pass; it could lift dark plastic
independently of its albedo and initially resembled the game image overlaid on
the cabinet. That pass and its averaging viewport have been removed.

`screen_light.gd` uses two overlapping OmniLight3D sources anchored to the TV.
Their short ranges and receiver mask limit the effect to the cabinet, stand,
props and floor. Native lighting handles albedo and surface normals.
Screen-light specular and shadows are disabled: point highlights expose the
approximation, while shadow maps would add substantial stereo cost. The room's
existing shadowed lamp is unchanged. This respects the Compatibility renderer:
[Godot 4.5 lighting documentation](https://docs.godotengine.org/en/4.5/tutorials/3d/lights_and_shadows.html).

No projector, reflection capture or full-screen bloom pass is required. The
emulator emits its already-created CPU Image by reference after upload. A
constant 192 jittered samples are graded before averaging, avoiding GPU
readback and full-frame image processing. Picture area scales emitted power;
scanline/mask detail, PAL carrier noise and fitting guides are deliberately not
sampled. They should not create flickering pools of coloured light. This is an
approximation of integrated picture radiance, not an exact integral of the
final CRT shader. A 55 ms exponential response smooths 20 Hz updates without
delaying the emulator, input or the displayed picture.

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
alone, as in the Lights off mood). Energy is 24 × radiance^0.7 × glow per light,
reaching 3 m with a soft falloff; each light follows its half of the picture.
Values saved on the old 0–0.4 scale migrate once (0.4 becomes 0.5). Existing saved zero stays off; focus the slider and
press Y to restore the default. The legacy `crt/screen_spill` global preference
migrates to `room/spill_strength`, keeping this separate from per-game picture
preferences. The picture's Phosphor glow remains separate under Picture.
Increasing screen spill brightens nearby materials, not the image itself.
Existing distance blackout and the XR floor island stay in effect.

Room > Screen bloom in the dark shares these samples: `ScreenHalo`, an additive
quad in front of the casing, takes each half's smoothed radiance through the
same curve and a level of bloom × the room's darkness × power level
(`CRTWorld.room_darkness`). The light keeps sampling while either the glow or
the bloom is on.

This is a diffuse area-source approximation, not ray-traced indirect lighting.
The sources sit slightly ahead of the curved glass to light the inset bezel.
They do not cast occlusion shadows or provide a mirror reflection of the tube;
recessed/hidden surfaces can receive some light. Keep the strength subtle.
