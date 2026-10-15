# Head tracking — 14 October 2026

The Deck build is installed separately at
`~/Applications/RetroCRT/tracking-20261014/`, with a **RetroCRT XR Tracking**
desktop launcher. The original SBS prototype remains available.

## Using it

Connect the glasses directly by USB-C. Open the tracking shortcut. Linux selects
the real provider by default. The overlay should say `XRLinuxDriver / LIVE 3DoF`;
the first fresh pose centers the view automatically. Turn slowly left/right,
look up/down, and tilt your head. The TV should remain fixed in space.
Press **R** or right-stick click to recenter locally. **Y** also recenters when
no game is loaded; during gameplay it remains available as a SNES face button.

Test in mono first if convenient. Then use the Full-SBS and monitor arrangement
already working on the Deck. F2 / Select switches SBS; F11 toggles fullscreen.
The app does not change the glasses' hardware mode or disable monitors.

Settings include field of view, axis inversion, smoothing, retrying real tracking
and returning to simulation. Opening settings returns to mono; this still needs
a per-eye menu for use inside SBS. If movement is reversed, report the axis or
invert that axis and recenter. If the TV drifts visually with the head despite
correct directions, calibrate **Vertical field of view**. Real tracking starts at
a provisional 24 degrees; simulation uses 50. Optical FOV is not yet calibrated.
Increase TV distance or reduce scale if the cabinet exceeds the visible area.
The latest local build saves FOV, inversion, smoothing, CRT effects and view-edge
fade along with distance, scale, IPD and convergence through **Save settings & close**.
The older tracking build currently on the Deck saves only the original view options.

## Driver settings

The user approved changing only `disabled=true` to `disabled=false` through the
installed CLI. Existing `output_mode=external_only` and `external_mode=none` were
preserved. This supplies tracking without enabling XR Gaming's virtual display.
Do not enable another head transform on top of the app's cameras. No driver
binaries, plugin files, feature restrictions or SteamOS system partitions changed.

The original configuration was copied to
`~/Applications/RetroCRT/prototype-20261014/xr-driver-config-before-tracking.ini`.
To return only the approved setting to its previous disabled state:

```bash
~/.local/bin/xr_driver_cli --disable
```

Do not restore the entire backup over newer unrelated preferences.

## Implementation

Godot checks `~/.local/bin/xrDriver` against the inspected binary hash
(`bb14df…1479ed`). Unknown builds report unavailable; use simulation until checked.

`retrocrt-tracking-bridge` is a C++ sidecar, chosen instead of a GDExtension to
isolate the process-shared mutex from Godot and avoid a Godot C++ build dependency.
It is compiled for Linux and sends only to 127.0.0.1 on an ephemeral app-bound UDP
port. No remote service is exposed.

It attaches to existing System V segments through `ftok(path, 0)` and `shmget`
without creation flags. It verifies regular-file ownership, segment ownership
and exact sizes: orientation 64 bytes, mutex 40 bytes, disabled 1 byte.
Orientation and disabled mappings are read-only; the mutex mapping must be
writable to acquire the producer's lock.

The installed Sombrero shader describes three x/y/z/w snapshots and timestamps
in the last float4. The installed `push_to_imu_buffer` disassembly agrees: current
quaternion at byte 0 and timestamp at byte 48. This establishes the consumed
fields for that binary without assuming upstream main matches the installation.

Polling uses `pthread_mutex_trylock`, copies under the existing mutex and unlocks.
It never creates, deletes, initializes or repairs driver resources. On robust
mutex owner death it exits without unlocking or repairing the inconsistent lock;
the kernel marks owner death again so the producer retains recovery control.
This failure behavior is tested only on private fixtures.

The reader requires advancing timestamps before declaring tracking live, rejects
invalid quaternions, and expires frozen timestamps after 250 ms. Stationary
orientation remains valid when timestamps advance. Godot expires receipt of
progressing sequences after 300 ms. Invalid data freezes the view with visible
status; simulation is an explicit choice. Segment identities are checked for
replacement periodically. The helper exits when its parent disappears and is
terminated on normal app shutdown.

NWU source axes map to Godot by B(x,y,z)=(-y,z,-x), a proper basis change. The
quaternion vector becomes (-qy,qz,-qx), preserving w. The installed shader's
forward +X, left +Y, up +Z look vector supports this mapping. Local recentering
and optional smoothing apply afterward. No global driver recenter is sent.
A reconnect rebases the local reference to keep the view continuous.

The bridge also forwards the driver's own timestamp. The app estimates
body-frame angular velocity from consecutive driver-timed poses, low-passes
and clamps it to 8 rad/s, and extrapolates the camera target toward the
frame being drawn by the **Motion prediction** delay (default 30 ms,
range 0-80 ms) in Controls & XR settings. The reported orientation itself is
never modified, so recentering and reconnect rebasing remain exact; only the
view target is extrapolated. Zero keeps raw driver timing. The estimator and
extrapolation are checked by `tests/pose_prediction.gd`; the live chain
check runs with prediction disabled.

## Verified and remaining

The Deck probe received 999 valid, distinct sequences over five seconds. The
exported app reports LIVE 3DoF. A live integration check confirmed that driver
poses reach the camera while the television remains fixed. The normal 13 scene
checks and 19 isolated native safety checks pass.

The user subsequently confirmed the tracking build looks great in SBS.
Long-session drift, precise optical calibration, disconnect/reconnect, the
default motion-prediction feel and Gaming Mode compositor behavior still need
on-device acceptance testing.
