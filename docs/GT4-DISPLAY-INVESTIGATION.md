# GT4 glasses blackout — 6 November 2026

Status: powered operation resolves the disconnect in the user's repeat test;
the exact electrical trigger remains unmeasured. The user reported that the entire glasses display
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

## Repeat occurrence, 14:05 UTC

The new diagnostics establish that the glasses disappeared from the Deck; the
user confirmed the switch to the internal display preceded touching the cable.
They are connected directly to the Deck, without a dock or adapter.

| Time (UTC) | Recorded event |
| --- | --- |
| 14:05:12 | Kernel reports USB disconnect for the VITURE glasses. |
| 14:05:13–14 | App reports stale tracking, then driver disconnected. |
| 14:05:18 | Gamescope reports DP-1 disconnected and selects the internal panel. |
| 14:05:23 | xrDriver aborts with memory corruption during reconnection. |
| 14:05:24–25 | The driver service automatically restarts. |

The driver coredump identifies signal 6/ABRT. The recorded stack runs through
`viture_device_connect`, `xr_device_provider_initialize` in `libglasses.so`, and
libudev device enumeration; its log reports `corrupted size vs. prev_size`.
This is a confirmed XR driver/SDK reconnect crash. It follows the initial USB
disconnect by eleven seconds, so it does not establish the original trigger.

During the preceding interval the app reports 2× MSAA enabled, a 3840×1080 SBS
window, live tracking and a room rate of 60 fps. The sampled frame/draw gaps
have a median near 16.67 ms and a maximum near 33.4 ms in the 31 seconds before
the disconnect. The app continues drawing as the output disappears. No GPU
reset is recorded. These observations rule out a sustained app rendering stall
in that interval, but do not prove power, cable, firmware or driver causation.

The installed driver is 2.11.9, also the latest release listed by upstream when
checked on 6 November. Its release note covers SBS support, not this reconnect
crash: [upstream releases](https://github.com/wheaney/XRLinuxDriver/releases/tag/v2.11.9).
No driver files, firmware or USB power policy were changed during investigation.

The next proposed controlled test is the same race, same cable, same AA and
display mode, with the XR driver temporarily stopped and a fixed view. That
removes the driver/SDK's USB interaction while retaining the display workload.
It requires the user's agreement because stopping the service removes head
tracking outside CRT XR too. Restore the service after the trial. One successful
race would be evidence for another trial, not proof of a permanent fix.

## Completed fixed-view trial, 14:18 UTC

The user authorized one race with the XR driver stopped. A bounded monitor
stopped `xr-driver.service` at 14:16:34, verified that it remained inactive
through the trial, and restored it automatically at 14:18:57 after CRT XR closed.
The service and `xrDriver` process were subsequently confirmed active again.
No app preferences, USB power policies or driver installation files were changed.

The glasses connected at 14:18:05, entered SBS at approximately 14:18:12, and
GT4 resumed. At 14:18:35 the kernel again reported their USB disconnect. The
user confirmed the picture failed in the same way. This reproduces the original
failure without the XR driver/SDK running; the reconnect crash is therefore a
separate problem and is not required for the display loss.

The user reported 27% battery; a subsequent read confirmed 27%, battery discharge
and no connected AC supply. Power delivery under load is now a strong hypothesis,
but no voltage/current measurement was captured at the USB-C port at the instant
of failure. Neither a universal low-battery cutoff nor an exact battery threshold
is established by these logs. Cable, glasses firmware and host USB-C behavior
remain alternatives.

The next inexpensive comparison is the same race and same settings after charging
the Deck to 80–100%, retaining 2× MSAA and normal tracking. If an appropriate
charge-and-display adapter is already available, externally powered operation is
another useful comparison. VITURE documents its supported charge/display adapter
as compatible with Steam Deck:
[manufacturer compatibility](https://www.viture.com/product/usb-c-xr-charging-adapter-ultra).
No accessory purchase or power-setting change is necessary for the first test.

## Powered comparison

The user subsequently confirmed that using a power splitter and charging while
playing resolves the repeated race-start blackout. Combined with reproduction
while the XR driver was stopped and the kernel's USB disconnect records, this
strongly implicates the power/connection path under battery operation. The
powered setup also changes the physical connection arrangement, so this test
does not independently establish a USB-C voltage drop or a fixed battery cutoff.

A brief blue area remained visible in the left eye for a fraction of a second
near the race-start point. The user clarified that it was confined to GT4's
picture inside the TV. No frame capture exists, and the Deck was not reachable
over SSH when this was reported. Treat this as a separate unresolved picture
artifact; neither the PS2 core, the CRT processing nor per-eye presentation has
been established as its source. Do not classify it as harmless or filter blue
frames without evidence. AA and picture settings remain unchanged.

### Powered-session logs retrieved

After SSH became available, the 14:20:47 trace and `display-probe-hido6yt7`
reports were preserved under `build/gt4-display-powered-20261106/`. A live read
confirmed AC power online and 34% battery. The session reports 2× MSAA enabled,
live head tracking and room rendering around 60 fps during the approximately
31-second gameplay interval examined. Median tick/draw gaps were approximately
16.68 ms; the largest was 37.82 ms. No GPU fault or application error was logged
during gameplay.

The glasses' SBS output remained enabled and powered on throughout that gameplay
interval. A USB disconnect was recorded at 14:21:33, after the game had paused
and the exit sequence had begun. This must be distinguished from the preceding
battery-powered failures, where the disconnect occurred during play. Gamescope
ReShade errors again appear at connection/session boundaries, not as a logged
race-start graphics fault.

The saved trace contains timings, display health and context, not frame images.
It cannot establish which stage produced the reported blue patch. This remains
an uncaptured transient picture artifact; no rendering setting was changed and
no speculative filter or graphics workaround was deployed.
