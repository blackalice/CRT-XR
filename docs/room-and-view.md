# Room and view controls

The latest **local** menu update groups controls into Game, View, Picture, Room
and Advanced. See [Settings and startup](settings-and-startup.md) for saved
setups, per-game picture settings and recovery. The Deck installation described
below remains the previous version until the next transfer.

The current update is installed on the Steam Deck in `library-controls-20261014`.
Previous installations remain available for rollback.

Open settings with L1 + R1 + Start, or Escape. Use L1 / R1 to change tabs,
D-pad / A to select controls, and B to return. Mouse clicks and normal keyboard
focus also work. Both eyes show the same menu in SBS. Save and Exit remain below
the tab content.

Settings work directly with the controller in gamepad mode: D-pad or left stick
up/down moves between controls and left/right changes category. A selects an
option for editing; left/right then changes it and A/B finishes the edit.
Buttons activate immediately with A. Holding a direction repeats after a short delay.
L1/R1 switches tabs. No desktop pointer mode is required. Focus loss, disconnect
and closing the menu cancel held movement. Ten regression checks remove the
platform's default UI joypad bindings to verify that these actions still work.

## SD card and default ROM folder

In **Game → Open SNES ROM**, press **X** for the SD card, navigate to your SNES
folder, then press **R1** (or **Use this folder as default**) to remember it.
The folder is saved immediately. Opening the ROM browser thereafter starts
there; playing a game from another folder does not change this preference.
**Y** jumps back to the default folder, **L1** goes up a folder, and A opens the
selected game, folder or navigation button. **Clear default** removes only the
preference. Y continues to reset selected options in the settings menu.

SD detection reads mounted `mmcblk` volumes from Linux mount information, handles
escaped paths, and rescan occurs whenever X is pressed. Multiple card volumes
are listed for selection. Missing or removed cards produce an explanation and
retain the saved default. No paths are hard-coded to a specific card UUID.
Library locations are stored separately in `user://recent.cfg`, alongside the
last game; resetting picture/view settings does not erase them.
The mount reader streams lines to EOF because procfs reports zero-length files;
whole-file reads returned no mount information on the Deck.

Seventeen ROM-location checks cover mount parsing, the live SD shortcut, folder
filtering, controller navigation, persistence across restarts/recent games,
missing-card recovery, clearing defaults, layout and menu-chord suppression.
Deck validation additionally requires successful detection of the actual mounted
card. The Steam entry uses its existing Gamepad With Joystick Trackpad layout;
its keyboard emulation remains disabled.

Press **Y** with a slider or switch selected to reset **only that option** to its
default. The footer's **Reset option [Y]** button does the same for the last
selected option on the current tab. Y on an action button does not reset other
options. **Setup → Reset all settings to defaults** is the separate global reset.
Save settings & close persists resets. Neither action reloads the game, erases
saves, switches tracking provider or changes the physical mono/SBS display mode.

## Screenshots

Press **F6**, or select **Game → Save clean screenshot**. A timestamped PNG is
saved to **Pictures/RetroCRT XR** (on the Deck, normally
`/home/deck/Pictures/RetroCRT XR`). A short on-screen message reports the folder.
If the system has no Pictures directory, the app uses `user://Screenshots`.

Captures contain the rendered 3D scene from the left eye as a normal single-view
image, even in SBS. Menus, diagnostics, notifications and the glasses' edge fade
are outside the capture. Current viewpoint, lighting and picture settings are
retained. Capturing from the menu keeps the game paused and the menu open. The
one-time GPU readback and PNG save only run when requested; repeated captures use
distinct names. `RETROCRT_SCREENSHOT_DIR` can override the destination for tests.

All 16 screenshot/reset checks pass locally and on the Deck. They verify option isolation, switches, live lighting,
reset-all, gameplay Y mapping, SBS/pause preservation, distinct filenames, F6 and
exact image equality with the clean 3D viewport. Captured model/game images are
not loaded into generative image tools or visually inspected by the assistant.

| Tab | Contents |
| --- | --- |
| Game | ROM browser, last game, pause, states, test signal, input-delay preview |
| View | Distance, screen height, stick binding and speed, scale, stereo, fullscreen, IPD, convergence, FOV, soft edges, smoothing |
| Picture | Scanlines, phosphor mask and glow, glass reflection, screen curvature |
| Room | Lighting presets, ambient/lamp/fill energy, warmth, lamp position, carpet brightness, fade distances, shadows, rug |
| Setup | Tracking provider, axis inversion, diagnostic overlay |

## Lighting and furniture

The default Deck Showcase uses a dark room with stronger screen spill and no rug.
Warm bedroom remains available with more ambient/front fill. Bright inspection
makes the cabinet easier to inspect; Dim XR keeps a
small pool of light around it. Sliders update immediately. Save settings & close
persists changes. Fade start/end always retain at least a 0.5 m transition.

Room's expanded light controls include **Shadow darkness** (default 0.60;
zero removes the lamp's shadow contrast, one restores full contrast). Y resets
the selected control. Lamp shadows can still be disabled entirely.

The Compatibility renderer now uses its 13-tap positional shadow filter.
Each eye keeps a 2048 shadow atlas but reserves a single 1024 slot for our one
shadow-casting lamp instead of subdividing it for many lights. The lamp cone
is tightened from 48 to 34 degrees to use that detail around the TV, and a
modest 1.5 normal bias reduces self-shadowing on the curved casing. This targets
jagged/self-shadowed edges without blurring the game image or adding shadowed
lights. It is filtered shadow mapping, not contact-hardening area shadows.
Compatibility ignores `shadow_blur`; increasing that property alone would not
help. Reference: [Godot 4.5 GLES shadow sampling](https://github.com/godotengine/godot/blob/4.5/drivers/gles3/shaders/scene.glsl).

The TV's plastic casing uses its authored baked occlusion and does not receive
live shadow maps. This deliberately trades physically exact self-shadows for
stable shading on the curved pedestal. It still casts filtered shadows onto
the furniture and floor. Room and screen illumination remain dynamic. The
Shadow darkness control affects those remaining live shadows, not the authored
occlusion in the casing. No new lightmap textures or extra rendering passes
are introduced by the receiver exclusion itself.

A subsequent Blender Cycles bake supplies stronger front/rear recess detail
using the model's existing UVs. **Casing recess shading** in the expanded room
controls adjusts this from 0 to 1 (default 0.70). It remains stable when the
head or lamps move; room and screen light still affect the plastic normally.
It uses one extra single-channel texture sample, with no extra rendering pass.
See [the local cabinet documentation](crt-model-local.md#blender-ao-bake).

The prepared wide wooden table from brandon_grey’s Wood Drawer & Tables Set now
replaces the stand when installed (see [wood-table.md](wood-table.md)). It keeps
its proportions, supports the full CRT depth, and moves the floor island down
to its feet without moving the viewing position. The original rounded oak-style
shelf unit remains as a fallback. Its open shelves contain
four unbranded game cases and a small console-shaped prop. Sage carpet and a
muted teal/terracotta woven rug provide colour without surrounding the viewer
with walls. The floor patch has soft black edges as well as distance fading.
The self-lit game picture keeps its contrast as the surroundings fade.

**Screen light spill** in Room now uses two native, shadowless lights instead
of an additive cabinet overlay. It illuminates the inset bezel, furniture and
nearby floor using their existing materials and normals. Point specular
highlights are disabled so the approximation does not look like two bulbs.
The lights move with the TV and their reach follows its scale. Picture and
glass are excluded from the receiver mask; the existing distance fade remains.

A jittered 16×12 grid samples the emulator's existing CPU presentation image at
20 Hz, applies the picture's colour grading per sample, and averages in linear
emitted-light space. The mean is scaled by picture coverage and smoothed with
a 55 ms response. Bright scenes light the surroundings more than dark scenes;
a black frame settles to no light. No spatial image detail is projected.
Paused games retain their last frame and still respond to grading adjustments.
The calibration signal uses a fixed approximate mean, with the same grading.

There is no GPU readback, extra viewport, receiver overlay, shadow map or
framebuffer copy. Zero hides both lights immediately and stops sampling.
Default strength is 0.10, adjustable to 0.40; Y resets the selected slider.
Existing saved zero values stay off until adjusted. The legacy
`crt/screen_spill` preference migrates to global `room/spill_strength`;
per-game picture saves do not override the room light.

This is a diffuse area-source approximation, not ray-traced indirect lighting.
The sources sit slightly ahead of the curved glass to light the inset bezel.
They do not cast occlusion shadows or provide a mirror reflection of the tube;
recessed/hidden surfaces can receive some light. Keep the strength subtle.

See [screen-light.md](screen-light.md) for local validation and performance.

The set and floor follow the distance and scale settings together. This remains
a stationary virtual object with rotational tracking; changing distance moves
the set, rather than simulating positional head tracking.

## Distance controls

View also has **Screen height offset (m)**, from −1.5 to +1.5 m in 0.05 m steps.
Positive values raise the TV, stand and floor island together; negative values
lower them. Zero retains the original placement. It leaves the eye position,
distance and 3DoF tracking unchanged. Use **Save settings & close** to remember it.

Right stick up brings the screen closer; down moves it farther away. The axis
has a 25% deadzone and proportional speed, adjustable from 0.2 to 2 m/s. Distance
is limited to 1.2–5 m. Changes save after 0.75 seconds without further movement.
Opening a menu suppresses movement; a held stick must return to neutral before
it can move the screen again. Disconnect and focus loss clear held movement.

View has a switch to release the right stick for future console controls.
Page Up / Page Down remain available in 0.1 m steps. A future Steam custom layout
can map a trackpad directional pad to these keys, leaving both analog sticks
available. No Steam layout has been installed as part of this local update.
Simulated head movement now uses mouse/keyboard so it cannot conflict with the
distance stick.

## Validation

Local checks: 17 scene checks, 29 gamepad checks, 23 room/view controls checks,
18 stereo menu checks, five cabinet-filtering GPU checks and two GPU
distance-fade pixel checks pass. The new props
were rendered and visually inspected separately from the licensed CRT asset.
The room/view test verifies axis mapping, deadzone, menu blocking, disable and
disconnect behaviour, distance limits, actual lighting updates, fade bounds,
toggles and preference reload. It restores the previous settings file.

## Speaker grille filtering

The GLB runtime loader supplied 4K textures without mipmaps, despite selecting
a mip-capable sampler. The loader now generates missing mip levels once for
each shared texture and selects trilinear anisotropic filtering. Normal maps
use normal-aware mip generation. This also filters roughness/metallic/AO maps,
which can otherwise shimmer under lighting. Full-resolution source pixels and
the on-disk GLB remain unchanged. It adds roughly one third to texture storage,
with a one-time startup generation cost, rather than a full-frame AA pass.

The synthetic GPU regression uses a minified checker pattern and subpixel motion.
Its temporal variance falls from 0.00149 to zero on the local renderer, while
the original image's alternating pixels remain intact. This verifies sampling
behaviour, not physical appearance through the glasses.

The Deck also passes all five filtering checks: pattern variance falls from
0.00144 to zero. A full-resolution SBS startup check confirms all nine cabinet
textures have mipmaps, use anisotropic filtering, and that glow is disabled.
No graphics or script errors were reported. The on-disk model hash is unchanged.

The following performance notes describe the now-disabled glow experiment:

A short Windows RTX 4080 rendering comparison of the initial version, with the diagnostic game and two
1920×1080 eyes, VSync off, measured mean frame times of 0.899 / 0.891 ms with spill
off and 0.899 / 0.896 ms with it on. Corresponding p95 values were 2.012 / 2.119 ms
off and 2.082 / 2.200 ms on. These small differences are not a reliable Deck cost
estimate. There was an audio overflow during warm-up. The benchmark is available
in the historical results here. The replacement benchmark now lives in
`tests/screen_spill_performance.gd`; the pixel tests use simple synthetic
geometry and solid-colour signals, without image inspection of the CRT asset.

The corrected version passed all nine screen-spill GPU pixel checks on the Deck,
including the high-contrast image-swap regression. In a short uncapped,
full-resolution stereo comparison running Super Mario World, mean frame times
were 3.736 / 3.823 ms off and 3.916 / 3.923 ms on; p95 was 6.075 / 6.448 ms off
and 6.516 / 6.533 ms on. The observed mean overhead was roughly 0.10–0.18 ms.
This offscreen check does not measure physical display latency or sustained
Gaming Mode performance. The diagnostic run reported an audio overflow and an
exit cleanup warning; shader checks and startup reported no errors. The warning
remained despite explicitly freeing the benchmark scene and requires separate
diagnostic cleanup investigation.

Physical appearance and feel of the new room/menu controls through the glasses
still need the user's next check.

## Baked grounding and soft carpet

The table and floor now use static contact AO, and the floor uses a filtered
CC0 carpet surface. Room and screen lighting remain adjustable. See
[room-contact-bake.md](room-contact-bake.md) for the repeatable Blender bake,
receiver setup, export details and when added props require a rebake.
