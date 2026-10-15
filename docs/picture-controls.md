# Picture fitting and CRT controls

Open settings with **L1 + R1 + Start**. Use L1/R1 to change tabs, D-pad or left
stick to select, left/right to adjust and A to activate. **Y resets only the
selected option**. Save and close persists the new controls.

## Picture → Screen fit

The whole framebuffer is mapped into a safe rectangle inside the rounded tube,
including PAL-height and high-resolution SNES output. It does not discard
overscan rows or crop corners to imitate a CRT. The imported model's screen
outline determines the safe area, with an additional bezel allowance.

Width/height limits reduce the picture inside this area. Horizontal/vertical
position use only the remaining border space, so moving the picture cannot
push its edges outside the safe area. Preserve 4:3 aspect is enabled by default;
disable it to adjust the two axes independently. Extra safe border provides
more clearance if the bezel obscures an edge at an oblique viewing angle.
Guides mark the full picture boundary and provide a calibration circle.
Restore full-picture fit resets these fitting controls.

**Fit TV to neutral view** adjusts distance/scale and recentres the view. This
helps if the virtual TV is outside the camera frame at the current settings.
Head tracking still lets you look away from the anchored television.

## Picture → Signal and CRT

Signal offers Clean, RGB CRT, PAL composite, NTSC composite and Auto composite
presets. Auto chooses PAL below 55 Hz and NTSC otherwise, using the core's game
rate. RGB remains the default and bypasses the extra composite pass. Presets
preserve fitting, glass, room and view preferences.

Display gamma controls the tube response: **lower gamma lightens midtones**.
Brightness, contrast, saturation, warmth and hue allow further adjustment.
Composite strength blends colour bleed into the clean signal; composite
artifacts adds luma/chroma interference. Phase noise and moving signal artifacts
are optional and default to zero to keep the XR picture stable. They stop while
paused or in settings. Composite controls have no visible effect in RGB mode.

Picture retains scanline, mask, phosphor glow, glass and physical curvature
controls, and adds beam sharpness and tube edge shading. Repeating beam/mask
patterns fade as they become too small for the eye viewport to resolve.
Screen-to-cabinet illumination is separate under Room; see
[Screen light](screen-light.md).

The beam reconstruction adapts Timothy Lottes' public-domain CRT shader. PAL
decoding adapts Viacheslav Slavinsky's BSD 2-Clause single-pass shader, including
its 20-tap filter. NTSC uses YIQ and an NTSC carrier/line-phase approximation.
These effects are artistic approximations, not calibrated hardware emulation.
See `THIRD_PARTY.md` and `third_party/shaders/` for sources and notices.

The composite pass is shared by both eyes and contains no previous-frame
buffer. Horizontal beam reconstruction is also shared between eyes to reduce
close-view rendering cost; effect strengths are unchanged. See
[CRT performance measurements](crt-performance.md) for Deck results and limits.
