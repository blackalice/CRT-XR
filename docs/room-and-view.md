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
saved to **Pictures/CRT XR** (on the Deck, normally
`/home/deck/Pictures/CRT XR`). A short on-screen message reports the folder.
If the system has no Pictures directory, the app uses `user://Screenshots`.

Captures contain the rendered 3D scene from the left eye as a normal single-view
image, even in SBS. Menus, diagnostics, notifications and the glasses' edge fade
are outside the capture. Current viewpoint, lighting and picture settings are
retained. Capturing from the menu keeps the game paused and the menu open. The
one-time GPU readback and PNG save only run when requested; repeated captures use
distinct names. `CRT_XR_SCREENSHOT_DIR` can override the destination for tests.

All 16 screenshot/reset checks pass locally and on the Deck. They verify option isolation, switches, live lighting,
reset-all, gameplay Y mapping, SBS/pause preservation, distinct filenames, F6 and
exact image equality with the clean 3D viewport. Captured model/game images are
not loaded into generative image tools or visually inspected by the assistant.

| Tab | Contents |
| --- | --- |
| Game | ROM browser, last game, pause, states, test signal, input-delay preview |
| View | Distance, screen height, stick binding and speed, scale, stereo, fullscreen, IPD, convergence, FOV, soft edges, smoothing |
| Picture | Scanlines, phosphor mask and glow, glass reflection, screen curvature |
| Room | Room presets (built-in moods and three of your own), ambient/lamp/fill energy, warmth, lamp position, floor style and brightness, props (clock radio, 24-hour clock, VCR, game boxes, your game on the box), room sound and tube whine, follow the time of day, fade distances, shadows |
| Setup | Tracking provider, axis inversion, diagnostic overlay |

## Lighting and furniture

Five lighting moods, darkest first: **Lights off** (no room light at all; the
screen's full glow is the only light), **Late night** (the default: the Deck
Showcase's dim lamp with the screen glowing), **Dim XR** (a small pool of lamp
light), **Warm bedroom** and **Bright inspection** (for looking over the cabinet).
Each sets every lighting value (screen glow, ambient, lamp, front fill, warmth,
shadow darkness, floor brightness and fade), so a mood always looks the same;
the brighter the room, the less the screen's glow stands out. A room is
recognised as its mood by its lighting alone, so switching a prop or the floor
doesn't turn it into Custom. These moods change lighting only. **Room → Presets** also
keeps three rooms of your own (lighting, shadows, floor and props): save the current room
into a slot, rename or delete it. The **Room** switch in the pause menus and Quick settings
moves through Custom, the moods and your rooms with left/right; Custom brings back the room
you tuned yourself. Sliders update immediately. Save settings & close
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
four unbranded game cases and a small console-shaped prop. The floor provides
colour without surrounding the viewer with walls: **Room → Materials → Floor**
offers a 90s confetti carpet (default), a wool carpet with large-scale
patches and a worn path, or wooden floorboards. At 2–3 m a carpet's pile is far
below a pixel, so each style adds detail that reads at that distance; the
confetti marks fade into the base colour before they become small enough to
shimmer. All three are one shader branch on a uniform with at most the existing
carpet texture reads (floorboards read none). The former woven rug was removed.

### Table props

**Room → Props** toggles three original, procedurally built props (no external
models or textures; `scripts/rendering/room_props.gd`, `shaders/prop_*.gdshader`):

- A **clock radio** left of the TV: charcoal plastic, speaker grille, snooze bar
  and a smoked red seven-segment display showing the system time (12-hour with a
  PM dot by default, or 24-hour). It sits where the music's default Radio
  position places the sound.
- A full-size **VCR** on a lower shelf under the TV, with a cassette door,
  transport buttons and a dim teal display: the time, or the tape counter while a
  video plays (minutes and seconds, then hours and minutes). The shelf is a plain board resting on the table's lower rails
  between the legs, toned from the table's own wood and darkened by the tabletop's
  shade; it stays when the VCR is hidden.
- Three **game boxes** (a plastic clamshell between two cardboard cartons)
  right of the TV. Each box uses cover, spine and edge artwork from
  `artwork/game-boxes/`, lit by the room and screen without emission.
  **Your game on the box** (on by default) prints the playing game's front cover
  on the top carton, from the player's existing scrapes (`covers` or
  `box2dfront`; never screenshots or 3D renders), loaded at 512 px on a worker
  thread. Portrait covers lie turned, like a box put down sideways; any spare
  edge and the spine take the cover's average colour. Without a cover, or with no
  game loaded, the box keeps its own print.

### Room sound and time of day

**Room → Sound** adds quiet sound around the TV, off by default: *Quiet room*
(soft air), *Rain on the window*, or *Rain and a ticking clock* (ticking on the
real second), with its own volume kept well under the programme. **Tube whine**
adds the line transformer's 15.7 kHz whine, very quietly; many people can't hear
it. **Room → Lighting → Follow the time of day** (off by default) shifts your own
lighting by the hour: brighter and cooler by day, warmer in the evening, dimmer
in the small hours. The saved values don't change, so turning it off restores
the room exactly. These are room settings, so room presets keep them.

### TV moments

**Audio → TV sound** has the TV's own effects beside the power-on: a **channel
change** (static, a click and a rolling picture for under half a second when a
game or video starts after the first) and a **power-off** (the picture collapses
to a line and a fading dot as CRT XR closes). **Picture → CRT → Degauss** closes
the menu and plays the coil's wobble, colour swirl and thunk. One **TV effect
sounds** level covers them all. Reduced motion keeps the degauss colour without
the wobble, settles the channel change without the roll, and skips the power-off.
The sounds are synthesised by `scripts/make-tv-sounds.py` (CC0, no recordings).

Displays are emissive but add no lights and never blink. Props are built at 2.3×
real size to match the oversized TV and table, cast no
shadows, receive the screen light and distance fade, and sit on a soft
multiply contact patch in place of baked AO. Together they add about four draw
calls per eye and no video memory (measured +8 draws for both eyes, +0.016 ms
GPU per eye on Windows). The floor patch has soft black edges as well as distance fading.
The self-lit game picture keeps its contrast as the surroundings fade.

**Screen glow** (Room → Materials; 0 = off, 1 = a dark room lit by the TV
alone) uses two native, shadowless lights instead of an additive cabinet
overlay. Each takes the colour of its own half of the picture (leaning 70%
towards its side), so a red left side tints the left of the set. Light is in
proportion to the picture's average linear radiance (energy 16 × radiance at
full glow), so a small logo on black lights the room faintly and a bright game
picture clearly; it reaches 3 m with a gentle falloff. The lights sit on the
tube's face, where the light comes from: the tabletop, the props beside the set
and the bezel's inset walls face them, while the casing's own front and the
table's rails and legs face away, as they do from a real screen. They have no
shadows, so the lower shelf and the VCR, under the tabletop, are left out of
them rather than lit through it. The picture's light also bounces back off the
room: a faint fill in its colour is added to the room's ambient light, so the
casing's front and the darker corners take the picture's colour softly
instead of going black. Settings saved
before this rescale (`room/lighting_version` below 2) map the old 0–0.4 range
so the old maximum, the previous default, becomes the new default of 0.5. It
uses the furniture's and floor's existing materials and normals. Point specular
highlights are disabled so the approximation does not look like two bulbs.
The lights move with the TV and their reach follows its scale. Picture and
glass are excluded from the receiver mask; the existing distance fade remains.

**Screen bloom in the dark** (Room → Materials; default 0.5, 0 = off) is the
soft halo your eyes see around a bright tube in a dark room. It is a single
additive quad just in front of the casing's face (`shaders/screen_halo.gdshader`):
clear over the picture, brightest at the tube's edge and fading out within
about 12 cm, well inside the casing's outline, so it never shows an edge or
haloes the black room beyond. It takes the colours of the picture's left and right halves from
the screen glow's samples (no extra sampling), through a steeper curve
(radiance^1.4) so dark scenes barely bloom and bright ones clearly do. It
scales with the room's darkness: full with the room lights off, most of it in
Late night, little in Dim XR and none in brighter rooms or by day when the
room follows the clock. It fades out when seen from a steep angle and goes dark
with the power-off. It is not a full-screen bloom pass, which would cost a
pass per eye on the Deck and bloom everything else too.

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
