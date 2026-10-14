# Glasses launch flow

Updated 14 October 2026. KDE display setup and supervised-exit recovery have
been tested on the Deck. Hardware SBS switching was tested and rejected by the
installed SDK; the installed desktop shortcut uses the physical-button fallback.

## Intended everyday use

1. In KDE Desktop Mode, launch the **glasses launcher**.
2. Connect the glasses and use their physical SBS switch. The launcher waits up
   to 90 seconds for the identified glasses to advertise a Full-SBS mode.
3. It saves the display layout, enables 3840x1080 at 100% scaling, verifies the
   accepted mode, disables the built-in panel, and launches RetroCRT fullscreen
   with SBS already enabled. It prefers a supported rate nearest 60 Hz.
4. Open settings with L1 + R1 + Start / Escape. The menu and ROM browser appear in both eyes.
   Use the D-pad and A; B cancels. **Play last game** remembers the last loaded
   ROM path. It loads the game normally; it does not automatically load a state.
5. Choose **Exit RetroCRT** to end the session, restore mode/placement/scaling and
   wake the Deck screen, including when it was already off before launch.

The default launcher leaves the physical SBS switch manual. It does not change
XR Gaming settings. Layout recovery does not switch the
glasses back to mono; use the physical button when returning to an ordinary desktop.
The saved layout is taken after SBS has appeared, before RetroCRT changes it.

### Hardware SBS test result

The manual step is an implementation limit of the current launcher, not a
hardware requirement. VITURE's current official SDK lists Pro 2 support and
provides `xr_device_provider_switch_dimension` to select 1920x1080 2D or
3840x1080 SBS at 60 Hz:
[VITURE device control reference](https://www.viture.com/en-SG/developer/glasses-sdk/glasses).
The upstream XR Linux driver also routes SBS requests to its VITURE provider:
[driver control handling](https://github.com/wheaney/XRLinuxDriver/blob/main/src/driver.c)
and [VITURE implementation](https://github.com/wheaney/XRLinuxDriver/blob/main/src/devices/viture.c).

The installed driver reports VITURE Pro 2 and `sbs_mode_supported=true`. An
experimental `driver-sbs.py` adapter now uses the installed API's freshness,
identity and feature-availability checks, then sends only the existing
`sbs_mode=enable/disable` control protocol. Driver and API hashes are pinned.
It neither opens USB independently nor changes feature availability.

Both live enable attempts were consumed by the driver, but its VITURE SDK 2.4.0
reported `get_display_mode ... returned -7`, followed by `Error setting requested
SBS mode` and a device reconnect. Tracking resumed after calibration. Software
capability reporting alone therefore does not establish working mode control on
this installation. The working driver was preserved. The user switched SBS with
the button, and the rest of the launch flow then worked.

Automatic hardware requests are now opt-in with `--auto-sbs`; ordinary launches
and the installed shortcut use the button. A supported SDK/firmware fix still
needs investigation. No upgrade or firmware change was performed. The adapter
will not overwrite another client's pending request. An old root-owned recenter
request blocked initial access; the user completed a one-time password-protected
cleanup after its contents were backed up. Normal launches require no sudo.

The implementation uses KDE's existing `kscreen-doctor` display API. KDE documents
mode, scaling, rotation, position and enable/disable changes, including applying
multiple changes together:
[KDE command-line implementation and help](https://github.com/KDE/libkscreen/blob/master/src/doctor/main.cpp).
The JSON fields used by the launcher follow
[KDE's configuration serializer](https://github.com/KDE/libkscreen/blob/master/src/configserializer.cpp).
The installed KScreen JSON and the glasses' VITURE EDID descriptor were verified.

## Package commands

The package includes Python 3 standard-library code and shell launchers; it uses
the Deck's existing Python, KScreen and session bus. It requires no root access.
From the package directory:

```bash
chmod +x retrocrt.x86_64 launch-deck.sh launch-glasses.sh
./launch-glasses.sh
```

Add `launch-glasses.sh` as the new Desktop/Steam shortcut, with its working
directory set to the package folder. Keep the existing tracking build available
until this flow passes the hardware check. `launch-deck.sh` remains the ordinary
launcher and makes no display changes.

Automatic identification reads the existing DRM EDID and requires a VITURE
descriptor. It does not infer identity just because a monitor supports 3840x1080.
If identification is unavailable, inspect `kscreen-doctor --json` and explicitly
name the glasses connector once in the shortcut's arguments, for example:

```bash
./launch-glasses.sh --output DP-1
```

`DP-1` is an example, not a verified connector on this Deck. Only use the actual
identified glasses output. Multiple active external monitors are rejected to
avoid launching fullscreen onto the wrong display. An ordinary game argument
can also be supplied, such as `--rom /path/to/game.sfc`.

## Recovery behavior

The supervisor keeps running while Godot runs. The app reports its SBS state,
window dimensions and frame count every second. A startup deadline of 20 seconds,
a stale/invalid status lasting over 6 seconds, mode loss or a glasses disconnect
ends the app and attempts recovery. Leaving app SBS mode is blocked in a managed
session so physical and rendered modes stay aligned.

Before restoring the old mode, placement, scale, rotation and priority, recovery
first enables the connected built-in panel in a separate call. It uses currently
advertised mode IDs rather than assuming old IDs survived a reconnect. The backup
contains only the glasses and internal display. If the glasses are disconnected,
the internal panel is recovered even when it was disabled before launch.

The backup stays in `~/.local/state/retrocrt/display-before.json` (or the equivalent
`XDG_STATE_HOME`) until restore succeeds. Another session is excluded by a lock.
If the supervisor itself is forcibly killed or a restore fails, run:

```bash
./launch-glasses.sh --restore
```

The next normal glasses launch also attempts a leftover restore first. A killed
supervisor cannot perform immediate cleanup, and unavailable KScreen/session-bus
services can prevent restoration; the backup is retained for recovery. Power
loss, suspend/resume and KWin failure remain hardware acceptance cases.

The launcher targets KDE Desktop Mode. It rejects a Gamescope desktop marker;
Gaming Mode integration requires separate work and testing. It does not change
the SteamOS system partition, driver files or hardware mode.

## Verification

Ten display-session Python tests pass without modifying a real display: refusing unidentified
or ambiguous outputs, choosing an available Full-SBS mode, keeping the internal
panel active when mode verification fails, restoration after mode-ID changes,
disconnect recovery, recovery before an external-restore failure, status validation,
restoration after app launch fails, and waking a previously disabled panel on
exit. Five adapter checks cover stale/wrong devices, unavailable features,
preserving pending requests, SBS-only requests/acknowledgement and idempotence.

Twelve Windows GPU menu checks pass, including controller navigation, opening an
actual diagnostic ROM with A, browser cancellation, keeping SBS active, and
restoring the game's previous pause state. The 13 scene and 17 emulation checks
also pass.

On the Deck, the fallback launcher selected 3840x1080 at scale 1, disabled eDP-1,
and started Super Mario World with LIVE 3DoF. The app's advancing heartbeat
confirmed a 3840x1080 SBS window. A supervised SIGTERM test recovered the internal
panel and relaunched the game successfully. The user reported that Mario looked
"amazing" through the glasses. Physical unplugging, abrupt supervisor kill,
audible sound and sustained frame times remain unverified.

Current build: `~/Applications/RetroCRT/scene-lighting-20261014/`, with the
**RetroCRT XR** and **RetroCRT Restore Screen** desktop shortcuts updated.
Older builds, including `seamless-20261014`, and previous shortcut files were
preserved. The 3.4 m default, adjustable curvature, gamepad mappings, local
Panasonic cabinet and scene lighting are deployed. No settings.cfg existed at
deployment, so application defaults apply; no saved calibration was overwritten.
