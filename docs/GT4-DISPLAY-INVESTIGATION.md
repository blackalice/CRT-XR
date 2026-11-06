# GT4 glasses blackout — 6 November 2026

Status: cause not confirmed. The user reported that the entire glasses display
went black soon after a race started. The Steam menu was also invisible;
disconnecting and reconnecting the glasses restored the picture.

Evidence was copied before another launch could replace the app log. Local
captures are under `build/gt4-display-20261106/`: the app log, system journal,
XR driver log, display-probe events and the opt-in frame trace from the session.

The trace records the room and GT4 continuing at approximately 60 fps before
the reconnect. Draw callbacks continue; the 240–276 second interval contains
no sustained rendering stall. This confirms continued app activity, not light
reaching the glasses. There is no recorded app crash or GPU reset in the
captured journal. The first recorded USB disconnect is 12:22:23 UTC. Later
reconnects include a return through 1920×1080 to 3840×1080 SBS at 60 Hz.

The XR driver records USB command errors around disconnect/reconnect. Several
error lines lack timestamps; they do not establish what triggered the initial
blackout. Gamescope ReShade texture errors occur at the initial connection,
before the app's tracking-only session, and are not evidence of a race-time
failure. An incompatible automatic save was rejected separately; no evidence
links that rejection to the display blackout.

The missing Steam overlay and continued app drawing point toward the physical
display or compositor output path. That is an inference, not a proven driver,
cable, glasses firmware or application defect. No automatic mode reset or
driver restart is justified by the current evidence.

For the next occurrence, the existing read-only display watcher also records
connector `enabled` and `dpms` states when the kernel exposes them. Every five
seconds, and on connector changes, its JSONL log includes the app heartbeat:
frame/draw counters, window/screen sizes, camera orientation, tracking state,
MSAA and TV selection. A stale heartbeat remains identifiable by its age.
The opt-in frame trace includes the same context with wall-clock timestamps.
These additions use existing once-a-second metadata and perform no GPU readback.

The user's 2× MSAA result is consistent with geometry-edge aliasing. The earlier
shader border smoothing addresses the picture/content cutoff, a different edge.
AA remains a user preference; this diagnostic update does not change it.

The diagnostic release `display-diagnostics-20261106` is active on the Deck.
Headless and graphical checks, including the runtime heartbeat and read-only
kernel output-health probe, passed on the device. The preceding
`display-profiles-20261106` release is retained. Existing user preferences were
not used by the isolated validation runs or changed by the deployment.
