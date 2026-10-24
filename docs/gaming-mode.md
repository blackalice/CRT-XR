# Steam launch and controls

The local startup update keeps the SBS instructions and game inside one
fullscreen app window. After confirmation, the display stays black while the
stereo scene loads; there is no windowed Godot-logo relaunch. This change still
needs validation on the Deck. The existing Native/3840×1080 resolution setup in
Gaming Mode remains necessary; this update does not take over Gamescope outputs.

Launch **CRT XR** from Steam's Non-Steam library. Holding the three-lines
button on the desktop switches the desktop controller layout; it does not
enter the separate SteamOS Gaming Mode session. Desktop keyboard/mouse mappings
can arrive as pause, mouse clicks or other keyboard commands instead of SNES
buttons. Adding the app to Steam gives it a dedicated controller layout.

The Deck installation has a Steam shortcut targeting `launch-steam.sh` in
`~/Applications/CRT-XR/latency-20261014/`. This entry uses Steam's
**Gamepad With Joystick Trackpad** template and **Native** game resolution.
The setup was performed through the running Steam client's own shortcut and
controller interfaces, without editing live shortcuts.vdf or global layouts.

In Gaming Mode, find **Library → Non-Steam → CRT XR**. The launcher uses
the Deck screen in mono when no identified VITURE glasses are connected. With
the glasses connected it first shows **SWITCH TO SBS NOW**, without loading or
playing the game. Switch the glasses with their button. Desktop Mode detects
the advertised Full-SBS mode and proceeds automatically. Gaming Mode proceeds
when its Native display reports 3840×1080, with **A: Continue after switching**
available when Steam does not expose the display change. **B** cancels setup.
Only then does the game start in SBS. Desktop setup times out after 90 seconds.
Gaming Mode owns monitor selection and resolution, so the launcher does not
run KScreen or start another Gamescope instance. Full SBS still needs an actual
3840×1080 external display mode; Native is the per-game resolution setting,
not proof that the external output has selected that mode.

From Steam in KDE Desktop Mode, the same entry retains the existing display
setup/recovery supervisor when glasses are connected. The main desktop icon
now launches the Steam entry rather than bypassing Steam Input. The previous
direct-launch shortcut is backed up with the previous installation files.

The most recent game opens automatically; SRAM continues to use the existing
save directory. If no recent game exists, use L1 + R1 + Start to open settings
and choose a ROM. No save state loads automatically.

| Deck control | SNES action |
| --- | --- |
| A (bottom) | B |
| B (right) | A |
| X (left) | Y |
| Y (top) | X |
| D-pad / left stick | Directions |
| L1 / R1 | L / R |
| Three-lines button | Start |
| View button | Select |
| L1 + R1 + Start | Settings |
| Right-stick click | Recenter |

For an explicit mode, set Steam launch options to `--mono` or `--glasses`.
Leave them empty for connected-glasses detection. Do not enable Proton for this
native Linux build. In this entry's Controller settings, the Gamepad template
should report gamepad use, with keyboard and mouse bindings absent.

Menu controls are D-pad to navigate, **A** to activate the focused setting and
**B** to close. A is forwarded as an explicit UI accept action rather than
depending on platform-specific default controller bindings.

The user accepted the Desktop Mode SBS prompt and handoff. Gaming Mode still
needs its external resolution chosen through Steam's UI when automatic mode
changes are unavailable. See [input latency](input-latency.md) for the current
one-frame preview option and Deck performance measurements.

Validation: 29 application gamepad checks, 13 stereo/menu checks and six launcher
checks pass locally, including activating the focused Close button and waiting
for SBS, cancellation and timeout. The prompt was started with graphics enabled.
The Steam-launched Deck app reports **Steam Deck Controller** and loads the
existing Super Mario World ROM. The user confirmed gameplay controls work through
Steam, and then confirmed the updated build boots and allows opening the menu
and exiting. The XR prompt and SBS handoff still require physical acceptance;
Full SBS in the actual Gaming Mode session remains unverified.

Valve documents the non-Steam library workflow in its
[Desktop FAQ](https://help.steampowered.com/en/faqs/view/671a-4453-e8d2-323c).

## Into and out of SBS automatically

Where the XR driver can switch the connected glasses itself (it reports
`sbs_mode_supported` with the `sbs` feature), `steam-session.py` asks it for SBS
as the setup screen opens, exactly as XR Gaming's own SBS toggle does
(`driver-sbs.py`, the driver's `sbs_mode=enable` control request). The screen
says the glasses are switching by themselves and continues when the SBS mode
appears, as it does after the button. Its status file (`CRT_XR_AUTO_SBS`, `auto-sbs.json` in the launch's
diagnostics folder) reads `switching`, `on` or `failed`; on `failed` the
button instructions return. After CRT XR exits, the launcher switches the
glasses back to 2D, only if they were in 2D before the launch.

Glasses the driver cannot switch (the VITURE Pro 2 on driver 2.11.9) use their
button on the way in. On the way out, after the power-off, `scripts/ui/sbs_exit.gd`
shows "Back to 2D" once in each eye and closes CRT XR as soon as the glasses
leave SBS: the SBS mode drops out of the display probe's advertised modes for
two readings in a row. B leaves at once, still in SBS, and it closes anyway
after a minute. Without it, Steam came back doubled until the button was
pressed. Desktop Mode, Windows and mono launches never show it.

## Get your glasses ready (startup screen)

With the display probe (Gaming Mode), `scripts/ui/sbs_prompt.gd` needs no
input: no A to darken, no Begin. It asks for the glasses' SBS button (or says
the driver is switching them), goes dark as soon as the glasses' SBS mode
appears after being absent, and starts the room once the probe, screen and
window all match for four readings. An SBS mode advertised from the very first
reading never blanks the screen by itself, in case glasses list it while in
2D. After 20 seconds a tip appears (check the USB connection); dark in SBS for
20 seconds, a note in each eye points at Steam's per-game resolution. B
returns to Steam.

Its canvas is 720 high and as wide as the window (16:9 to 32:9). Glasses still
in 2D show the 3840x1080 window letterboxed in a 1920x540 band, so the wide
layout (logo and title beside the steps) fills that band instead of a small
16:9 box in its middle; a 16:9 window stacks them and shrinks to fit. Desktop
launches without the probe keep A to darken and the supervisor's start gate.
