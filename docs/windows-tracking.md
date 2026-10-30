# Windows tracking preview

Windows uses Godot's native Xbox-compatible controller support. No Steam input layer is required. LB + RB + Start opens settings; click the right stick to recenter. The face buttons map by physical position to the original console.

Build the helper with `scripts/build-windows-tracking.ps1`, then export with `scripts/export-windows.ps1`. MinGW POSIX in WSL Ubuntu is required for this helper build.

For local testing, set `CRT_XR_VITURE_SDK` to the absolute path of `sdk/x86_64/glasses.dll` before launching. The editor finds that path automatically. Exported apps otherwise look for `sdk/glasses.dll` beside the EXE. Keep the SDK's dependency DLLs together in its directory. The SDK is excluded from Git, Godot imports and exported resources. Vendor redistribution rights still need verification before a public Windows tracking package can include it.

Close SpaceWalker before testing so it does not compete for USB access. Connect glasses directly to the PC. The Windows EXE opens a launch screen. Recommended: switch the glasses to SBS before launching CRT XR. Use the launch screen on a normal monitor, choose the glasses display, then select Open glasses view. The app blacks out, moves to that display and waits for a stable, plausible full-SBS mode before revealing the room. The physical SBS button is still required. No resolution is hardcoded for this flow. Return glasses to mono and press B / Escape to retry if it stays black. Without glasses, choose Play on this screen without glasses; this starts a fixed mono view. Display selection is explicit and is not inferred from a wide desktop monitor.

The native helper enumerates VITURE HID devices, checks product IDs with the SDK, opens pose mode at the highest supported rate up to 500 Hz and forwards normalized quaternions over loopback UDP. SDK callbacks never call the engine. Pose angles follow the vendor Gen1/Gen2 demo: Godot yaw = SDK yaw, pitch = negative SDK pitch, roll = negative SDK roll; compose Y * X * Z into a quaternion. A stale stream holds the last pose; the helper retries after disconnection and exits when its parent exits. Telemetry reporting is not enabled.

**OpenTrack source.** `scripts/tracking/opentrack_tracking.gd` is a second Windows (and Linux) source, chosen with View → Tracking source and saved as `tracking/source`. It binds UDP 127.0.0.1:4242 and accepts opentrack's 48-byte `double[6]` packet (x, y, z, yaw, pitch, roll; degrees, little-endian), or 52 bytes with XRLinuxDriver's trailing frame number. Non-finite or out-of-range angles are ignored; 300 ms without packets holds the last pose. opentrack documents no sign convention; XRLinuxDriver passes its own angles through unchanged in the VITURE SDK's frame, so the mapping matches the VITURE helper (Godot yaw = yaw, pitch = −pitch, roll = −roll, Y·X·Z). `tests/opentrack_tracking.gd` covers it with loopback packets; real non-VITURE glasses have not been tested.

Hardware validation is required for pose direction, display placement, controller operation and reconnect behaviour. Initial code and export checks alone do not establish a working Windows XR release.

Windows exports retain a separate CRT-XR.pck beside the EXE, then set its manifest to PerMonitorV2. Godot 4.5.1 otherwise uses system DPI awareness, which virtualizes monitor bounds on mixed-scale desktops. The manifest tool refuses embedded PCKs because resource edits can relocate their payload. Keep the PCK beside the EXE. The selector reports active desktop dimensions rather than panel maximum resolutions.

## Drives and network folders

In the ROM browser, Computer drives lists local, removable and mapped drives visible to your Windows user. Open folder or network path accepts paths such as D:/roms or \\server\share\roms. Connect protected shares in Windows File Explorer first; CRT XR uses your existing Windows access and does not store network passwords. After opening the main ROM folder, choose Use this folder for my library. The music browser also accepts folder and network paths. Network discovery and share authentication remain in Windows.

Desktop and glasses field-of-view calibration are stored separately (50° desktop, 24° XR defaults). Older 50° preview settings migrate to the XR default when used with glasses. Custom non-default legacy values are retained; subsequent explicit XR choices are preserved. Distance limits remain 1.2–5.0 metres on both platforms.
